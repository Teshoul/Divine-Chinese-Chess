import 'dart:math';
import 'dart:typed_data';
import 'ai_engine.dart';

// ════════════════════════════════════════════════════════════════
//  盲棋 AI（纯 Dart，可放进后台线程运行）
//
//  规则和游戏里的盲棋一致：暗子第一步按“所在位置原棋子”的走法走，
//  走完翻开随机的身份和阵营；任何棋子都能直接吃暗子；
//  吃掉将/帅的一方是否获胜，取决于被吃将帅的真实阵营。
//
//  等级 0~3：AI 看不见暗子，用“随机假设（确定化）”估计：
//           把剩下的未知身份随机分配给暗子，多次搜索后取平均。
//  等级 4（地狱）：AI 直接读取所有暗子的真实身份（开挂），迭代加深搜索。
//
//  编码：棋子编号同 ai_engine.dart；走法编码
//    from | to<<7 | 被吃子<<14 | 被吃子暗<<18 | 被吃子原位<<19
//    | 走子暗<<23 | 走子原位<<24
// ════════════════════════════════════════════════════════════════

const List<int> _dr4 = [1, -1, 0, 0];
const List<int> _dc4 = [0, 0, 1, -1];
const List<int> _drD = [1, 1, -1, -1];
const List<int> _dcD = [1, -1, 1, -1];

bool _pal(int color, int r, int c) =>
    c >= 3 && c <= 5 && (color == 0 ? (r >= 7 && r <= 9) : (r >= 0 && r <= 2));

bool _homeSide(int color, int r) => color == 0 ? r >= 5 : r <= 4;

class BlindAi {
  final Int8List pc = Int8List(90);
  final Uint8List hid = Uint8List(90);
  final Int8List home = Int8List(90);
  int side = 0;
  int hash = 0;
  int ev = 0;
  bool kingPalace = true;
  bool aeLimit = false;

  int nodes = 0;
  bool stopped = false;
  bool useQ = true;
  int timeMs = 1000;
  final Stopwatch sw = Stopwatch();
  final Int32List mv = Int32List(64 * 128);
  final Int32List sco = Int32List(64 * 128);
  final Int32List killers = Int32List(64 * 2);
  final Int32List hist = Int32List(8100);
  Int64List tKey = Int64List(1);
  Int32List tVal = Int32List(1);
  Int32List tMeta = Int32List(1);
  int ttMask = 0;
  int rootBest = 0;
  int _n = 0;
  int _base = 0;

  void initTT(int bits) {
    final size = 1 << bits;
    tKey = Int64List(size);
    tVal = Int32List(size);
    tMeta = Int32List(size);
    ttMask = size - 1;
  }

  void rebuild() {
    hash = side == 1 ? kZob[kSideIdx] : 0;
    ev = 0;
    for (var sq = 0; sq < 90; sq++) {
      final p = pc[sq];
      if (p == 0) continue;
      hash ^= kZob[p * 90 + sq];
      if (hid[sq] == 1) hash ^= kZob[(16 + home[sq]) * 90 + sq];
      ev += kPv[p * 90 + sq];
    }
  }

  int evalSide() => (side == 0 ? ev : -ev) + 8;

  void _make(int m) {
    final from = m & 127;
    final to = (m >> 7) & 127;
    final p = pc[from];
    final mh = hid[from];
    final mhome = home[from];
    final capPc = pc[to];
    hash ^= kZob[p * 90 + from];
    if (mh == 1) hash ^= kZob[(16 + mhome) * 90 + from];
    ev -= kPv[p * 90 + from];
    if (capPc != 0) {
      hash ^= kZob[capPc * 90 + to];
      if (hid[to] == 1) hash ^= kZob[(16 + home[to]) * 90 + to];
      ev -= kPv[capPc * 90 + to];
    }
    pc[to] = p;
    hid[to] = 0;
    home[to] = p;
    pc[from] = 0;
    hid[from] = 0;
    home[from] = 0;
    hash ^= kZob[p * 90 + to];
    ev += kPv[p * 90 + to];
    hash ^= kZob[kSideIdx];
    side ^= 1;
  }

