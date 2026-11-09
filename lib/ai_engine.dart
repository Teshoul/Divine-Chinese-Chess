import 'dart:math';
import 'dart:typed_data';

// ════════════════════════════════════════════════════════════════
//  象棋 AI 引擎（纯 Dart，没有任何 Flutter 依赖，可放进后台线程运行）
//
//  棋子编号：红方 1~7，黑方 9~15（低 3 位是种类，第 4 位是阵营）
//  种类：1 将帅  2 仕士  3 相象  4 马  5 车  6 炮  7 兵卒
//  格子编号：行 * 9 + 列（第 0 行是黑方底线，第 9 行是红方底线）
//  走法编码：from | to<<7 | 被吃子<<14
//
//  规则与游戏一致：被将军后不强制应将，吃掉将/帅即获胜，
//  将帅对面时可以直接飞吃。
// ════════════════════════════════════════════════════════════════

const int kInf = 32000;
const int kMate = 30000;
const int kSideIdx = 32 * 90;

const List<int> _matVal = [0, 0, 200, 200, 430, 1000, 470, 100];
const List<int> kOrdVal = [0, 20000, 200, 200, 430, 1000, 470, 100];

int _pst(int type, int adv, int c) {
  final dc = (c - 4).abs();
  switch (type) {
    case 1:
      {
        var v = 0;
        if (adv == 1) v = -4;
        if (adv == 2) v = -24;
        if (dc != 0) v -= 2;
        return v;
      }
    case 2:
      return (adv == 1 && c == 4) ? 10 : 0;
    case 3:
      return (adv == 2 && c == 4) ? 8 : 0;
    case 4:
      {
        var v = 24 - dc * 5 - (adv - 5).abs() * 3;
        if (adv == 0) v -= 10;
        if (dc == 4) v -= 8;
        return v;
      }
    case 5:
      return adv * 4 + (dc <= 1 ? 8 : 0) + (adv >= 8 ? 12 : 0);
    case 6:
      return (c == 4 ? 14 : 0) + adv * 2 - (adv == 0 ? 6 : 0);
    default:
      {
        if (adv < 5) return (adv == 4 ? 8 : 0) + (dc == 0 ? 4 : 0);
        var v = 55 + (adv - 5) * 14;
        if (adv == 9) v -= 40;
        if (dc <= 1) v += 12;
        if (dc == 4) v -= 8;
        return v;
      }
  }
}

/// 红方视角的子力 + 位置分（黑子为负）
final Int16List kPv = _buildPv();

Int16List _buildPv() {
  final t = Int16List(16 * 90);
  for (var id = 1; id < 16; id++) {
    final type = id & 7;
    if (type == 0) continue;
    final black = (id >> 3) == 1;
    for (var sq = 0; sq < 90; sq++) {
      final r = sq ~/ 9;
      final c = sq - r * 9;
      final adv = black ? r : 9 - r;
      final v = _matVal[type] + _pst(type, adv, c);
      t[id * 90 + sq] = black ? -v : v;
    }
  }
  return t;
}

final Int64List kZob = _buildZob();

Int64List _buildZob() {
  final z = Int64List(32 * 90 + 1);
  var s = 0x2545F4914F6CDD1D;
  for (var i = 0; i < z.length; i++) {
    s ^= (s << 13);
    s ^= (s >>> 7);
    s ^= (s << 17);
    z[i] = s;
  }
  return z;
}

bool _inPalace(int side, int r, int c) =>
    c >= 3 && c <= 5 && (side == 0 ? (r >= 7 && r <= 9) : (r >= 0 && r <= 2));

const List<List<int>> _orth = [
  [1, 0],
  [-1, 0],
  [0, 1],
  [0, -1]
];
const List<List<int>> _diag = [
  [1, 1],
  [1, -1],
  [-1, 1],
  [-1, -1]
];

