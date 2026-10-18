import 'dart:math';
import 'package:flutter/material.dart';
import 'engine.dart';
import 'blind.dart';
import 'board_draw.dart';
import 'match_info.dart';
import 'ui.dart';

const Color kGold = Color(0xFFFFB300);

class BlindPage extends StatefulWidget {
  final BlindConfig cfg;
  final int seed;
  final String title;
  final MatchInfo? match;
  const BlindPage(
      {super.key,
      required this.cfg,
      required this.seed,
      this.title = '盲棋',
      this.match});

  @override
  State<BlindPage> createState() => _BlindPageState();
}

class _BlindPageState extends State<BlindPage> with TickerProviderStateMixin {
  late BlindGame game;
  late BlindConfig cfg;
  int? sr, sc;
  List<Move> hints = [];
  bool flip = false;
  bool lost = false;
  bool lastCap = false;
  bool lastReveal = false;
  BPiece? lastDead;
  late final AnimationController _ac;
  late final AnimationController _pulse;

  MatchInfo? get m => widget.match;
  bool get online => m != null;
  Side? get mySide =>
      m == null ? null : (m!.first ? Side.red : Side.black);

  @override
  void initState() {
    super.initState();
    cfg = widget.cfg;
    game = BlindGame(cfg, widget.seed);
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..value = 1;
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    if (online) {
      flip = mySide == Side.black;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) m!.link.handler = _onNet;
      });
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    _pulse.dispose();
    if (online) {
      m!.link.handler = null;
      m!.link.close();
    }
    super.dispose();
  }

  void clearSel() {
    sr = null;
    sc = null;
    hints = [];
  }

  void _resetFlags() {
    lastCap = false;
    lastReveal = false;
    lastDead = null;
    _ac.value = 1;
  }

  bool _apply(Move mv) {
    final p = game.b[mv.fr][mv.fc];
    final t = game.b[mv.tr][mv.tc];
    final wasHidden = p != null && !p.up;
    if (!game.play(mv)) return false;
    lastCap = t != null;
    lastReveal = wasHidden;
    lastDead = t;
    _ac.forward(from: 0);
    return true;
  }

  void _onNet(Map<String, dynamic> msg) {
    if (!mounted) return;
    final t = msg['type'];
    setState(() {
      if (t == 'move') {
        _apply(Move(msg['fr'] as int, msg['fc'] as int, msg['tr'] as int,
            msg['tc'] as int));
        clearSel();
      } else if (t == 'start') {
        cfg = BlindConfig.fromJson(
            Map<String, dynamic>.from(msg['cfg'] as Map));
        game = BlindGame(cfg, msg['seed'] as int);
        clearSel();
        _resetFlags();
      } else if (t == 'closed') {
        lost = true;
      }
    });
  }

  void onTap(int r, int c) {
    if (game.winner != null || lost) return;
    if (online && game.turn != mySide) return;
    final p = game.b[r][c];
    if (sr != null && hints.any((x) => x.tr == r && x.tc == c)) {
      final mv = Move(sr!, sc!, r, c);
      setState(() {
        if (_apply(mv)) {
          if (online) {
            m!.link.send({
              'type': 'move',
              'fr': mv.fr,
              'fc': mv.fc,
              'tr': mv.tr,
              'tc': mv.tc
            });
          }
          clearSel();
        }
      });
      return;
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
      _resetFlags();
    });
    if (online) {
      m!.link.send({'type': 'start', 'cfg': cfg.toJson(), 'seed': seed});
    }
  }

  String get status {
    if (game.winner != null) return '${game.winner!.cn}获胜';
    if (lost) return '对方已断开连接';
    if (online) return game.turn == mySide ? '轮到你走棋' : '等待对方走棋…';
    return '${game.turn.cn}走棋';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final msg = status;
    return Scaffold(
      appBar: AppBar(
          title: Text(online ? '${widget.title} · 联机' : widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                sideTag(context, Side.black,
                    active: game.winner == null && game.turn == Side.black,
                    mine: online && mySide == Side.black),
                const SizedBox(width: 12),
                sideTag(context, Side.red,
                    active: game.winner == null && game.turn == Side.red,
                    mine: online && mySide == Side.red),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (c, a) => FadeTransition(
                  opacity: a, child: ScaleTransition(scale: a, child: c)),
              child: Padding(
                key: ValueKey(msg),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(msg,
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: game.winner != null
                            ? cs.primary
                            : cs.onSurface)),
              ),
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
                          painter: BlindPainter(game, sr, sc, hints, flip,
                              lastCap, lastReveal, lastDead, _ac, _pulse),
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
                                  _resetFlags();
                                })
                            : null,
                        icon: const Icon(Icons.undo),
                        label: const Text('悔棋')),
                  FilledButton.tonalIcon(
                      onPressed: () => setState(() => flip = !flip),
                      icon: const Icon(Icons.flip),
                      label: const Text('翻转')),
                  if (!online || m!.isHost)
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
  final bool lastCap;
  final bool lastReveal;
  final BPiece? lastDead;
  final Animation<double> anim;
  final Animation<double> pulse;

  BlindPainter(this.g, this.sr, this.sc, this.hints, this.flip, this.lastCap,
      this.lastReveal, this.lastDead, this.anim, this.pulse)
      : super(repaint: Listenable.merge([anim, pulse]));

  void _strip(Canvas canvas, double cell, double y, Side side,
      List<BPiece> dead, double t) {
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
      final pc = dead[i].side == Side.red ? kRedC : kBlackC;
      final isNew = identical(dead[i], lastDead);
      final scale = isNew ? 1 + 0.9 * (1 - t) : 1.0;
      drawPiece(canvas, ctr, cell * 0.21 * scale, dead[i].label, pc);
      if (isNew) {
        canvas.drawCircle(
            ctr,
            cell * (0.28 + 0.03 * pulse.value),
            Paint()
              ..color = kGold.withOpacity(0.55 + 0.45 * pulse.value)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.6);
      }
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

    final f = anim.value;
    final t = Curves.easeOutCubic.transform(f);

    drawBoard(canvas, cell, top);
    final redY = flip ? 0.0 : top + cell * 10;
    final blackY = flip ? top + cell * 10 : 0.0;
    _strip(canvas, cell, redY, Side.red, g.deadRed, t);
    _strip(canvas, cell, blackY, Side.black, g.deadBlack, t);

    final lm = g.last;
    final animating = lm != null && f < 1;

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
        if (animating && lm!.tr == r && lm.tc == c) continue;
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

    if (animating) {
      final p = g.b[lm!.tr][lm.tc];
      if (p != null) {
        final ctr = Offset.lerp(pos(lm.fr, lm.fc), pos(lm.tr, lm.tc), t)!;
        final rad = cell * 0.42;
        final col = p.side == Side.red ? kRedC : kBlackC;
        if (lastReveal) {
          final sx = max(0.05, (2 * f - 1).abs());
          canvas.save();
          canvas.translate(ctr.dx, ctr.dy);
          canvas.scale(sx, 1);
          canvas.translate(-ctr.dx, -ctr.dy);
          if (f < 0.5) {
            drawHidden(canvas, ctr, rad);
          } else {
            drawPiece(canvas, ctr, rad, p.label, col);
          }
          canvas.restore();
          canvas.drawCircle(
              ctr,
              rad * (1.0 + 0.6 * f),
              Paint()
                ..color = kGold.withOpacity(1 - f)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.5);
        } else {
          drawPiece(canvas, ctr, rad, p.label, col);
        }
      }
      final dead = lastDead;
      if (lastCap && dead != null) {
        final dc = dead.side == Side.red ? kRedC : kBlackC;
        canvas.drawCircle(
            pos(lm.tr, lm.tc),
            cell * (0.3 + 0.8 * f),
            Paint()
              ..color = dc.withOpacity((1 - f) * 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4);
        canvas.drawCircle(
            pos(lm.tr, lm.tc),
            cell * (0.2 + 0.6 * f),
            Paint()
              ..color = kGold.withOpacity((1 - f) * 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3);
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
