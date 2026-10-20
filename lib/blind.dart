import 'engine.dart';

const _orth = [[1, 0], [-1, 0], [0, 1], [0, -1]];
const _diag = [[1, 1], [1, -1], [-1, 1], [-1, -1]];

class BlindConfig {
  List<List<bool>> up;
  bool kingInPalace;
  bool advElephantLimit;

  BlindConfig(
      {List<List<bool>>? up,
      this.kingInPalace = true,
      this.advElephantLimit = false})
      : up = up ?? List.generate(10, (_) => List<bool>.filled(9, false));

  static BlindConfig rule(bool Function(PType, Side) f) {
    final g = Game();
    final c = BlindConfig();
    for (var r = 0; r < 10; r++) {
      for (var col = 0; col < 9; col++) {
        final p = g.b[r][col];
        if (p != null) c.up[r][col] = f(p.type, p.side);
      }
    }
    return c;
  }

  static BlindConfig kingsOnly() => rule((t, s) => t == PType.king);
  static BlindConfig kingsAdvisors() =>
      rule((t, s) => t == PType.king || t == PType.advisor);
  static BlindConfig allUp() => rule((t, s) => true);
  static BlindConfig allDown() => rule((t, s) => false);

  Map<String, dynamic> toJson() => {
        'up': [
          for (final row in up)
            for (final v in row) v
        ],
        'k': kingInPalace,
        'ae': advElephantLimit,
      };

  static BlindConfig fromJson(Map<String, dynamic> j) {
    final flat = (j['up'] as List).cast<bool>();
    final c = BlindConfig(
        kingInPalace: j['k'] as bool, advElephantLimit: j['ae'] as bool);
    for (var i = 0; i < 90; i++) {
      c.up[i ~/ 9][i % 9] = flat[i];
    }
    return c;
  }
}

class BPiece {
  final PType type;
  final Side side;
  bool up;
  final PType posType;
  final Side posSide;
  BPiece(this.type, this.side, this.up, this.posType, this.posSide);
  Side get owner => up ? side : posSide;
  String get label => Piece(type, side).label;
}

class _Rec {
  final Move m;
  final BPiece? cap;
  final bool capWasUp;
  final bool wasUp;
  final Side prevTurn;
  final bool swap;
  _Rec(this.m, this.cap, this.capWasUp, this.wasUp, this.prevTurn, {this.swap = false});
}

class BlindGame {
  final BlindConfig cfg;
  late final List<List<BPiece?>> b;
  Side turn = Side.red;
  Side? winner;
  Move? last;
  final List<BPiece> deadRed = [];
  final List<BPiece> deadBlack = [];
  final List<_Rec> _hist = [];

  bool get canUndo => _hist.isNotEmpty;

  BlindGame(this.cfg, int seed) {
    final lay = Game().b;
    b = List.generate(10, (_) => List<BPiece?>.filled(9, null));
    final hidden = <List<int>>[];
    final pool = <Piece>[];
    for (var r = 0; r < 10; r++) {
      for (var c = 0; c < 9; c++) {
        final p = lay[r][c];
        if (p == null) continue;
        if (cfg.up[r][c]) {
          b[r][c] = BPiece(p.type, p.side, true, p.type, p.side);
        } else {
          hidden.add([r, c]);
          pool.add(p);
        }
      }
    }
    var s = seed & 0x7fffffff;
    int next(int n) {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      return (s >> 8) % n;
    }

    for (var i = pool.length - 1; i > 0; i--) {
      final j = next(i + 1);
      final t = pool[i];
      pool[i] = pool[j];
      pool[j] = t;
    }
    for (var i = 0; i < hidden.length; i++) {
      final r = hidden[i][0], c = hidden[i][1];
      final home = lay[r][c]!;
      b[r][c] = BPiece(pool[i].type, pool[i].side, false, home.type, home.side);
    }
  }

  bool _in(int r, int c) => r >= 0 && r <= 9 && c >= 0 && c <= 8;
  bool _palace(Side s, int r, int c) =>
      c >= 3 && c <= 5 && (s == Side.red ? r >= 7 : r <= 2);
  bool _home(Side s, int r) => s == Side.red ? r >= 5 : r <= 4;

