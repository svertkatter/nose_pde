# 『利己の鏡』

顔検出と笑顔認識を使ったインタラクティブアート作品です。

## 概要

このプロジェクトは、カメラで顔を検出し、笑顔の度合いに応じて鼻のサイズが変化するインタラクティブな鏡のような体験を提供します。

## バージョン

### Python版（`python/`フォルダ）

MediaPipeとOpenCVを使用した高機能版です。

**特徴：**
- 468点のフェイスメッシュランドマークによる高精度な顔認識
- 詳細な笑顔検出（口の形状解析）
- ポーズ検出による全身トラッキング
- 3種類の笑い声サウンド
- リアルタイム設定調整UI（OpenCVトラックバー）
- 設定の保存/読み込み（JSON）

**必要な環境：**
- Python 3.x
- MediaPipe
- OpenCV
- NumPy
- Pygame
- SciPy

**詳細：** [python/readme.md](python/readme.md) を参照

### Processing版（`nose_pde/`フォルダ）

Python版をProcessingに移植した版です。Processing環境で動作するため、セットアップが簡単です。

**特徴：**
- OpenCV for Processingによる顔検出
- 複数人トラッキング
- 鼻オーバーレイ表示
- デバッグ情報表示

**制限事項：**
- MediaPipeの高度な機能は非対応
- 笑顔検出は簡易実装
- サウンドは未実装

**必要な環境：**
- Processing 4.x
- OpenCV for Processing ライブラリ
- Video ライブラリ

**詳細：** [nose_pde/README.md](nose_pde/README.md) を参照

## どちらを使うべきか

| 用途 | 推奨バージョン |
|------|---------------|
| 高精度な顔認識が必要 | Python版 |
| 詳細な笑顔検出が必要 | Python版 |
| サウンド付きで実行したい | Python版 |
| 簡単にセットアップしたい | Processing版 |
| Processingの知識がある | Processing版 |
| プロトタイピング | Processing版 |

## プロジェクト構成

```
nose_pde/
├── python/              # Python版
│   ├── main.py         # メインプログラム
│   ├── app_config.py   # 設定管理
│   ├── centroid_tracker.py  # 顔トラッキング
│   ├── nose_logic.py   # 鼻スケール計算
│   ├── settings_ui.py  # 設定UI
│   ├── utils.py        # ユーティリティ関数
│   └── readme.md       # Python版README
│
└── nose_pde/           # Processing版
    ├── nose_pde.pde    # メインスケッチ
    ├── CentroidTracker.pde  # 顔トラッキング
    ├── NoseLogic.pde   # 鼻スケール計算
    └── README.md       # Processing版README
```

## 共通のリソース

両方のバージョンで以下のリソースが必要です：

### 鼻画像（`assets/`フォルダ）
- PNG形式（透過アルファチャンネル推奨）
- ファイル名: `nose_1.png`, `nose_2.png`, など
- 各バージョンのフォルダ内に配置

### サウンド（Python版のみ、`assets/`フォルダ）
- `laugh_giggle.wav`
- `laugh_chuckle.wav`
- `laugh_big.wav`

## 開発履歴

- **Python版**: 元のバージョン。exe形式で実行可能（distやbuildフォルダは未アップロード）
- **Processing版**: Python版からの移植版

## ライセンス

（ライセンス情報をここに追加）

## 作者

（作者情報をここに追加）

## 謝辞

- OpenCV
- MediaPipe
- Processing
- OpenCV for Processing
