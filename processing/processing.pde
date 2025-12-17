// processing.pde - 利己の鏡 Processing版（統合版）
// Python版からの変換（簡略化版）
// 必要なライブラリ: OpenCV for Processing, Video Library

import gab.opencv.*;
import processing.video.*;
import java.awt.Rectangle;
import java.util.*;

// ================================================================
// グローバル変数
// ================================================================
Capture cam;
OpenCV opencv;
PImage[] noseImages;
int noseImageCount = 0;

// 定数
final int SCREEN_W = 1920;
final int SCREEN_H = 1080;
final int MIN_FACE_SIZE = 80;
final float VISIBILITY_THRESH = 0.5;

// 設定（Python版の config.json 相当）
int cameraIndex = 0;
float swapSec = 15.0;
float maxScale = 4.5;
boolean debugOverlay = true;

// トラッカーとロジック
CentroidTracker centroidTracker;
NoseLogic noseLogic;

// 割当ステート
Integer assignedId = null;
int assignedImgIdx = 0;
float twoPersonLastSwitch = 0;

// フレームカウント
int frameCount = 0;

// ================================================================
// セットアップと描画
// ================================================================
void settings() {
  // フルスクリーン設定
  fullScreen();
  // または固定サイズ: size(1920, 1080);
}

void setup() {
  // カメラ初期化
  String[] cameras = Capture.list();

  if (cameras.length == 0) {
    println("利用可能なカメラがありません");
    exit();
  } else {
    println("利用可能なカメラ:");
    for (int i = 0; i < cameras.length; i++) {
      println(i + ": " + cameras[i]);
    }

    // カメラを開く（インデックスは環境に応じて調整）
    if (cameraIndex < cameras.length) {
      cam = new Capture(this, 640, 480, cameras[cameraIndex]);
    } else {
      cam = new Capture(this, 640, 480, cameras[0]);
    }
    cam.start();
  }

  // OpenCV初期化
  opencv = new OpenCV(this, 640, 480);
  opencv.loadCascade(OpenCV.CASCADE_FRONTALFACE);

  // 鼻画像の読み込み
  loadNoseImages();

  // トラッカーとロジックの初期化
  centroidTracker = new CentroidTracker(300);
  noseLogic = new NoseLogic();

  frameRate(30);
}

void draw() {
  background(0);

  if (cam.available()) {
    cam.read();
  }

  // OpenCVに画像をロード
  opencv.loadImage(cam);

  // グレースケール変換（顔検出用）
  opencv.gray();

  // 顔検出
  Rectangle[] faces = opencv.detect();

  // 検出された顔のバウンディングボックスをリストに変換
  ArrayList<int[]> boxes = new ArrayList<int[]>();
  for (Rectangle face : faces) {
    if (face.width * face.height >= MIN_FACE_SIZE * MIN_FACE_SIZE) {
      boxes.add(new int[]{face.x, face.y, face.width, face.height});
    }
  }

  // トラッカー更新
  HashMap<Integer, int[]> objects = centroidTracker.update(boxes);

  // 笑顔スコアの計算（簡易版 - 実際のPython版ではFaceMeshを使用）
  HashMap<Integer, Float> smileScores = new HashMap<Integer, Float>();
  for (Map.Entry<Integer, int[]> entry : objects.entrySet()) {
    // 簡易笑顔スコア（ランダムまたは常に一定値）
    // 実際の実装では、より高度な検出が必要
    smileScores.put(entry.getKey(), random(0.0, 0.5));
  }

  // 割り当て処理
  updateAssignment(objects);

  // 鼻スケールの更新
  HashMap<Integer, Float> noseScales = noseLogic.update(objects, smileScores);

  // フレーム表示（ミラー反転）
  pushMatrix();
  translate(width, 0);
  scale(-1, 1);

  // カメラ画像をスケーリングして表示
  float aspectFrame = (float)cam.width / cam.height;
  float aspectScreen = (float)width / height;
  int newW, newH;

  if (aspectFrame > aspectScreen) {
    newW = width;
    newH = int(width / aspectFrame);
  } else {
    newH = height;
    newW = int(height * aspectFrame);
  }

  int offsetX = (width - newW) / 2;
  int offsetY = (height - newH) / 2;

  image(cam, offsetX, offsetY, newW, newH);

  // 鼻オーバーレイ
  if (assignedId != null && objects.containsKey(assignedId)) {
    drawNoseOverlay(objects, noseScales, offsetX, offsetY, newW, newH);
  }

  popMatrix();

  // デバッグ情報
  if (debugOverlay) {
    drawDebugInfo(objects.size(), noseScales);
  }
}

