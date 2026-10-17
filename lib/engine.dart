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