final List<Int16List> _kingT = _buildKing();
final List<Int16List> _advT = _buildAdv();
final List<Int16List> _eleT = _buildEle();
final List<Int16List> _horseT = _buildHorse();
final List<Int16List> _pawnT = _buildPawn();

List<Int16List> _buildKing() {
  final out = <Int16List>[];
  for (var s = 0; s < 2; s++) {
    for (var sq = 0; sq < 90; sq++) {
      final r = sq ~/ 9;
      final c = sq - r * 9;
      final l = <int>[];
      if (_inPalace(s, r, c)) {
        for (final d in _orth) {
          final nr = r + d[0];
          final nc = c + d[1];
          if (_inPalace(s, nr, nc)) l.add(nr * 9 + nc);
        }
      }
      out.add(Int16List.fromList(l));
    }
  }
  return out;
}

List<Int16List> _buildAdv() {
  final out = <Int16List>[];
  for (var s = 0; s < 2; s++) {
    for (var sq = 0; sq < 90; sq++) {
      final r = sq ~/ 9;
      final c = sq - r * 9;
      final l = <int>[];
      if (_inPalace(s, r, c)) {
        for (final d in _diag) {
          final nr = r + d[0];
          final nc = c + d[1];
          if (_inPalace(s, nr, nc)) l.add(nr * 9 + nc);
        }
      }
      out.add(Int16List.fromList(l));
    }
  }
  return out;
}

List<Int16List> _buildEle() {
  final out = <Int16List>[];
  for (var s = 0; s < 2; s++) {
    for (var sq = 0; sq < 90; sq++) {
      final r = sq ~/ 9;
      final c = sq - r * 9;
      final l = <int>[];
      for (final d in _diag) {
        final nr = r + 2 * d[0];
        final nc = c + 2 * d[1];
        if (nr < 0 || nr > 9 || nc < 0 || nc > 8) continue;
        if (s == 0 ? nr < 5 : nr > 4) continue;
        l.add(nr * 9 + nc);
        l.add((r + d[0]) * 9 + (c + d[1]));
      }
      out.add(Int16List.fromList(l));
    }
  }
  return out;
}

List<Int16List> _buildHorse() {
  final out = <Int16List>[];
  for (var sq = 0; sq < 90; sq++) {
    final r = sq ~/ 9;
    final c = sq - r * 9;
    final l = <int>[];
    for (final d in _orth) {
      final lr = r + d[0];
      final lc = c + d[1];
      if (lr < 0 || lr > 9 || lc < 0 || lc > 8) continue;
      final targets = <List<int>>[];
      if (d[0] != 0) {
        targets.add([r + 2 * d[0], c - 1]);
        targets.add([r + 2 * d[0], c + 1]);
      } else {
        targets.add([r - 1, c + 2 * d[1]]);
        targets.add([r + 1, c + 2 * d[1]]);
      }
      for (final t in targets) {
        if (t[0] < 0 || t[0] > 9 || t[1] < 0 || t[1] > 8) continue;
        l.add(t[0] * 9 + t[1]);
        l.add(lr * 9 + lc);
      }
    }
    out.add(Int16List.fromList(l));
  }
  return out;
}

List<Int16List> _buildPawn() {
  final out = <Int16List>[];
  for (var s = 0; s < 2; s++) {
    for (var sq = 0; sq < 90; sq++) {
      final r = sq ~/ 9;
      final c = sq - r * 9;
      final l = <int>[];
      final fr = s == 0 ? r - 1 : r + 1;
      if (fr >= 0 && fr <= 9) l.add(fr * 9 + c);
      final crossed = s == 0 ? r <= 4 : r >= 5;
      if (crossed) {
        if (c > 0) l.add(r * 9 + c - 1);
        if (c < 8) l.add(r * 9 + c + 1);
      }
      out.add(Int16List.fromList(l));
    }
  }
  return out;
}

const List<int> _hDr = [2, 2, -2, -2, 1, 1, -1, -1];
const List<int> _hDc = [1, -1, 1, -1, 2, -2, 2, -2];