// ================================================================
// ヘルパー関数
// ================================================================
void updateAssignment(HashMap<Integer, int[]> objects) {
  float curTime = millis() / 1000.0;
  ArrayList<Integer> currentFaces = new ArrayList<Integer>(objects.keySet());

  if (assignedId == null) {
    if (currentFaces.size() > 0) {
      if (currentFaces.size() == 1) {
        assignedId = currentFaces.get(0);
        twoPersonLastSwitch = 0;
      } else {
        assignedId = currentFaces.get(int(random(currentFaces.size())));
        twoPersonLastSwitch = curTime;
      }
      if (noseImageCount > 0) {
        assignedImgIdx = int(random(noseImageCount));
      }
    }
  } else if (!currentFaces.contains(assignedId)) {
    if (currentFaces.size() == 0) {
      assignedId = null;
      assignedImgIdx = 0;
      twoPersonLastSwitch = 0;
    } else if (currentFaces.size() == 1) {
      assignedId = currentFaces.get(0);
      if (noseImageCount > 0) {
        assignedImgIdx = int(random(noseImageCount));
      }
      twoPersonLastSwitch = 0;
    } else {
      assignedId = currentFaces.get(int(random(currentFaces.size())));
      if (noseImageCount > 0) {
        assignedImgIdx = int(random(noseImageCount));
      }
      twoPersonLastSwitch = curTime;
    }
  } else if (currentFaces.size() == 2) {
    if (twoPersonLastSwitch == 0) {
      twoPersonLastSwitch = curTime;
    } else if (curTime - twoPersonLastSwitch >= swapSec) {
      for (Integer id : currentFaces) {
        if (id != assignedId) {
          assignedId = id;
          break;
        }
      }
      twoPersonLastSwitch = curTime;
    }
  }
}

void drawNoseOverlay(HashMap<Integer, int[]> objects, HashMap<Integer, Float> noseScales,
                      int offsetX, int offsetY, int dispW, int dispH) {
  if (noseImageCount == 0) return;

  int[] centroid = objects.get(assignedId);
  if (centroid == null) return;

  float cx = centroid[0];
  float cy = centroid[1];

  // 画像座標をスクリーン座標に変換
  float scaleX = (float)dispW / cam.width;
  float scaleY = (float)dispH / cam.height;

  float screenX = cx * scaleX + offsetX;
  float screenY = cy * scaleY + offsetY;

  // スケール取得
  float scale = noseScales.getOrDefault(assignedId, 2.0);

  // 複数人の場合は相手のスケールを使用
  if (objects.size() == 2) {
    for (Map.Entry<Integer, Float> entry : noseScales.entrySet()) {
      if (entry.getKey() != assignedId) {
        scale = entry.getValue();
        break;
      }
    }
  } else if (objects.size() >= 3) {
    float maxScale = 2.0;
    for (Map.Entry<Integer, Float> entry : noseScales.entrySet()) {
      if (entry.getKey() != assignedId) {
        maxScale = max(maxScale, entry.getValue());
      }
    }
    scale = maxScale;
  }

  // 最大スケールクランプ
  scale = min(maxScale, scale);

  // 基準サイズ（顔の幅の約0.45倍）
  int[] box = findFaceBox();
  float baseSize = 120;
  if (box != null) {
    baseSize = box[2] * 0.45;
  }

  int noseSize = max(8, int(baseSize * scale));

  // 鼻画像を描画
  PImage noseImg = noseImages[assignedImgIdx];
  imageMode(CENTER);
  image(noseImg, screenX, screenY - noseSize * 0.15, noseSize, noseSize);
  imageMode(CORNER);
}

int[] findFaceBox() {
  // 実際の実装では、顔のバウンディングボックスを保持する必要がある
  // ここでは簡略化のため null を返す
  return null;
}