  void _unmake(int m) {
    final from = m & 127;
    final to = (m >> 7) & 127;
    final capPc = (m >> 14) & 15;
    final capHid = (m >> 18) & 1;
    final capHome = (m >> 19) & 15;
    final mvHid = (m >> 23) & 1;
    final mvHome = (m >> 24) & 15;
    final p = pc[to];
    hash ^= kZob[p * 90 + to];
    ev -= kPv[p * 90 + to];
    pc[from] = p;
    hid[from] = mvHid;
    home[from] = mvHome;
    hash ^= kZob[p * 90 + from];
    if (mvHid == 1) hash ^= kZob[(16 + mvHome) * 90 + from];
    ev += kPv[p * 90 + from];
    pc[to] = capPc;
    hid[to] = capHid;
    home[to] = capHome;
    if (capPc != 0) {
      hash ^= kZob[capPc * 90 + to];
      if (capHid == 1) hash ^= kZob[(16 + capHome) * 90 + to];
      ev += kPv[capPc * 90 + to];
    }
    hash ^= kZob[kSideIdx];
    side ^= 1;
  }

  void _add(int from, int to, int owner, bool caps) {
    final q = pc[to];
    if (q != 0) {
      if (hid[to] == 0 && (q >> 3) == owner) return;
    } else if (caps) {
      return;
    }
    if (_n >= 127) return;
    mv[_base + _n] = from |
        (to << 7) |
        (q << 14) |
        (hid[to] << 18) |
        (home[to] << 19) |
        (hid[from] << 23) |
        (home[from] << 24);
    _n++;
  }

  void _rays(int sq, int r, int c, int owner, bool cannon, bool caps) {
    for (var d = 0; d < 4; d++) {
      final dq = d == 0 ? -9 : (d == 1 ? 9 : (d == 2 ? -1 : 1));
      final steps = d == 0 ? r : (d == 1 ? 9 - r : (d == 2 ? c : 8 - c));
      var q = sq;
      var screen = false;
      for (var k = 0; k < steps; k++) {
        q += dq;
        final x = pc[q];
        if (!cannon) {
          if (x == 0) {
            _add(sq, q, owner, caps);
          } else {
            _add(sq, q, owner, caps);
            break;
          }
        } else if (!screen) {
          if (x == 0) {
            _add(sq, q, owner, caps);
          } else {
            screen = true;
          }
        } else if (x != 0) {
          _add(sq, q, owner, caps);
          break;
        }
      }
    }
  }

