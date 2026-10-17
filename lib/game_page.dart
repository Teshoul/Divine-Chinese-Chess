import 'package:flutter/material.dart';
import 'engine.dart';

class GamePage extends StatefulWidget {
  final bool free;
  const GamePage({super.key, required this.free});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final game = Game();
  int? sr, sc;
  List<Move> hints = [];
  Move? last;
  bool flip = false;
  bool strict = true;
  String? over;

  @override
  void initState() {
    super.initState();
    strict = !widget.free;
  }

  String get status {
    if (over != null) return over!;
    final chk = strict && game.inCheck(game.turn);
    return '${game.turn.cn}走棋${chk ? ' · 将军！' : ''}';
  }

  void clearSel() {
    sr = null;
    sc = null;
    hints = [];
  }

  void select(int r, int c) {
    final p = game.b[r][c];
    setState(() {
      if (p == null || (strict && p.side != game.turn)) {
        clearSel();
        return;
      }
      sr = r;
      sc = c;
      hints = strict ? game.legalMoves(r, c) : [];
    });
  }

  void checkOver() {
    for (final s in Side.values) {
      if (!game.hasKing(s)) {
        over = '${s.other.cn}获胜';
        return;
      }
    }
    if (strict && !game.hasLegalMove(game.turn)) {
      over = '${game.turn.cn}无路可走，${game.turn.other.cn}获胜';
    }
  }

  void onTap(int r, int c) {
    if (over != null) return;
    final p = game.b[r][c];
    if (sr != null) {
      final from = game.b[sr!][sc!];
      if (from != null && p != null && p.side == from.side) {
        select(r, c);
        return;
      }
      final m = Move(sr!, sc!, r, c);
      if (game.play(m, strict: strict)) {
        setState(() {
          last = m;
          clearSel();
          checkOver();
        });
      } else {
        setState(clearSel);
      }
      return;
    }
    select(r, c);
  }

  void undo() {
    setState(() {
      game.undo();
      last = game.history.isEmpty ? null : game.history.last.move;
      over = null;
      clearSel();
    });
  }

  void restart() {
    setState(() {
      game.reset();
      last = null;
      over = null;
      clearSel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.free ? '自由模式' : '普通对局')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(status,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AspectRatio(
                    aspectRatio: 9 / 10,
                    child: LayoutBuilder(builder: (ctx, cons) {
                      final cell = cons.maxWidth / 9;
                      return GestureDetector(
                        onTapUp: (d) {
                          var c = (d.localPosition.dx / cell).floor();
                          var r = (d.localPosition.dy / cell).floor();
                          if (c < 0 || c > 8 || r < 0 || r > 9) return;
                          if (flip) {
                            c = 8 - c;
                            r = 9 - r;
                          }
                          onTap(r, c);
                        },
                        child: CustomPaint(
                          size: Size(cons.maxWidth, cons.maxHeight),
                          painter: BoardPainter(game, last, sr, sc, hints, flip),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                      onPressed: undo,
                      icon: const Icon(Icons.undo),
                      label: const Text('悔棋')),
                  FilledButton.tonalIcon(
                      onPressed: () => setState(() => flip = !flip),
                      icon: const Icon(Icons.flip),
                      label: const Text('翻转')),
                  FilledButton.tonalIcon(
                      onPressed: restart,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重开')),
                  if (widget.free)
                    FilterChip(
                      label: const Text('规则校验'),
                      selected: strict,
                      onSelected: (v) => setState(() {
                        strict = v;
                        clearSel();
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _text(Canvas canvas, String s, Offset center, double size, Color color) {
  final tp = TextPainter(
    text: TextSpan(
        text: s,
        style: TextStyle(
            fontSize: size, color: color, fontWeight: FontWeight.bold)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

class BoardPainter extends CustomPainter {
  final Game game;
  final Move? last;
  final int? sr, sc;
  final List<Move> hints;
  final bool flip;
  BoardPainter(this.game, this.last, this.sr, this.sc, this.hints, this.flip);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 9;
    Offset pos(int r, int c) {
      final rr = flip ? 9 - r : r;
      final cc = flip ? 8 - c : c;
      return Offset(cell * (cc + 0.5), cell * (rr + 0.5));
    }

    const lineColor = Color(0xFF5B3A1E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(cell * 0.3)),
      Paint()..color = const Color(0xFFE9CB93),
    );
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    for (var r = 0; r < 10; r++) {
      canvas.drawLine(pos(r, 0), pos(r, 8), line);
    }
    for (var c = 0; c < 9; c++) {
      if (c == 0 || c == 8) {
        canvas.drawLine(pos(0, c), pos(9, c), line);
      } else {
        canvas.drawLine(pos(0, c), pos(4, c), line);
        canvas.drawLine(pos(5, c), pos(9, c), line);
      }
    }
    canvas.drawLine(pos(0, 3), pos(2, 5), line);
    canvas.drawLine(pos(0, 5), pos(2, 3), line);
    canvas.drawLine(pos(7, 3), pos(9, 5), line);
    canvas.drawLine(pos(7, 5), pos(9, 3), line);

    final river = lineColor.withOpacity(0.6);
    _text(canvas, '楚 河', Offset(cell * 2.5, cell * 5), cell * 0.5, river);
    _text(canvas, '汉 界', Offset(cell * 6.5, cell * 5), cell * 0.5, river);

    if (last != null) {
      final hl = Paint()
        ..color = const Color(0xFF1E88E5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(pos(last!.fr, last!.fc), cell * 0.46, hl);
      canvas.drawCircle(pos(last!.tr, last!.tc), cell * 0.46, hl);
    }

    for (var r = 0; r < 10; r++) {
      for (var c = 0; c < 9; c++) {
        final p = game.b[r][c];
        if (p == null) continue;
        final ctr = pos(r, c);
        final col = p.side == Side.red
            ? const Color(0xFFC62828)
            : const Color(0xFF212121);
        final rad = cell * 0.42;
        canvas.drawCircle(ctr + const Offset(0, 2), rad,
            Paint()..color = Colors.black26);
        canvas.drawCircle(ctr, rad, Paint()..color = const Color(0xFFF6E3B4));
        canvas.drawCircle(
            ctr,
            rad,
            Paint()
              ..color = col
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
        canvas.drawCircle(
            ctr,
            rad * 0.82,
            Paint()
              ..color = col.withOpacity(0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
        _text(canvas, p.label, ctr, cell * 0.5, col);
      }
    }

    if (sr != null && sc != null) {
      canvas.drawCircle(
          pos(sr!, sc!),
          cell * 0.47,
          Paint()
            ..color = Colors.teal
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5);
    }

    for (final m in hints) {
      final ctr = pos(m.tr, m.tc);
      if (game.b[m.tr][m.tc] != null) {
        canvas.drawCircle(
            ctr,
            cell * 0.47,
            Paint()
              ..color = Colors.redAccent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3);
      } else {
        canvas.drawCircle(
            ctr, cell * 0.12, Paint()..color = Colors.teal.withOpacity(0.8));
      }
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => true;
}
