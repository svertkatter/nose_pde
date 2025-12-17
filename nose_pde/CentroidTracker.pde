// CentroidTracker.pde
// Python版 centroid_tracker.py からの変換

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