void drawDebugInfo(int faceCount, HashMap<Integer, Float> noseScales) {
  fill(0, 255, 0);
  textSize(20);
  textAlign(LEFT, TOP);

  text("MODE: " + faceCount + "人", 10, 30);

  float curTime = millis() / 1000.0;
  if (faceCount == 2 && twoPersonLastSwitch > 0) {
    float remaining = max(0, swapSec - (curTime - twoPersonLastSwitch));
    text("Flip in: " + nf(remaining, 1, 1) + "s", 10, 60);
  }

  text("Smile Debug:", 10, 100);
  int y = 130;

  for (Map.Entry<Integer, Float> entry : noseScales.entrySet()) {
    int id = entry.getKey();
    float sc = entry.getValue();
    String mark = (assignedId != null && id == assignedId) ? "*" : " ";
    text(mark + "ID " + id + ": sc=" + nf(sc, 1, 2), 10, y);
    y += 25;
  }
}

void loadNoseImages() {
  File assetsDir = new File(sketchPath("assets"));

  if (!assetsDir.exists()) {
    println("Warning: assetsフォルダが見つかりません");
    return;
  }

  // nose_*.png ファイルを検索
  File[] files = assetsDir.listFiles();
  ArrayList<PImage> tempImages = new ArrayList<PImage>();

  if (files != null) {
    Arrays.sort(files);
    for (File file : files) {
      if (file.getName().startsWith("nose_") && file.getName().endsWith(".png")) {
        PImage img = loadImage(file.getAbsolutePath());
        if (img != null) {
          tempImages.add(img);
        }
      }
    }
  }

  noseImageCount = tempImages.size();
  noseImages = new PImage[noseImageCount];
  for (int i = 0; i < noseImageCount; i++) {
    noseImages[i] = tempImages.get(i);
  }

  if (noseImageCount == 0) {
    println("Warning: 鼻画像が見つかりません");
  } else {
    println("鼻画像を" + noseImageCount + "個読み込みました");
  }
}

void keyPressed() {
  if (key == ESC) {
    key = 0; // ESCのデフォルト動作を無効化
    exit();
  }

  // デバッグ切り替え
  if (key == 'd' || key == 'D') {
    debugOverlay = !debugOverlay;
  }
}

// ================================================================
// CentroidTracker クラス
// ================================================================
class CentroidTracker {
  int nextObjectID;
  ArrayList<Integer> availableIDs;
  HashMap<Integer, int[]> objects;         // objectID -> (centroid_x, centroid_y)
  HashMap<Integer, Integer> disappeared;   // objectID -> 連続で検出されなかったフレーム数
  int maxDisappeared;

  CentroidTracker(int maxDisappeared) {
    this.nextObjectID = 0;
    this.availableIDs = new ArrayList<Integer>();
    this.objects = new HashMap<Integer, int[]>();
    this.disappeared = new HashMap<Integer, Integer>();
    this.maxDisappeared = maxDisappeared;
  }

  void register(int[] centroid) {
    int objectID;

    if (availableIDs.size() > 0) {
      objectID = availableIDs.remove(0);
    } else {
      objectID = nextObjectID;
      nextObjectID++;
    }

    objects.put(objectID, centroid);
    disappeared.put(objectID, 0);
  }

  void deregister(int objectID) {
    objects.remove(objectID);
    disappeared.remove(objectID);
    availableIDs.add(objectID);
    Collections.sort(availableIDs);
  }