List<int> xqInitBoard() {
  final b = List<int>.filled(90, 0);
  const back = [5, 4, 3, 2, 1, 2, 3, 4, 5];
  for (var c = 0; c < 9; c++) {
    b[c] = back[c] | 8;
    b[81 + c] = back[c];
  }
  b[2 * 9 + 1] = 6 | 8;
  b[2 * 9 + 7] = 6 | 8;
  b[7 * 9 + 1] = 6;
  b[7 * 9 + 7] = 6;
  for (final c in const [0, 2, 4, 6, 8]) {
    b[3 * 9 + c] = 7 | 8;
    b[6 * 9 + c] = 7;
  }
  return b;
}

class XqAi {
  final Int8List b = Int8List(90);
  int side = 0;
  int hash = 0;
  int ev = 0;
  final Int32List att = Int32List(2);
  int nodes = 0;
  bool stopped = false;
  bool useQ = true;
  int timeMs = 1000;
  final Stopwatch sw = Stopwatch();
  final Int32List mv = Int32List(64 * 128);
  final Int32List sco = Int32List(64 * 128);
  final Int32List killers = Int32List(64 * 2);
  final Int32List hist = Int32List(8100);
  final Int64List rep = Int64List(1024);
  int repLen = 0;
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

  void setBoard(List<int> board, int s) {
    for (var i = 0; i < 90; i++) {
      b[i] = board[i];
    }
    side = s;
    _recompute();
    rep[0] = hash;
    repLen = 1;
  }

  void _recompute() {
    hash = side == 1 ? kZob[kSideIdx] : 0;
    ev = 0;
    att[0] = 0;
    att[1] = 0;
    for (var sq = 0; sq < 90; sq++) {
      final p = b[sq];
      if (p == 0) continue;
      hash ^= kZob[p * 90 + sq];
      ev += kPv[p * 90 + sq];
      final t = p & 7;
      if (t >= 4 && t <= 6) att[p >> 3]++;
    }
  }

  /// 用整局的走法重放出历史局面，用来避免重复走棋
  void loadHistory(List<int> moves) {
    final tmp = XqAi();
    tmp.setBoard(xqInitBoard(), 0);
    final hs = <int>[tmp.hash];
    for (final key in moves) {
      final from = key ~/ 90;
      final to = key % 90;
      final cap = tmp.b[to];
      tmp._make(from | (to << 7) | (cap << 14));
      hs.add(tmp.hash);
    }
    if (hs.last != hash) {
      repLen = 1;
      rep[0] = hash;
      return;
    }
    final start = max(0, hs.length - 400);
    repLen = 0;
    for (var i = start; i < hs.length; i++) {
      rep[repLen++] = hs[i];
    }
  }

  int evalSide() => (side == 0 ? ev : -ev) + 8;

  void _make(int m) {
    final from = m & 127;
    final to = (m >> 7) & 127;
    final cap = (m >> 14) & 15;
    final p = b[from];
    b[from] = 0;
    b[to] = p;
    hash ^= kZob[p * 90 + from] ^ kZob[p * 90 + to] ^ kZob[kSideIdx];
    ev += kPv[p * 90 + to] - kPv[p * 90 + from];
    if (cap != 0) {
      hash ^= kZob[cap * 90 + to];
      ev -= kPv[cap * 90 + to];
      final ct = cap & 7;
      if (ct >= 4 && ct <= 6) att[cap >> 3]--;
    }
    side ^= 1;
  }

  void _unmake(int m) {
    final from = m & 127;
    final to = (m >> 7) & 127;
    final cap = (m >> 14) & 15;
    final p = b[to];
    b[from] = p;
    b[to] = cap;
    hash ^= kZob[p * 90 + from] ^ kZob[p * 90 + to] ^ kZob[kSideIdx];
    ev -= kPv[p * 90 + to] - kPv[p * 90 + from];
    if (cap != 0) {
      hash ^= kZob[cap * 90 + to];
      ev += kPv[cap * 90 + to];
      final ct = cap & 7;
      if (ct >= 4 && ct <= 6) att[cap >> 3]++;
    }
    side ^= 1;
  }