  int _gen(int ply, bool caps) {
    _base = ply * 128;
    _n = 0;
    for (var sq = 0; sq < 90; sq++) {
      final p = pc[sq];
      if (p == 0) continue;
      final strict = hid[sq] == 1;
      final mp = strict ? home[sq] : p;
      final owner = mp >> 3;
      if (owner != side) continue;
      final t = mp & 7;
      final limK = strict || kingPalace;
      final limAE = strict || aeLimit;
      final r = sq ~/ 9;
      final c = sq - r * 9;
      switch (t) {
        case 1:
          {
            for (var d = 0; d < 4; d++) {
              final nr = r + _dr4[d];
              final nc = c + _dc4[d];
              if (nr < 0 || nr > 9 || nc < 0 || nc > 8) continue;
              if (limK && _pal(owner, r, c) && !_pal(owner, nr, nc)) continue;
              _add(sq, nr * 9 + nc, owner, caps);
            }
            break;
          }
        case 2:
          {
            for (var d = 0; d < 4; d++) {
              final nr = r + _drD[d];
              final nc = c + _dcD[d];
              if (nr < 0 || nr > 9 || nc < 0 || nc > 8) continue;
              if (limAE && _pal(owner, r, c) && !_pal(owner, nr, nc)) continue;
              _add(sq, nr * 9 + nc, owner, caps);
            }
            break;
          }
        case 3:
          {
            for (var d = 0; d < 4; d++) {
              final nr = r + 2 * _drD[d];
              final nc = c + 2 * _dcD[d];
              if (nr < 0 || nr > 9 || nc < 0 || nc > 8) continue;
              if (pc[(r + _drD[d]) * 9 + c + _dcD[d]] != 0) continue;
              if (limAE && _homeSide(owner, r) && !_homeSide(owner, nr)) continue;
              _add(sq, nr * 9 + nc, owner, caps);
            }
            break;
          }
        case 4:
          {
            for (var d = 0; d < 4; d++) {
              final lr = r + _dr4[d];
              final lc = c + _dc4[d];
              if (lr < 0 || lr > 9 || lc < 0 || lc > 8) continue;
              if (pc[lr * 9 + lc] != 0) continue;
              for (var k = 0; k < 2; k++) {
                int tr;
                int tc;
                if (_dr4[d] != 0) {
                  tr = r + 2 * _dr4[d];
                  tc = c + (k == 0 ? -1 : 1);
                } else {
                  tr = r + (k == 0 ? -1 : 1);
                  tc = c + 2 * _dc4[d];
                }
                if (tr < 0 || tr > 9 || tc < 0 || tc > 8) continue;
                _add(sq, tr * 9 + tc, owner, caps);
              }
            }
            break;
          }
        case 5:
          {
            _rays(sq, r, c, owner, false, caps);
            break;
          }
        case 6:
          {
            _rays(sq, r, c, owner, true, caps);
            break;
          }
        default:
          {
            final dir = owner == 0 ? -1 : 1;
            final nr = r + dir;
            if (nr >= 0 && nr <= 9) _add(sq, nr * 9 + c, owner, caps);
            final crossed = owner == 0 ? r <= 4 : r >= 5;
            if (crossed) {
              if (c > 0) _add(sq, r * 9 + c - 1, owner, caps);
              if (c < 8) _add(sq, r * 9 + c + 1, owner, caps);
            }
            break;
          }
      }
    }
    return _n;
  }

  int _key(int m) => (m & 127) * 90 + ((m >> 7) & 127);

  void _order(int ply, int n, int ttMove) {
    final base = ply * 128;
    final k1 = killers[ply * 2];
    final k2 = killers[ply * 2 + 1];
    for (var i = 0; i < n; i++) {
      final m = mv[base + i];
      final from = m & 127;
      final cap = (m >> 14) & 15;
      final key = _key(m);
      int s;
      if (key == ttMove) {
        s = 2000000;
      } else if (cap != 0) {
        s = 1000000 + kOrdVal[cap & 7] * 16 - (kOrdVal[pc[from] & 7] ~/ 16);
      } else if (key == k1) {
        s = 900000;
      } else if (key == k2) {
        s = 800000;
      } else {
        s = hist[key];
      }
      sco[base + i] = s;
    }
  }

  void _pick(int base, int n, int i) {
    var best = i;
    var bs = sco[base + i];
    for (var j = i + 1; j < n; j++) {
      if (sco[base + j] > bs) {
        bs = sco[base + j];
        best = j;
      }
    }
    if (best != i) {
      final tm = mv[base + i];
      mv[base + i] = mv[base + best];
      mv[base + best] = tm;
      final ts = sco[base + i];
      sco[base + i] = sco[base + best];
      sco[base + best] = ts;
    }
  }

  /// 吃到真实身份为将帅的棋子：胜负看被吃将帅的阵营
  int _kingCapScore(int cap, int ply) {
    final win = kMate - ply - 1;
    return ((cap >> 3) != side) ? win : -win;
  }