  HashMap<Integer, int[]> update(ArrayList<int[]> rects) {
    // rects: [(x, y, w, h), ...] のリスト

    // (1) もし矩形がひとつもなければ、すべての objectID を disappeared カウントする
    if (rects.size() == 0) {
      ArrayList<Integer> toDeregister = new ArrayList<Integer>();

      for (Integer objectID : new ArrayList<Integer>(disappeared.keySet())) {
        int count = disappeared.get(objectID) + 1;
        disappeared.put(objectID, count);

        if (count > maxDisappeared) {
          toDeregister.add(objectID);
        }
      }

      for (Integer objectID : toDeregister) {
        deregister(objectID);
      }

      return objects;
    }

    // (2) 各矩形から centroid を計算
    int[][] inputCentroids = new int[rects.size()][2];
    for (int i = 0; i < rects.size(); i++) {
      int[] rect = rects.get(i);
      int x = rect[0];
      int y = rect[1];
      int w = rect[2];
      int h = rect[3];

      int cX = x + w / 2;
      int cY = y + h / 2;
      inputCentroids[i][0] = cX;
      inputCentroids[i][1] = cY;
    }

    // (3) 既存追跡中オブジェクトがない場合 → すべて新規登録
    if (objects.size() == 0) {
      for (int i = 0; i < inputCentroids.length; i++) {
        register(inputCentroids[i]);
      }
    } else {
      // (4) 既存オブジェクトと新検出 centroid の距離行列を作成
      ArrayList<Integer> objectIDs = new ArrayList<Integer>(objects.keySet());
      int[][] objectCentroids = new int[objectIDs.size()][2];

      for (int i = 0; i < objectIDs.size(); i++) {
        objectCentroids[i] = objects.get(objectIDs.get(i));
      }

      float[][] D = new float[objectCentroids.length][inputCentroids.length];

      for (int i = 0; i < objectCentroids.length; i++) {
        for (int j = 0; j < inputCentroids.length; j++) {
          float dx = objectCentroids[i][0] - inputCentroids[j][0];
          float dy = objectCentroids[i][1] - inputCentroids[j][1];
          D[i][j] = sqrt(dx * dx + dy * dy);
        }
      }

      // (5) 最小距離順にマッチング
      Integer[] rows = sortRowsByMinDistance(D);
      int[] cols = new int[rows.length];

      for (int i = 0; i < rows.length; i++) {
        cols[i] = argmin(D[rows[i]]);
      }

      HashSet<Integer> usedRows = new HashSet<Integer>();
      HashSet<Integer> usedCols = new HashSet<Integer>();

      for (int i = 0; i < rows.length; i++) {
        int row = rows[i];
        int col = cols[i];

        if (usedRows.contains(row) || usedCols.contains(col)) {
          continue;
        }

        if (D[row][col] > 50) {
          // もし距離が 50px を超えていたら別人とみなす
          continue;
        }

        int objectID = objectIDs.get(row);
        objects.put(objectID, inputCentroids[col]);
        disappeared.put(objectID, 0);

        usedRows.add(row);
        usedCols.add(col);
      }

      // (6) マッチしなかった既存顔 → disappeared カウントをインクリメント
      HashSet<Integer> unusedRows = new HashSet<Integer>();
      for (int i = 0; i < D.length; i++) {
        if (!usedRows.contains(i)) {
          unusedRows.add(i);
        }
      }

      for (Integer row : unusedRows) {
        int objectID = objectIDs.get(row);
        int count = disappeared.get(objectID) + 1;
        disappeared.put(objectID, count);

        if (count > maxDisappeared) {
          deregister(objectID);
        }
      }

      // (7) マッチしなかった新顔 → 新規登録
      HashSet<Integer> unusedCols = new HashSet<Integer>();
      for (int i = 0; i < inputCentroids.length; i++) {
        if (!usedCols.contains(i)) {
          unusedCols.add(i);
        }
      }

      for (Integer col : unusedCols) {
        register(inputCentroids[col]);
      }
    }

    return objects;
  }

  // ヘルパー関数: 各行の最小値でソート
  Integer[] sortRowsByMinDistance(float[][] D) {
    Integer[] indices = new Integer[D.length];
    for (int i = 0; i < D.length; i++) {
      indices[i] = i;
    }

    // 最小距離でソート
    Arrays.sort(indices, new Comparator<Integer>() {
      public int compare(Integer a, Integer b) {
        float minA = min(D[a]);
        float minB = min(D[b]);
        return Float.compare(minA, minB);
      }
    });

    return indices;
  }

  // ヘルパー関数: 配列の最小値のインデックス
  int argmin(float[] arr) {
    int minIdx = 0;
    float minVal = arr[0];

    for (int i = 1; i < arr.length; i++) {
      if (arr[i] < minVal) {
        minVal = arr[i];
        minIdx = i;
      }
    }

    return minIdx;
  }
}

// ================================================================
// NoseLogic クラス
// ================================================================
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

  boolean candidateOn(float s, float base, float sigma) {
    float thrAbsOn = SMILE_ON_THRESH;
    float thrRelOn = base + max(DELTA_ON, K_SIGMA_ON * sigma);
    return (s >= thrAbsOn) && (s >= thrRelOn);
  }

  boolean candidateOff(float s, float base, float sigma) {
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
      boolean candOn = candidateOn(s, base, sigma);
      boolean candOff = candidateOff(s, base, sigma);

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