  List<Move> movesFor(int r, int c) {
    final p = b[r][c];
    if (p == null || winner != null) return [];
    final owner = p.owner;
    final PType type = p.up ? p.type : p.posType;
    final Side color = p.up ? p.side : p.posSide;
    final strict = !p.up;
    final limitKing = strict || cfg.kingInPalace;
    final limitAE = strict || cfg.advElephantLimit;
    final res = <Move>[];

    bool canTake(BPiece t) => !t.up || t.side != owner;
    void add(int nr, int nc) {
      if (!_in(nr, nc)) return;
      final t = b[nr][nc];
      if (t != null && !canTake(t)) return;
      res.add(Move(r, c, nr, nc));
    }

    switch (type) {
      case PType.king:
        for (final d in _orth) {
          final nr = r + d[0], nc = c + d[1];
          if (limitKing && _palace(color, r, c) && !_palace(color, nr, nc)) {
            continue;
          }
          add(nr, nc);
        }
        break;
      case PType.advisor:
        for (final d in _diag) {
          final nr = r + d[0], nc = c + d[1];
          if (limitAE && _palace(color, r, c) && !_palace(color, nr, nc)) {
            continue;
          }
          add(nr, nc);
        }
        break;
      case PType.elephant:
        for (final d in _diag) {
          final nr = r + 2 * d[0], nc = c + 2 * d[1];
          if (!_in(nr, nc)) continue;
          if (b[r + d[0]][c + d[1]] != null) continue;
          if (limitAE && _home(color, r) && !_home(color, nr)) continue;
          add(nr, nc);
        }
        break;
      case PType.horse:
        for (final d in _orth) {
          final lr = r + d[0], lc = c + d[1];
          if (!_in(lr, lc) || b[lr][lc] != null) continue;
          if (d[0] != 0) {
            add(r + 2 * d[0], c - 1);
            add(r + 2 * d[0], c + 1);
          } else {
            add(r - 1, c + 2 * d[1]);
            add(r + 1, c + 2 * d[1]);
          }
        }
        break;
      case PType.rook:
        for (final d in _orth) {
          var nr = r + d[0], nc = c + d[1];
          while (_in(nr, nc)) {
            final t = b[nr][nc];
            if (t == null) {
              res.add(Move(r, c, nr, nc));
            } else {
              if (canTake(t)) res.add(Move(r, c, nr, nc));
              break;
            }
            nr += d[0];
            nc += d[1];
          }
        }
        break;
      case PType.cannon:
        for (final d in _orth) {
          var nr = r + d[0], nc = c + d[1];
          var screen = false;
          while (_in(nr, nc)) {
            final t = b[nr][nc];
            if (!screen) {
              if (t == null) {
                res.add(Move(r, c, nr, nc));
              } else {
                screen = true;
              }
            } else if (t != null) {
              if (canTake(t)) res.add(Move(r, c, nr, nc));
              break;
            }
            nr += d[0];
            nc += d[1];
          }
        }
        break;
      case PType.pawn:
        final dir = color == Side.red ? -1 : 1;
        add(r + dir, c);
        final crossed = color == Side.red ? r <= 4 : r >= 5;
        if (crossed) {
          add(r, c - 1);
          add(r, c + 1);
        }
        break;
    }
    return res;
  }

  bool _hasMove(Side s) {
    for (var r = 0; r < 10; r++) {
      for (var c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p != null && p.owner == s && movesFor(r, c).isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  /// 开发者：无视规则移动 / 吃子 / 调换
  bool devApply(Move m) {
    if (m.fr == m.tr && m.fc == m.tc) return false;
    final p = b[m.fr][m.fc];
    if (p == null) return false;
    final t = b[m.tr][m.tc];
    if (t != null && t.owner == p.owner) {
      _hist.add(_Rec(m, null, false, p.up, turn, swap: true));
      b[m.fr][m.fc] = t;
      b[m.tr][m.tc] = p;
      last = m;
      return true;
    }
    _hist.add(_Rec(m, t, t?.up ?? false, p.up, turn));
    if (t != null) {
      t.up = true;
      (t.side == Side.red ? deadRed : deadBlack).add(t);
    }
    b[m.tr][m.tc] = p;
    b[m.fr][m.fc] = null;
    last = m;
    if (p.owner == turn) {
      p.up = true;
      turn = turn.other;
    }
    if (t != null && t.type == PType.king) winner = t.side.other;
    return true;
  }
  bool play(Move m) {
    if (winner != null) return false;
    final p = b[m.fr][m.fc];
    if (p == null || p.owner != turn) return false;
    if (!movesFor(m.fr, m.fc).any((x) => x.tr == m.tr && x.tc == m.tc)) {
      return false;
    }
    final t = b[m.tr][m.tc];
    _hist.add(_Rec(m, t, t?.up ?? false, p.up, turn));
    if (t != null) {
      t.up = true;
      (t.side == Side.red ? deadRed : deadBlack).add(t);
    }
    b[m.tr][m.tc] = p;
    b[m.fr][m.fc] = null;
    p.up = true;
    last = m;
    if (t != null && t.type == PType.king) {
      winner = t.side.other;
    }
    turn = turn.other;
    if (winner == null && !_hasMove(turn)) winner = turn.other;
    return true;
  }

  void undo() {
    if (_hist.isEmpty) return;
    final h = _hist.removeLast();
    final p = b[h.m.tr][h.m.tc]!;
    if (h.swap) {
      final a = b[h.m.fr][h.m.fc];
      b[h.m.fr][h.m.fc] = p;
      b[h.m.tr][h.m.tc] = a;
    } else {
      p.up = h.wasUp;
      b[h.m.fr][h.m.fc] = p;
      b[h.m.tr][h.m.tc] = h.cap;
      final c = h.cap;
      if (c != null) {
        c.up = h.capWasUp;
        (c.side == Side.red ? deadRed : deadBlack).remove(c);
      }
    }
    turn = h.prevTurn;
    winner = null;
    last = _hist.isEmpty ? null : _hist.last.m;
  }
