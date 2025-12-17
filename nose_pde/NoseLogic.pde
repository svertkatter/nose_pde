// NoseLogic.pde
// Python版 nose_logic.py からの変換（簡略化版）

class NoseLogic {
  // スケール設定
  final float SCALE_MIN_BASE = 2.0;
  final float HARD_MAX_SCALE = 3.8;

  // 笑顔ゲート
  final float SMILE_ON_THRESH = 0.25;
  final float SMILE_OFF_THRESH = 0.18;
  final float DELTA_ON = 0.05;
  final float DELTA_OFF = 0.01;
  final float K_SIGMA_ON = 0.7;
  final float K_SIGMA_OFF = 0.1;

  // 平滑化・確定までの猶予
  final float S_EMA_ALPHA = 0.25;
  final float BASELINE_ALPHA = 0.05;
  final float NOISE_ALPHA = 0.05;
  final int MIN_ON_FRAMES = 7;

  // 速度（秒ベース）
  final float ADD_PER_SEC_K = 4.00;
  final float DECAY_PER_SEC = 0.60;

  // キャリブレーション
  final float CALIB_SECS = 2.0;

  // 各人のステート
  HashMap<Integer, Float> scales;
  HashMap<Integer, Float> smileEma;
  HashMap<Integer, Float> baseline;
  HashMap<Integer, Float> noiseEma;
  HashMap<Integer, Integer> onFrames;
  HashMap<Integer, Boolean> isOn;
  HashMap<Integer, Float> firstTs;
  HashMap<Integer, Float> lastTs;
  HashSet<Integer> idsLive;

  NoseLogic() {
    scales = new HashMap<Integer, Float>();
    smileEma = new HashMap<Integer, Float>();
    baseline = new HashMap<Integer, Float>();
    noiseEma = new HashMap<Integer, Float>();
    onFrames = new HashMap<Integer, Integer>();
    isOn = new HashMap<Integer, Boolean>();
    firstTs = new HashMap<Integer, Float>();
    lastTs = new HashMap<Integer, Float>();
    idsLive = new HashSet<Integer>();
  }

  float now() {
    return millis() / 1000.0;
  }

  void resetPeople(HashSet<Integer> idsNow) {
    if (!idsNow.equals(idsLive)) {
      float currentTime = now();

      HashMap<Integer, Float> newScales = new HashMap<Integer, Float>();
      HashMap<Integer, Float> newSmileEma = new HashMap<Integer, Float>();
      HashMap<Integer, Float> newBaseline = new HashMap<Integer, Float>();
      HashMap<Integer, Float> newNoiseEma = new HashMap<Integer, Float>();
      HashMap<Integer, Integer> newOnFrames = new HashMap<Integer, Integer>();
      HashMap<Integer, Boolean> newIsOn = new HashMap<Integer, Boolean>();
      HashMap<Integer, Float> newFirstTs = new HashMap<Integer, Float>();
      HashMap<Integer, Float> newLastTs = new HashMap<Integer, Float>();

      for (Integer pid : idsNow) {
        newScales.put(pid, scales.getOrDefault(pid, SCALE_MIN_BASE));
        newSmileEma.put(pid, 0.0);
        newBaseline.put(pid, 0.0);
        newNoiseEma.put(pid, 0.0);
        newOnFrames.put(pid, 0);
        newIsOn.put(pid, false);
        newFirstTs.put(pid, firstTs.getOrDefault(pid, currentTime));
        newLastTs.put(pid, currentTime);
      }

      scales = newScales;
      smileEma = newSmileEma;
      baseline = newBaseline;
      noiseEma = newNoiseEma;
      onFrames = newOnFrames;
      isOn = newIsOn;
      firstTs = newFirstTs;
      lastTs = newLastTs;
      idsLive = new HashSet<Integer>(idsNow);
    }
  }

  boolean candidateOn(int pid, float s, float base, float sigma) {
    float thrAbsOn = SMILE_ON_THRESH;
    float thrRelOn = base + max(DELTA_ON, K_SIGMA_ON * sigma);
    return (s >= thrAbsOn) && (s >= thrRelOn);
  }

  boolean candidateOff(int pid, float s, float base, float sigma) {
    float thrAbsOff = SMILE_OFF_THRESH;
    float thrRelOff = base + max(DELTA_OFF, K_SIGMA_OFF * sigma);
    return (s < thrAbsOff) || (s < thrRelOff);
  }

  HashMap<Integer, Float> update(HashMap<Integer, int[]> objects, HashMap<Integer, Float> smileById) {
    HashSet<Integer> ids = new HashSet<Integer>(objects.keySet());
    resetPeople(ids);

    if (ids.size() == 0) {
      return new HashMap<Integer, Float>();
    }

    float currentTime = now();
    HashMap<Integer, Float> out = new HashMap<Integer, Float>();

    for (Integer pid : ids) {
      // 経過時間
      float prevTs = lastTs.getOrDefault(pid, currentTime);
      float dt = max(1.0/120.0, currentTime - prevTs);
      lastTs.put(pid, currentTime);

      // スコアEMA
      float sRaw = smileById.getOrDefault(pid, 0.0);
      float sPrev = smileEma.getOrDefault(pid, sRaw);
      float s = sPrev * (1.0 - S_EMA_ALPHA) + sRaw * S_EMA_ALPHA;
      smileEma.put(pid, s);

      // キャリブ期間中は学習のみ
      float first = firstTs.getOrDefault(pid, currentTime);
      boolean inCalib = (currentTime - first) < CALIB_SECS;

      // 中立＆ノイズEMA更新
      float base;
      if (!isOn.getOrDefault(pid, false)) {
        float bPrev = baseline.getOrDefault(pid, s);
        base = bPrev * (1.0 - BASELINE_ALPHA) + s * BASELINE_ALPHA;
        baseline.put(pid, base);

        float nPrev = noiseEma.getOrDefault(pid, 0.0);
        noiseEma.put(pid, nPrev * (1.0 - NOISE_ALPHA) + abs(s - base) * NOISE_ALPHA);
      } else {
        base = baseline.getOrDefault(pid, 0.0);
      }

      float sigma = noiseEma.getOrDefault(pid, 0.0);

      // 候補ON/OFF判定
      boolean candOn = candidateOn(pid, s, base, sigma);
      boolean candOff = candidateOff(pid, s, base, sigma);

      if (isOn.getOrDefault(pid, false)) {
        if (candOff) {
          isOn.put(pid, false);
          onFrames.put(pid, 0);
        }
      } else {
        if (candOn) {
          int frames = onFrames.getOrDefault(pid, 0) + 1;
          onFrames.put(pid, frames);

          if (frames >= MIN_ON_FRAMES && !inCalib) {
            isOn.put(pid, true);
            onFrames.put(pid, 0);
          }
        } else {
          onFrames.put(pid, 0);
        }
      }

      // スケール更新
      float prevScale = scales.getOrDefault(pid, SCALE_MIN_BASE);
      float newScale;

      if (isOn.getOrDefault(pid, false)) {
        if (candOn) {
          float thrRelOn = base + max(DELTA_ON, K_SIGMA_ON * sigma);
          float sEff = max(0.0, s - thrRelOn);
          newScale = prevScale + sEff * ADD_PER_SEC_K * dt;
        } else {
          newScale = prevScale - DECAY_PER_SEC * dt;
        }
      } else {
        newScale = prevScale - DECAY_PER_SEC * dt;
      }

      newScale = constrain(newScale, SCALE_MIN_BASE, HARD_MAX_SCALE);
      scales.put(pid, newScale);
      out.put(pid, newScale);
    }

    return out;
  }
}