  void _add(int from, int to, bool caps) {
    final q = b[to];
    if (q != 0) {
      if ((q >> 3) == side) return;
    } else if (caps) {
      return;
    }
    if (_n >= 127) return;
    mv[_base + _n] = from | (to << 7) | (q << 14);
    _n++;
  }

  void _rays(int sq, int r, int c, bool cannon, bool caps) {
    for (var d = 0; d < 4; d++) {
      final dq = d == 0 ? -9 : (d == 1 ? 9 : (d == 2 ? -1 : 1));
      final steps = d == 0 ? r : (d == 1 ? 9 - r : (d == 2 ? c : 8 - c));
      var q = sq;
      var screen = false;
      for (var k = 0; k < steps; k++) {
        q += dq;
        final x = b[q];
        if (!cannon) {
          if (x == 0) {
            _add(sq, q, caps);
          } else {
            _add(sq, q, caps);
            break;
          }
        } else if (!screen) {
          if (x == 0) {
            _add(sq, q, caps);
          } else {
            screen = true;
          }
        } else if (x != 0) {
          _add(sq, q, caps);
          break;
        }
      }
    }
  }

  int _gen(int ply, bool caps) {
    _base = ply * 128;
    _n = 0;
    final s = side;
    for (var sq = 0; sq < 90; sq++) {
      final p = b[sq];
      if (p == 0 || (p >> 3) != s) continue;
      final t = p & 7;
      final r = sq ~/ 9;
      final c = sq - r * 9;
      switch (t) {
        case 1:
          {
            final l = _kingT[s * 90 + sq];
            for (var i = 0; i < l.length; i++) {
              _add(sq, l[i], caps);
            }
            final step = s == 0 ? -9 : 9;
            var q = sq + step;
            while (q >= 0 && q < 90) {
              final pc = b[q];
              if (pc != 0) {
                if ((pc & 7) == 1 && (pc >> 3) != s) _add(sq, q, caps);
                break;
              }
              q += step;
            }
            break;
          }
        case 2:
          {
            final l = _advT[s * 90 + sq];
            for (var i = 0; i < l.length; i++) {
              _add(sq, l[i], caps);
            }
            break;
          }
        case 3:
          {
            final l = _eleT[s * 90 + sq];
            for (var i = 0; i < l.length; i += 2) {
              if (b[l[i + 1]] == 0) _add(sq, l[i], caps);
            }
            break;
          }
        case 4:
          {
            final l = _horseT[sq];
            for (var i = 0; i < l.length; i += 2) {
              if (b[l[i + 1]] == 0) _add(sq, l[i], caps);
            }
            break;
          }
        case 5:
          {
            _rays(sq, r, c, false, caps);
            break;
          }
        case 6:
          {
            _rays(sq, r, c, true, caps);
            break;
          }
        default:
          {
            final l = _pawnT[s * 90 + sq];
            for (var i = 0; i < l.length; i++) {
              _add(sq, l[i], caps);
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
        s = 1000000 + kOrdVal[cap & 7] * 16 - (kOrdVal[b[from] & 7] ~/ 16);
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

  bool _attacked(int ks, int e) {
    final r = ks ~/ 9;
    final c = ks - r * 9;
    final eo = e << 3;
    for (var d = 0; d < 4; d++) {
      final dq = d == 0 ? -9 : (d == 1 ? 9 : (d == 2 ? -1 : 1));
      final steps = d == 0 ? r : (d == 1 ? 9 - r : (d == 2 ? c : 8 - c));
      var q = ks;
      var screen = false;
      for (var k = 0; k < steps; k++) {
        q += dq;
        final x = b[q];
        if (x == 0) continue;
        if (!screen) {
          if ((x >> 3) == e) {
            final t = x & 7;
            if (t == 5) return true;
            if (t == 1 && d < 2) return true;
          }
          screen = true;
        } else {
          if (x == (6 | eo)) return true;
          break;
        }
      }
    }
    for (var i = 0; i < 8; i++) {
      final a = _hDr[i];
      final bb = _hDc[i];
      final hr = r - a;
      final hc = c - bb;
      if (hr < 0 || hr > 9 || hc < 0 || hc > 8) continue;
      if (b[hr * 9 + hc] != (4 | eo)) continue;
      final lr = hr + (a.abs() == 2 ? (a > 0 ? 1 : -1) : 0);
      final lc = hc + (bb.abs() == 2 ? (bb > 0 ? 1 : -1) : 0);
      if (b[lr * 9 + lc] == 0) return true;
    }
    final pid = 7 | eo;
    final fr = e == 0 ? r + 1 : r - 1;
    if (fr >= 0 && fr <= 9 && b[fr * 9 + c] == pid) return true;
    final crossed = e == 0 ? r <= 4 : r >= 5;
    if (crossed) {
      if (c > 0 && b[r * 9 + c - 1] == pid) return true;
      if (c < 8 && b[r * 9 + c + 1] == pid) return true;
    }
    return false;
  }

  bool _inCheck() {
    final s = side;
    final r0 = s == 0 ? 7 : 0;
    final kid = 1 | (s << 3);
    var ks = -1;
    for (var r = r0; r < r0 + 3; r++) {
      for (var c = 3; c < 6; c++) {
        if (b[r * 9 + c] == kid) ks = r * 9 + c;
      }
    }
    if (ks < 0) return true;
    return _attacked(ks, s ^ 1);
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
      if ((cap & 7) == 1) return kMate - ply - 1;
      if (stand + kOrdVal[cap & 7] + 220 < alpha) continue;
      _make(m);
      final score = -_qsearch(-beta, -alpha, ply + 1);
      _unmake(m);
      if (score >= beta) return score;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  int search(int depth, int alpha, int beta, int ply, bool nullOk) {
    if ((++nodes & 2047) == 0 && sw.elapsedMilliseconds > timeMs) stopped = true;
    if (stopped) return 0;
    if (ply >= 56) return evalSide();

    if (ply > 0) {
      final lo = max(0, repLen - 80);
      for (var i = repLen - 3; i >= lo; i -= 2) {
        if (rep[i] == hash) return 0;
      }
    }

    final inChk = _inCheck();
    if (inChk && ply < 40) depth++;
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

    if (nullOk && !inChk && depth >= 3 && beta < kMate - 200 && att[side] >= 2) {
      side ^= 1;
      hash ^= kZob[kSideIdx];
      rep[repLen++] = hash;
      final s = -search(depth - 3, -beta, -beta + 1, ply + 1, false);
      repLen--;
      hash ^= kZob[kSideIdx];
      side ^= 1;
      if (stopped) return 0;
      if (s >= beta) return s;
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
      if ((cap & 7) == 1) {
        return kMate - ply - 1;
      }
      _make(m);
      rep[repLen++] = hash;
      int score;
      if (searched == 0) {
        score = -search(depth - 1, -beta, -alpha, ply + 1, true);
      } else {
        var red = 0;
        if (depth >= 3 && i >= 4 && cap == 0 && !inChk) red = 1;
        score = -search(depth - 1 - red, -alpha - 1, -alpha, ply + 1, true);
        if (score > alpha && (red > 0 || score < beta)) {
          score = -search(depth - 1, -beta, -alpha, ply + 1, true);
        }
      }
      repLen--;
      _unmake(m);
      searched++;
      if (stopped) return 0;
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

class _Lv {
  final int depth;
  final bool q;
  final int noise;
  final double rnd;
  final int ms;
  final bool id;
  final int bits;
  const _Lv(this.depth, this.q, this.noise, this.rnd, this.ms, this.id, this.bits);
}

const List<_Lv> _levels = [
  _Lv(1, false, 300, 0.40, 400, false, 12),
  _Lv(2, false, 120, 0.12, 600, false, 14),
  _Lv(3, true, 40, 0.02, 1500, false, 16),
  _Lv(8, true, 0, 0.0, 3000, true, 19),
  _Lv(30, true, 0, 0.0, 8500, true, 21),
];

int _bk(int fr, int fc, int tr, int tc) => (fr * 9 + fc) * 90 + tr * 9 + tc;

/// 开局库：只在最开始的一两步使用，走法会先和真实可走的招法核对
int _book(List<int> rootKeys, int histLen, Random rnd) {
  final List<int> cand;
  if (histLen == 0) {
    cand = [
      _bk(7, 7, 7, 4),
      _bk(7, 1, 7, 4),
      _bk(9, 7, 7, 6),
      _bk(9, 6, 7, 4),
      _bk(9, 2, 7, 4),
    ];
  } else {
    cand = [
      _bk(0, 7, 2, 6),
      _bk(0, 1, 2, 2),
      _bk(2, 1, 2, 4),
      _bk(2, 7, 2, 4),
    ];
  }
  final ok = <int>[];
  for (final k in cand) {
    if (rootKeys.contains(k)) ok.add(k);
  }
  if (ok.isEmpty) return -1;
  return ok[rnd.nextInt(ok.length)];
}

/// 返回 from*90+to；没有可走的棋返回 -1
/// board：90 个格子；side：0 红 1 黑（轮到谁走）；level：0~4
int xqAiPick(List<int> board, int side, int level, int seed, List<int> hist) {
  final lv = _levels[level.clamp(0, 4).toInt()];
  final ai = XqAi();
  ai.setBoard(board, side);
  ai.loadHistory(hist);
  final rnd = Random(seed);
  final n = ai._gen(0, false);
  if (n == 0) return -1;
  final roots = <int>[for (var i = 0; i < n; i++) ai.mv[i]];
  final rootKeys = <int>[for (final m in roots) ai._key(m)];
  for (final m in roots) {
    if ((((m >> 14) & 15) & 7) == 1) return ai._key(m);
  }
  if (rnd.nextDouble() < lv.rnd) return rootKeys[rnd.nextInt(n)];

  ai.useQ = lv.q;
  ai.timeMs = lv.ms;
  ai.sw.start();

  if (!lv.id) {
    var bestKey = rootKeys[0];
    var bestScore = -(1 << 30);
    for (var i = 0; i < n; i++) {
      final m = roots[i];
      ai._make(m);
      ai.rep[ai.repLen++] = ai.hash;
      int s;
      if (lv.depth <= 1) {
        s = -ai.evalSide();
      } else {
        s = -ai.search(lv.depth - 1, -kInf, kInf, 1, true);
      }
      ai.repLen--;
      ai._unmake(m);
      if (lv.noise > 0) s += rnd.nextInt(lv.noise * 2 + 1) - lv.noise;
      if (s > bestScore) {
        bestScore = s;
        bestKey = rootKeys[i];
      }
    }
    return bestKey;
  }

  if (level >= 3 && hist.length <= 1) {
    final bk = _book(rootKeys, hist.length, rnd);
    if (bk >= 0) return bk;
  }

  ai.initTT(lv.bits);
  var best = 0;
  for (var d = 1; d <= lv.depth; d++) {
    ai.rootBest = 0;
    final s = ai.search(d, -kInf, kInf, 0, false);
    if (ai.stopped) break;
    if (ai.rootBest != 0) best = ai.rootBest;
    if (s >= kMate - 100) break;
    if (ai.sw.elapsedMilliseconds * 10 > lv.ms * 5) break;
  }
  if (best == 0) best = roots[0];
  return ai._key(best);
}
