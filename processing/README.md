# Processing版 - 利己の鏡

Python版（MediaPipe + OpenCV）からProcessingへの変換版です。

## 特徴

- ✅ **単一ファイル構成**: すべてのコードが1つの.pdeファイルにまとまっています
- ✅ カメラキャプチャ
- ✅ 顔検出（OpenCV for Processing）
- ✅ 複数人トラッキング（CentroidTracker）
- ✅ 鼻オーバーレイ表示
- ✅ 複数人モード（2人の場合は自動切り替え）
- ✅ デバッグ情報表示

## Python版からの主な変更点

### 制限事項
- **MediaPipe非対応**: Processingでは利用できないため、OpenCVの顔検出（Haar Cascades）を使用
- **FaceMesh非対応**: 468個のランドマークは使用不可。基本的な顔検出のみ
- **笑顔検出簡略化**: FaceMeshによる詳細な口の解析の代わりに、簡易的な検出を実装

## 必要な環境

### Processing
- Processing 4.x 以上

### 必要なライブラリ
1. **OpenCV for Processing**
   - Processing IDE: Sketch → Import Library → Add Library → "OpenCV for Processing" を検索してインストール

2. **Video Library**
   - Processing標準ライブラリ（通常はプリインストール済み）

### 必要なファイル
- `assets/` フォルダに鼻画像（`nose_*.png`）を配置
  - PNG形式（透過アルファチャンネル推奨）
  - ファイル名: `nose_1.png`, `nose_2.png`, など

## セットアップ

1. **Processingをインストール**
   - https://processing.org/ からダウンロード

2. **ライブラリをインストール**
   - Processing IDE を起動
   - Sketch → Import Library → Add Library
   - "OpenCV for Processing" を検索してインストール

3. **スケッチを配置**
   - この `processing` フォルダをProcessingのスケッチブックフォルダにコピー
   - または、Processing IDEで File → Open から `processing.pde` を開く

4. **アセット（鼻画像）を配置**
   - `processing/assets/` フォルダを作成
   - 鼻画像（`nose_*.png`）を配置

## 使い方

1. Processing IDEで `processing.pde` を開く
2. 再生ボタン（▶）をクリック
3. カメラが起動し、顔検出が開始されます
4. 顔が検出されると、鼻オーバーレイが表示されます

### キーボード操作
- `ESC`: アプリケーション終了
- `D`: デバッグ情報の表示/非表示切り替え

## アプリケーションとしてエクスポート

Processing IDEから実行可能アプリケーションを作成できます：

1. File → Export Application
2. プラットフォームを選択（Windows, macOS, Linux）
3. "Full Screen" オプションを有効化（推奨）
4. Export をクリック
5. `application.{platform}/` フォルダに実行可能ファイルが生成されます

### 注意事項
- エクスポート時に `assets/` フォルダも一緒に含める必要があります
- `data/` フォルダにリソースを配置すると、自動的にパッケージされます

## 設定

`processing.pde` の冒頭で設定を変更できます：

```java
int cameraIndex = 0;        // カメラ番号（0, 1, 2...）
float swapSec = 15.0;       // 2人モード時の切り替え秒数
float maxScale = 4.5;       // 鼻の最大スケール
boolean debugOverlay = true; // デバッグ情報表示
```

## ファイル構成

```
processing/
├── processing.pde        # メインスケッチ（統合版）
├── README.md             # このファイル
└── assets/               # リソースフォルダ
    ├── nose_1.png
    ├── nose_2.png
    └── ...
```

## トラブルシューティング

### カメラが起動しない
- コンソールに表示されるカメラリストを確認
- `cameraIndex` を変更してみる（0, 1, 2...）

### 顔が検出されない
- 明るい場所で試す
- カメラに正面を向く
- OpenCVライブラリが正しくインストールされているか確認

### 鼻画像が表示されない
- `assets/` フォルダが `processing/` の直下にあるか確認
- 鼻画像ファイル名が `nose_*.png` 形式か確認
- 画像ファイルが破損していないか確認

### ライブラリが見つからないエラー
```
The package "gab.opencv" does not exist
```
- OpenCV for Processing ライブラリがインストールされていません
- Processing IDE: Sketch → Import Library → Add Library → "OpenCV for Processing"

## クラス構成

この単一ファイルには以下のクラスが含まれています：

### CentroidTracker
- 顔の追跡を管理
- オブジェクトIDの割り当て
- 消失した顔の管理

### NoseLogic
- 鼻のスケール計算
- 笑顔スコアに基づく倍率調整
- EMA（指数移動平均）による平滑化
- キャリブレーション機能

## Python版との違い

| 機能 | Python版 | Processing版 |
|------|----------|--------------|
| ファイル構成 | 複数ファイル | 単一ファイル |
| 顔検出 | MediaPipe Face Detection | OpenCV Haar Cascades |
| ランドマーク | 468点 FaceMesh | なし（重心のみ） |
| 笑顔検出 | 口の詳細解析 | 簡易実装 |
| ポーズ検出 | あり | なし |
| サウンド | 3種類の笑い声 | なし |
| 設定UI | OpenCVトラックバー | コード内定数 |
| フルスクリーン | あり | あり |

## 今後の改善案

- [ ] 笑顔検出の精度向上（追加のOpenCV分類器使用）
- [ ] サウンド再生の実装（Minim libraryなど）
- [ ] 設定UIの追加（ControlP5 libraryなど）
- [ ] パフォーマンス最適化
- [ ] より高度な顔ランドマーク検出（DLib for Processingなど）

## ライセンス

元のPython版と同じライセンスが適用されます。

## 参考

- Processing: https://processing.org/
- OpenCV for Processing: https://github.com/atduskgreg/opencv-processing
- Processing Video Library: https://processing.org/reference/libraries/video/index.html