  int _qsearch(int alpha, int beta, int ply) {
    nodes++;
    final stand = evalSide();
    if (ply >= 56) return stand;
    if (stand >= beta) return stand;
    if (stand > alpha) alpha = stand;
    final n = _gen(ply, true);
    _order(ply, n, -1);
    final base = ply * 128;
    for (var i = 0; i < n; i++) {
      _pick(base, n, i);
      final m = mv[base + i];
      final cap = (m >> 14) & 15;
      int score;
      if ((cap & 7) == 1) {
        score = _kingCapScore(cap, ply);
      } else {
        if (stand + kOrdVal[cap & 7] + 220 < alpha) continue;
        _make(m);
        score = -_qsearch(-beta, -alpha, ply + 1);
        _unmake(m);
      }
      if (score >= beta) return score;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  int search(int depth, int alpha, int beta, int ply) {
    if ((++nodes & 2047) == 0 && sw.elapsedMilliseconds > timeMs) stopped = true;
    if (stopped) return 0;
    if (ply >= 56) return evalSide();
    if (depth <= 0) {
      return useQ ? _qsearch(alpha, beta, ply) : evalSide();
    }

    var ttMove = 0;
    final idx = ttMask == 0 ? 0 : (hash & ttMask);
    if (ttMask != 0 && tKey[idx] == hash) {
      final meta = tMeta[idx];
      final d = (meta >> 13) & 63;
      final fl = (meta >> 19) & 3;
      var s = tVal[idx];
      ttMove = meta & 8191;
      if (ply > 0 && d >= depth) {
        if (s > kMate - 200) {
          s -= ply;
        } else if (s < -kMate + 200) {
          s += ply;
        }
        if (fl == 0) return s;
        if (fl == 1 && s >= beta) return s;
        if (fl == 2 && s <= alpha) return s;
      }
    }

    final n = _gen(ply, false);
    if (n == 0) return -kMate + ply;
    _order(ply, n, ttMove);
    final base = ply * 128;
    var best = -kInf;
    var bestMove = 0;
    var flag = 2;
    var searched = 0;
    for (var i = 0; i < n; i++) {
      _pick(base, n, i);
      final m = mv[base + i];
      final cap = (m >> 14) & 15;
      int score;
      if ((cap & 7) == 1) {
        score = _kingCapScore(cap, ply);
      } else {
        _make(m);
        if (searched == 0) {
          score = -search(depth - 1, -beta, -alpha, ply + 1);
        } else {
          final red = (depth >= 3 && i >= 5 && cap == 0) ? 1 : 0;
          score = -search(depth - 1 - red, -alpha - 1, -alpha, ply + 1);
          if (score > alpha && (red > 0 || score < beta)) {
            score = -search(depth - 1, -beta, -alpha, ply + 1);
          }
        }
        _unmake(m);
        if (stopped) return 0;
      }
      searched++;
      if (score > best) {
        best = score;
        bestMove = m;
        if (score > alpha) {
          alpha = score;
          flag = 0;
          if (ply == 0) rootBest = m;
          if (score >= beta) {
            flag = 1;
            if (cap == 0) {
              final key = _key(m);
              if (killers[ply * 2] != key) {
                killers[ply * 2 + 1] = killers[ply * 2];
                killers[ply * 2] = key;
              }
              var h = hist[key] + depth * depth;
              if (h > 500000) h = 500000;
              hist[key] = h;
            }
            break;
          }
        }
      }
    }

    if (ttMask != 0 && !stopped) {
      var s = best;
      if (s > kMate - 200) {
        s += ply;
      } else if (s < -kMate + 200) {
        s -= ply;
      }
      tKey[idx] = hash;
      tVal[idx] = s;
      tMeta[idx] = _key(bestMove) | (depth << 13) | (flag << 19);
    }
    return best;
  }
}

class _BLv {
  final int depth;
  final int samples;
  final int ms;
  final int noise;
  final double rnd;
  const _BLv(this.depth, this.samples, this.ms, this.noise, this.rnd);
}

const List<_BLv> _blevels = [
  _BLv(1, 1, 400, 300, 0.40),
  _BLv(1, 4, 800, 120, 0.12),
  _BLv(2, 6, 1500, 45, 0.02),
  _BLv(3, 14, 3500, 10, 0.0),
];

/// 返回 from*90+to；没有可走的棋返回 -1
///
/// pcIn   ：每格的“真实棋子编号”。等级 0~3 时暗子填 0（AI 看不见），等级 4 填真实身份
/// hidIn  ：1 表示暗子
/// homeIn ：暗子所在位置的“原棋子编号”（决定它第一步怎么走）
/// pool   ：等级 0~3 用的，剩余未知身份的棋子编号列表
int blindAiPick(List<int> pcIn, List<int> hidIn, List<int> homeIn, List<int> pool,
    int side, int level, int seed, bool kingPalace, bool aeLimit) {
  final ai = BlindAi();
  ai.side = side;
  ai.kingPalace = kingPalace;
  ai.aeLimit = aeLimit;
  for (var i = 0; i < 90; i++) {
    ai.pc[i] = pcIn[i];
    ai.hid[i] = hidIn[i];
    ai.home[i] = homeIn[i];
  }
  final rnd = Random(seed);
  final hiddenSq = <int>[
    for (var i = 0; i < 90; i++)
      if (hidIn[i] == 1) i
  ];

  // ───── 地狱：全知，迭代加深 ─────
  if (level >= 4) {
    ai.rebuild();
    final n = ai._gen(0, false);
    if (n == 0) return -1;
    final roots = <int>[for (var i = 0; i < n; i++) ai.mv[i]];
    ai.initTT(21);
    ai.useQ = true;
    ai.timeMs = 8500;
    ai.sw.start();
    var best = 0;
    for (var d = 1; d <= 30; d++) {
      ai.rootBest = 0;
      final s = ai.search(d, -kInf, kInf, 0);
      if (ai.stopped) break;
      if (ai.rootBest != 0) best = ai.rootBest;
      if (s >= kMate - 100) break;
      if (ai.sw.elapsedMilliseconds * 10 > 8500 * 5) break;
    }
    if (best == 0) best = roots[0];
    return ai._key(best);
  }

  // ───── 等级 0~3：随机假设 + 浅搜索，多次取平均 ─────
  final lv = _blevels[level.clamp(0, 3).toInt()];
  ai.useQ = lv.depth >= 2;
  ai.sw.start();
  final totals = <int, int>{};
  final order = <int>[];
  var done = 0;
  for (var s = 0; s < lv.samples; s++) {
    if (s > 0 && ai.sw.elapsedMilliseconds > lv.ms) break;
    ai.timeMs = s == 0 ? (1 << 30) : lv.ms * 3;
    final ids = List<int>.from(pool);
    for (var i = ids.length - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final t = ids[i];
      ids[i] = ids[j];
      ids[j] = t;
    }
    for (var i = 0; i < hiddenSq.length; i++) {
      ai.pc[hiddenSq[i]] = ids.isEmpty ? 0 : ids[i % ids.length];
    }
    // 万一未知身份不够，用随机棋子补上，避免出现空格
    for (final sq in hiddenSq) {
      if (ai.pc[sq] == 0) ai.pc[sq] = 5;
    }
    ai.rebuild();
    final n = ai._gen(0, false);
    if (n == 0) return -1;
    final roots = <int>[for (var i = 0; i < n; i++) ai.mv[i]];
    final scores = <int, int>{};
    var aborted = false;
    for (final m in roots) {
      final key = ai._key(m);
      final cap = (m >> 14) & 15;
      int sc;
      if ((cap & 7) == 1) {
        sc = ai._kingCapScore(cap, 0);
      } else {
        ai._make(m);
        if (lv.depth <= 1) {
          sc = -ai.evalSide();
        } else {
          sc = -ai.search(lv.depth - 1, -kInf, kInf, 1);
        }
        ai._unmake(m);
        if (ai.stopped) {
          aborted = true;
          break;
        }
      }
      scores[key] = sc;
    }
    if (aborted) {
      ai.stopped = false;
      if (s > 0) break;
    }
    if (done == 0) {
      order.addAll(scores.keys);
    }
    scores.forEach((k, v) {
      totals[k] = (totals[k] ?? 0) + v;
    });
    done++;
  }
  if (order.isEmpty) return -1;
  if (rnd.nextDouble() < lv.rnd) return order[rnd.nextInt(order.length)];
  var bestKey = order[0];
  var bestScore = -(1 << 30);
  final cnt = done == 0 ? 1 : done;
  for (final k in order) {
    var s = (totals[k] ?? 0) ~/ cnt;
    if (lv.noise > 0) s += rnd.nextInt(lv.noise * 2 + 1) - lv.noise;
    if (s > bestScore) {
      bestScore = s;
      bestKey = k;
    }
  }
  return bestKey;
}
