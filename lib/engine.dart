import 'dart:math';

enum Side { red, black }

extension SideX on Side {
  Side get other => this == Side.red ? Side.black : Side.red;
  String get cn => this == Side.red ? '红方' : '黑方';
}

enum PType { king, advisor, elephant, horse, rook, cannon, pawn }

class Piece {
  final PType type;
  final Side side;
  const Piece(this.type, this.side);

  String get label {
    const r = {
      PType.king: '帅', PType.advisor: '仕', PType.elephant: '相',
      PType.horse: '马', PType.rook: '车', PType.cannon: '炮', PType.pawn: '兵'
    };
    const k = {
      PType.king: '将', PType.advisor: '士', PType.elephant: '象',
      PType.horse: '马', PType.rook: '车', PType.cannon: '炮', PType.pawn: '卒'
    };
    return (side == Side.red ? r : k)[type]!;
  }
}

class Move {
  final int fr, fc, tr, tc;
  const Move(this.fr, this.fc, this.tr, this.tc);
}

class MoveRecord {
  final Move move;
  final Piece? captured;
  final Side prevTurn;
  MoveRecord(this.move, this.captured, this.prevTurn);
}

class Game {
  final List<List<Piece?>> b =
      List.generate(10, (_) => List<Piece?>.filled(9, null));
  Side turn = Side.red;
  final List<MoveRecord> history = [];

  Game() {
    reset();
  }

  void reset() {
    for (final row in b) {
      row.fillRange(0, 9, null);
    }
    turn = Side.red;
    history.clear();
    const back = [
      PType.rook, PType.horse, PType.elephant, PType.advisor, PType.king,
      PType.advisor, PType.elephant, PType.horse, PType.rook
    ];
    for (var c = 0; c < 9; c++) {
      b[0][c] = Piece(back[c], Side.black);
      b[9][c] = Piece(back[c], Side.red);
    }
    b[2][1] = const Piece(PType.cannon, Side.black);
    b[2][7] = const Piece(PType.cannon, Side.black);
    b[7][1] = const Piece(PType.cannon, Side.red);
    b[7][7] = const Piece(PType.cannon, Side.red);
    for (final c in [0, 2, 4, 6, 8]) {
      b[3][c] = const Piece(PType.pawn, Side.black);
      b[6][c] = const Piece(PType.pawn, Side.red);
    }
  }

  bool _in(int r, int c) => r >= 0 && r <= 9 && c >= 0 && c <= 8;

  List<Move> pseudoMoves(int r, int c) {
    final p = b[r][c];
    if (p == null) return [];
    final res = <Move>[];
    final red = p.side == Side.red;
    void add(int nr, int nc) {
      if (!_in(nr, nc)) return;
      final t = b[nr][nc];
      if (t != null && t.side == p.side) return;
      res.add(Move(r, c, nr, nc));
    }

    const orth = [[1, 0], [-1, 0], [0, 1], [0, -1]];
    const diag = [[1, 1], [1, -1], [-1, 1], [-1, -1]];
    bool inPalace(int nr, int nc) =>
        nc >= 3 && nc <= 5 && (red ? (nr >= 7 && nr <= 9) : (nr >= 0 && nr <= 2));

    switch (p.type) {
      case PType.king:
        for (final d in orth) {
          final nr = r + d[0], nc = c + d[1];
          if (inPalace(nr, nc)) add(nr, nc);
        }
        break;
      case PType.advisor:
        for (final d in diag) {
          final nr = r + d[0], nc = c + d[1];
          if (inPalace(nr, nc)) add(nr, nc);
        }
        break;
      case PType.elephant:
        for (final d in diag) {
          final nr = r + 2 * d[0], nc = c + 2 * d[1];
          if (!_in(nr, nc)) continue;
          if (red ? nr < 5 : nr > 4) continue;
          if (b[r + d[0]][c + d[1]] != null) continue;
          add(nr, nc);
        }
        break;
      case PType.horse:
        for (final d in orth) {
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
        for (final d in orth) {
          var nr = r + d[0], nc = c + d[1];
          while (_in(nr, nc)) {
            final t = b[nr][nc];
            if (t == null) {
              res.add(Move(r, c, nr, nc));
            } else {
              if (t.side != p.side) res.add(Move(r, c, nr, nc));
              break;
            }
            nr += d[0];
            nc += d[1];
          }
        }
        break;
      case PType.cannon:
        for (final d in orth) {
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
              if (t.side != p.side) res.add(Move(r, c, nr, nc));
              break;
            }
            nr += d[0];
            nc += d[1];
          }
        }
        break;
      case PType.pawn:
        final dir = red ? -1 : 1;
        add(r + dir, c);
        final crossed = red ? r <= 4 : r >= 5;
        if (crossed) {
          add(r, c - 1);
          add(r, c + 1);
        }
        break;
    }
    return res;
  }

  bool hasKing(Side s) {
    for (final row in b) {
      for (final p in row) {
        if (p != null && p.type == PType.king && p.side == s) return true;
      }
    }
    return false;
  }

  bool inCheck(Side s) {
    var kr = -1, kc = -1, er = -1, ec = -1;
    for (var r = 0; r < 10; r++) {
      for (var c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p != null && p.type == PType.king) {
          if (p.side == s) {
            kr = r;
            kc = c;
          } else {
            er = r;
            ec = c;
          }
        }
      }
    }
    if (kr < 0) return true;
    if (er >= 0 && ec == kc) {
      var blocked = false;
      for (var r = min(kr, er) + 1; r < max(kr, er); r++) {
        if (b[r][kc] != null) {
          blocked = true;
          break;
        }
      }
      if (!blocked) return true;
    }
    for (var r = 0; r < 10; r++) {
      for (var c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p != null && p.side != s) {
          for (final m in pseudoMoves(r, c)) {
            if (m.tr == kr && m.tc == kc) return true;
          }
        }
      }
    }
    return false;
  }

List<Move> legalMoves(int r, int c) {
    final p = b[r][c];
    if (p == null) return [];
    final res = pseudoMoves(r, c);
    if (p.type == PType.king) {
      final step = p.side == Side.red ? -1 : 1;
      for (var rr = r + step; rr >= 0 && rr <= 9; rr += step) {
        final t = b[rr][c];
        if (t == null) continue;
        if (t.type == PType.king && t.side != p.side) {
          res.add(Move(r, c, rr, c));
        }
        break;
      }
    }
    return res;
}

  bool hasLegalMove(Side s) {
    for (var r = 0; r < 10; r++) {
      for (var c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p != null && p.side == s && legalMoves(r, c).isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  bool play(Move m, {bool strict = true}) {
    final p = b[m.fr][m.fc];
    if (p == null) return false;
    if (strict) {
      if (p.side != turn) return false;
      final ok = legalMoves(m.fr, m.fc)
          .any((x) => x.tr == m.tr && x.tc == m.tc);
      if (!ok) return false;
    } else {
      if (m.fr == m.tr && m.fc == m.tc) return false;
      final t = b[m.tr][m.tc];
      if (t != null && t.side == p.side) return false;
    }
    final cap = b[m.tr][m.tc];
    history.add(MoveRecord(m, cap, turn));
    b[m.tr][m.tc] = p;
    b[m.fr][m.fc] = null;
    turn = p.side.other;
    return true;
  }

  void undo() {
    if (history.isEmpty) return;
    final h = history.removeLast();
    b[h.move.fr][h.move.fc] = b[h.move.tr][h.move.tc];
    b[h.move.tr][h.move.tc] = h.captured;
    turn = h.prevTurn;
  }
}
