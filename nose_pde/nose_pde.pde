// nose_pde.pde - Main Processing sketch
// Python版からの変換（簡略化版）
// 必要なライブラリ: OpenCV for Processing, Video Library

import gab.opencv.*;
import processing.video.*;
import java.awt.Rectangle;
import java.util.*;

// グローバル変数
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
  updateAssignment(objects, smileScores);

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

void updateAssignment(HashMap<Integer, int[]> objects, HashMap<Integer, Float> smileScores) {
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
  int[] box = findFaceBox(assignedId, objects);
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

int[] findFaceBox(int targetId, HashMap<Integer, int[]> objects) {
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
