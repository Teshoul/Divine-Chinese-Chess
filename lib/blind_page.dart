import 'dart:math';
import 'package:flutter/material.dart';
import 'engine.dart';
import 'blind.dart';
import 'board_draw.dart';
import 'net.dart';

class BlindPage extends StatefulWidget {
  final BlindConfig cfg;
  final int seed;
  final String title;
  final NetLink? link;
  final Side? mySide;
  final bool isHost;
  const BlindPage(
      {super.key,
      required this.cfg,
      required this.seed,
      this.title = '盲棋',
      this.link,
      this.mySide,
      this.isHost = false});

  @override
  State<BlindPage> createState() => _BlindPageState();
}

class _BlindPageState extends State<BlindPage> {
  late BlindGame game;
  late BlindConfig cfg;
  int? sr, sc;
  List<Move> hints = [];
  bool flip = false;
  bool lost = false;

  bool get online => widget.link != null;

  @override
  void initState() {
    super.initState();
    cfg = widget.cfg;
    game = BlindGame(cfg, widget.seed);
    flip = online && widget.mySide == Side.black;
    if (online) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.link!.handler = _onNet;
      });
    }
  }

  @override
  void dispose() {
    widget.link?.handler = null;
    widget.link?.close();
    super.dispose();
  }

  void clearSel() {
    sr = null;
    sc = null;
    hints = [];
  }

  void _onNet(Map<String, dynamic> m) {
    if (!mounted) return;
    final t = m['type'];
    setState(() {
      if (t == 'move') {
        game.play(Move(m['fr'] as int, m['fc'] as int, m['tr'] as int,
            m['tc'] as int));
        clearSel();
      } else if (t == 'start') {
        cfg = BlindConfig.fromJson(Map<String, dynamic>.from(m['cfg'] as Map));
        game = BlindGame(cfg, m['seed'] as int);
        clearSel();
      } else if (t == 'closed') {
        lost = true;
      }
    });
  }

  void onTap(int r, int c) {
    if (game.winner != null) return;
    if (online && (lost || game.turn != widget.mySide)) return;
    final p = game.b[r][c];
    if (sr != null && hints.any((x) => x.tr == r && x.tc == c)) {
      final m = Move(sr!, sc!, r, c);
      if (game.play(m)) {
        widget.link?.send(
            {'type': 'move', 'fr': m.fr, 'fc': m.fc, 'tr': m.tr, 'tc': m.tc});
        setState(clearSel);
        return;
      }
    }
    if (p != null && p.owner == game.turn) {
      setState(() {
        sr = r;
        sc = c;
        hints = game.movesFor(r, c);
      });
    } else {
      setState(clearSel);
    }
  }

  void restart() {
    final seed = Random().nextInt(1 << 30);
    setState(() {
      game = BlindGame(cfg, seed);
      clearSel();
    });
    widget.link?.send({'type': 'start', 'cfg': cfg.toJson(), 'seed': seed});
  }

  String get status {
    if (game.winner != null) return '${game.winner!.cn}获胜';
    if (online) {
      if (lost) return '对方已断开连接';
      final mine = game.turn == widget.mySide;
      return '${game.turn.cn}走棋（${mine ? '轮到你' : '等待对方…'}）';
    }
    return '${game.turn.cn}走棋';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(online
              ? '${widget.title} · 你是${widget.mySide!.cn}'
              : widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(status,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AspectRatio(
                    aspectRatio: 9 / 12,
                    child: LayoutBuilder(builder: (ctx, cons) {
                      final cell = cons.maxWidth / 9;
                      return GestureDetector(
                        onTapUp: (d) {
                          var c = (d.localPosition.dx / cell).floor();
                          var r = ((d.localPosition.dy - cell) / cell).floor();
                          if (c < 0 || c > 8 || r < 0 || r > 9) return;
                          if (flip) {
                            c = 8 - c;
                            r = 9 - r;
                          }
                          onTap(r, c);
                        },
                        child: CustomPaint(
                          size: Size(cons.maxWidth, cons.maxHeight),
                          painter: BlindPainter(game, sr, sc, hints, flip),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (!online)
                    FilledButton.tonalIcon(
                        onPressed: game.canUndo
                            ? () => setState(() {
                                  game.undo();
                                  clearSel();
                                })
                            : null,
                        icon: const Icon(Icons.undo),
                        label: const Text('悔棋')),
                  FilledButton.tonalIcon(
                      onPressed: () => setState(() => flip = !flip),
                      icon: const Icon(Icons.flip),
                      label: const Text('翻转')),
                  if (!online || widget.isHost)
                    FilledButton.tonalIcon(
                        onPressed: restart,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重开')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BlindPainter extends CustomPainter {
  final BlindGame g;
  final int? sr, sc;
  final List<Move> hints;
  final bool flip;
  BlindPainter(this.g, this.sr, this.sc, this.hints, this.flip);

  void _strip(Canvas canvas, double cell, double y, Side side,
      List<BPiece> dead) {
    final col = side == Side.red ? kRedC : kBlackC;
    final rr = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, y + cell * 0.08, cell * 9, cell * 0.84),
        Radius.circular(cell * 0.25));
    canvas.drawRRect(rr, Paint()..color = col.withOpacity(0.10));
    canvas.drawRRect(
        rr,
        Paint()
          ..color = col.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    drawText(canvas, '${side == Side.red ? '红' : '黑'}方\n阵亡',
        Offset(cell * 0.75, y + cell * 0.5), cell * 0.26, col.withOpacity(0.75));
    for (var i = 0; i < dead.length; i++) {
      final ctr = Offset(cell * 1.55 + i * cell * 0.46, y + cell * 0.5);
      drawPiece(canvas, ctr, cell * 0.21, dead[i].label,
          dead[i].side == Side.red ? kRedC : kBlackC);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 9;
    final top = cell;
    Offset pos(int r, int c) {
      final rr = flip ? 9 - r : r;
      final cc = flip ? 8 - c : c;
      return Offset(cell * (cc + 0.5), top + cell * (rr + 0.5));
    }

    drawBoard(canvas, cell, top);
    final redY = flip ? 0.0 : top + cell * 10;
    final blackY = flip ? top + cell * 10 : 0.0;
    _strip(canvas, cell, redY, Side.red, g.deadRed);
    _strip(canvas, cell, blackY, Side.black, g.deadBlack);

    final lm = g.last;
    if (lm != null) {
      final hl = Paint()
        ..color = const Color(0xFF1E88E5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(pos(lm.fr, lm.fc), cell * 0.46, hl);
      canvas.drawCircle(pos(lm.tr, lm.tc), cell * 0.46, hl);
    }

    for (var r = 0; r < 10; r++) {
      for (var c = 0; c < 9; c++) {
        final p = g.b[r][c];
        if (p == null) continue;
        final ctr = pos(r, c);
        final rad = cell * 0.42;
        if (p.up) {
          drawPiece(canvas, ctr, rad, p.label,
              p.side == Side.red ? kRedC : kBlackC);
        } else {
          drawHidden(canvas, ctr, rad);
        }
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
      if (g.b[m.tr][m.tc] != null) {
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
  bool shouldRepaint(covariant BlindPainter oldDelegate) => true;
}
