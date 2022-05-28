import "dart:math";

/// コピペ：
/// https://qiita.com/as_kuya/items/8acaa265bc740d925f4c
/// 高速離散コサイン変換用のクラス、タイプIIとタイプIIIを備える
///
/// アルゴリズムは Byeong Gi Lee
///
/// 参考
/// https://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.118.3056&rep=rep1&type=pdf#page=34
/// https://pdfs.semanticscholar.org/ed00/5160f5befd45073fd01b697227d009cad919.pdf
///
/// DCT-IIの数式、DCT-IIIはこれの逆順で実装
/// y[2k] = Σ[n/2,m=0] (x[m]+x[n/2-1-m]) cos(π(2m+1)k/n)
/// y[2k-1] + y[2k+1] = Σ[n/2,m=0] (x[m]-x[n/2-1-m]) 2cos(π(2m+1)/2n) cos(π(m+1)k/n)
///
/// N - データ数
/// x - サンプリング配列
/// y - 周波数配列
/// j - サンプリング配列の添字 (時間)
/// k - 周波数配列への添字 (周波数)
class Vector {
  final List<double> data;
  const Vector.fromList(this.data);
  // 要素を入れ替える
  void swap(int a, int b) {
    final temp = data[a];
    data[a] = data[b];
    data[b] = temp;
  }

  // 要素配列の並び替え
  void swapElements(int n) {
    final nh = n >> 1;
    final nh1 = nh + 1;
    final nq = n >> 2;
    for (var i = 0, j = 0; i < nh; i += 2) {
      swap(i + nh, j + 1);
      if (i < j) {
        swap(i + nh1, j + nh1);
        swap(i, j);
      }
      // ビットオーダを反転した変数としてインクリメント
      for (var k = nq; (j ^= k) < k; k >>= 1) {}
    }
  }

  // 離散コサイン変換、タイプII
  // n - サンプル数、2のべき乗である必要がある
  // x - n個のサンプルの配列
  void dctII(int n) {
    // バタフライ演算
    var rad = pi / (n << 1);
    for (var m = n, mh = m >> 1; 1 < m; m = mh, mh >>= 1) {
      for (var i = 0; i < mh; ++i) {
        final cs = 2.0 * cos(rad * ((i << 1) + 1));
        for (var j = i, k = (m - 1) - i; j < n; j += m, k += m) {
          final x0 = data[j];
          final x1 = data[k];
          data[j] = x0 + x1;
          data[k] = (x0 - x1) * cs;
        }
      }
      rad *= 2.0;
    }

    // データの入れ替え
    swapElements(n);

    // 差分方程式
    for (var m = n, mh = m >> 1, mq = mh >> 1;
        2 < m;
        m = mh, mh = mq, mq >>= 1) {
      for (var i = mq + mh; i < m; ++i) {
        var xt = (data[i] = -data[i] - data[i - mh]);
        for (var j = i + mh; j < n; j += m) {
          var k = j + mh;
          xt = (data[j] -= xt);
          xt = (data[k] = -data[k] - xt);
        }
      }
    }

    // スケーリング
    for (var i = 1; i < n; ++i) {
      data[i] *= 0.5;
    }
  }

  // 離散コサイン変換、タイプIII
  // n - サンプル数、2のべき乗である必要がある
  // x - n個のサンプルの配列
  void dctIII(int n) {
    // スケーリング
    data[0] *= 0.5;

    // 差分方程式
    for (var m = 4, mh = 2, mq = 1; m <= n; mq = mh, mh = m, m <<= 1) {
      for (var i = n - mq; i < n; ++i) {
        var j = i;
        while (m < j) {
          final k = j - mh;
          data[j] = -data[j] - data[k];
          data[k] += data[j = k - mh];
        }
        data[j] = -data[j] - data[j - mh];
      }
    }

    // データの入れ替え
    swapElements(n);

    // バタフライ演算
    var rad = pi / 2.0;
    for (var m = 2, mh = 1; m <= n; mh = m, m <<= 1) {
      rad *= 0.5;
      for (var i = 0; i < mh; ++i) {
        final cs = 2.0 * cos(rad * ((i << 1) + 1));
        for (var j = i, k = (m - 1) - i; j < n; j += m, k += m) {
          final x0 = data[j];
          final x1 = data[k] / cs;
          data[j] = x0 + x1;
          data[k] = x0 - x1;
        }
      }
    }
  }

  operator [](int i) => data[i];
  operator []=(int i, double n) => data[i] = n;
}

/// 高速修正離散コサイン変換用のクラス
///
/// アルゴリズムは Mu-Huo Cheng and Yu-Hsin Hsu
///
/// 参考
/// https://pdfs.semanticscholar.org/2f26/a658836927331d559e723ac36b8dab911b14.pdf
class FastMDCT {
  // 修正コサイン変換
  // n - 周波数配列数、2のべき乗である必要がある
  // samples - 2n個のサンプル配列、この配列が変換処理の入力元となる
  // frequencies - n個の周波数配列、この配列が変換処理の出力先となる
  static Vector mdct(int n, Vector samples) {
    Vector frequencies = Vector.fromList(List.filled(n, 0.0));
    // データを結合
    final ns1 = n - 1; // n - 1
    final nd2 = n >> 1; // n / 2
    final nm3d4 = n + nd2; // n * 3 / 4
    final nm3d4s1 = nm3d4 - 1; // n * 3 / 4 - 1
    for (var i = 0; i < nd2; ++i) {
      frequencies[i] = samples[nm3d4 + i] + samples[nm3d4s1 - i];
      frequencies[nd2 + i] = samples[i] - samples[ns1 - i];
    }

    // cos値の変換用の係数をかけ合わせ
    final rad = pi / (n << 2);
    var i = 0;
    final nh = n >> 1;
    for (; i < nh; ++i) {
      frequencies[i] /= -2.0 * cos(rad * ((i << 1) + 1));
    }
    for (; i < n; ++i) {
      frequencies[i] /= 2.0 * cos(rad * ((i << 1) + 1));
    }

    // DCT-II
    frequencies.dctII(n);

    // 差分方程式
    for (var i = 0, j = 1; j < n; i = j++) {
      frequencies[i] += frequencies[j];
    }
    return frequencies;
  }

  // 逆修正コサイン変換
  // n - 周波数配列数、2のべき乗である必要がある
  // samples - 2n個のサンプル配列、この配列が変換処理の出力先となる
  // frequencies - n個の周波数配列、この配列が変換処理の入力元となる
  static Vector imdct(int n, Vector frequencies) {
    // TODO 入力元である周波数配列を破壊してしまうので作業用バッファを用いるか、破壊して良い出力先のsamplesを作業用バッファとして用いる
    // cos値の変換用係数を掛け合わせ
    Vector samples = Vector.fromList(List.filled(n << 1, 0.0));
    final rad = pi / (n << 2);
    for (var i = 0; i < n; ++i) {
      frequencies[i] *= 2.0 * cos(rad * ((i << 1) + 1));
    }

    // DCT-II
    frequencies.dctII(n);

    // 差分方程式
    frequencies[0] *= 0.5;
    var i = 0, j = 1;
    final nh = n >> 1;
    for (; i < nh; i = j++) {
      frequencies[j] += (frequencies[i] = -frequencies[i]);
    }
    for (; j < n; i = j++) {
      frequencies[j] -= frequencies[i];
    }

    // スケーリング
    for (var j = 0; j < n; ++j) {
      frequencies[j] /= n;
    }

    // データを分離
    final ns1 = n - 1; // n - 1
    final nd2 = n >> 1; // n / 2
    final nm3d4 = n + nd2; // n * 3 / 4
    final nm3d4s1 = nm3d4 - 1; // n * 3 / 4 - 1
    for (var i = 0; i < nd2; ++i) {
      samples[ns1 - i] = -(samples[i] = frequencies[nd2 + i]);
      samples[nm3d4 + i] = (samples[nm3d4s1 - i] = frequencies[i]);
    }
    return samples;
  }
}
