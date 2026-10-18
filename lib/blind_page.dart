import 'dart:math';
import 'package:flutter/material.dart';
import 'engine.dart';
import 'blind.dart';
import 'board_draw.dart';
import 'match_info.dart';
import 'settings.dart';
import 'strings.dart';
import 'ui.dart';
import 'peer.dart';

class BlindPage extends StatefulWidget {
  final BlindConfig cfg;
  final int seed;
  final String title;
  final MatchInfo? match;
  const BlindPage({
    super.key,
    required this.cfg,
    required this.seed,
    this.title = '盲棋',
    this.match,
  });

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
  bool _recorded = false;

  void _syncRecord() {
    if (!online) return;
    final w = game.winner;
    if (w == null) {
      _recorded = false;
    } else if (!_recorded) {
      _recorded = true;
      app.recordResult(w == mySide);
    }
  }
  bool lastCap = false;
  bool lastReveal = false;
  BPiece? lastDead;
  late final AnimationController _ac;
  late final AnimationController _pulse;

  MatchInfo? get m => widget.match;
  bool get online => m != null;
  Side? get mySide => m == null ? null : (m!.first ? Side.red : Side.black);
  String _name(Side s) => tr(s == Side.red ? '红方' : '黑方');

  @override
  void initState() {
    super.initState();
    cfg = widget.cfg;
    game = BlindGame(cfg, widget.seed);
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))
      ..value = 1;
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..value = 1;
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
    _pulse.value = 1;
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
    if (t != null) _pulse.forward(from: 0);
    return true;
  }

  void _onNet(Map<String, dynamic> msg) {
    if (!mounted) return;
    final t = msg['type'];
    setState(() {
      if (t == 'move') {
        _apply(Move(msg['fr'] as int, msg['fc'] as int, msg['tr'] as int, msg['tc'] as int));
        clearSel();
      } else if (t == 'start') {
        cfg = BlindConfig.fromJson(Map<String, dynamic>.from(msg['cfg'] as Map));
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
            m!.link.send({'type': 'move', 'fr': mv.fr, 'fc': mv.fc, 'tr': mv.tr, 'tc': mv.tc});
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
    if (game.winner != null) return trf('{s}获胜', {'s': _name(game.winner!)});
    if (lost) return tr('对方已断开连接');
    if (online) return tr(game.turn == mySide ? '轮到你走棋' : '等待对方走棋…');
    return trf('{s}走棋', {'s': _name(game.turn)});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    _syncRecord();
    final msg = status;
    final base = tr(widget.title);
    return Stack(
      fit: StackFit.expand,
      children: [
        const ImageSlot(slot: 'game'),
        if (online) ...onlineBadges(context, m!.link),
        Scaffold(
          appBar: AppBar(title: Text(online ? '$base · ${tr('联机')}' : base)),
          body: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
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
                ),
                SizedBox(
                  height: 40,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (c, a) =>
                          FadeTransition(opacity: a, child: ScaleTransition(scale: a, child: c)),
                      child: Text(
                        msg,
                        key: ValueKey(msg),
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: game.winner != null ? cs.primary : cs.onSurface,
                        ),
                      ),
                    ),
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
                            child: RepaintBoundary(
                              child: CustomPaint(
                                size: Size(cons.maxWidth, cons.maxHeight),
                                painter: BlindPainter(game, sr, sc, hints, flip, lastCap,
                                    lastReveal, lastDead, _ac, _pulse),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
                ActionBar(
                  children: [
                    if (!online)
                      LitButton(
                        icon: Icons.undo,
                        label: tr('悔棋'),
                        onTap: game.canUndo
                            ? () => setState(() {
                                  game.undo();
                                  clearSel();
                                  _resetFlags();
                                })
                            : null,
                      ),
                    LitButton(
                        icon: Icons.flip,
                        label: tr('翻转'),
                        onTap: () => setState(() => flip = !flip)),
                    if (!online || m!.isHost)
                      LitButton(icon: Icons.refresh, label: tr('重开'), onTap: restart),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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

  BlindPainter(this.g, this.sr, this.sc, this.hints, this.flip, this.lastCap, this.lastReveal,
      this.lastDead, this.anim, this.pulse)
      : super(repaint: Listenable.merge([anim, pulse]));

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
    final pv = 0.5 + 0.5 * sin(pulse.value * pi * 6);

    drawBoard(canvas, cell, top);
    final redY = flip ? 0.0 : top + cell * 10;
    final blackY = flip ? top + cell * 10 : 0.0;
    final redDead = [for (final b in g.deadRed) Piece(b.type, b.side)];
    final blackDead = [for (final b in g.deadBlack) Piece(b.type, b.side)];
    drawTray(canvas, cell, redY, Side.red, redDead,
        fresh: g.deadRed.indexWhere((x) => identical(x, lastDead)), t: t, pulse: pv);
    drawTray(canvas, cell, blackY, Side.black, blackDead,
        fresh: g.deadBlack.indexWhere((x) => identical(x, lastDead)), t: t, pulse: pv);

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
        if (animating && lm.tr == r && lm.tc == c) continue;
        final ctr = pos(r, c);
        final rad = cell * 0.42;
        if (p.up) {
          drawPiece(canvas, ctr, rad, p.label, p.side == Side.red ? app.red : app.black);
        } else {
          drawHidden(canvas, ctr, rad);
        }
      }
    }

    if (animating) {
      final p = g.b[lm.tr][lm.tc];
      if (p != null) {
        final ctr = Offset.lerp(pos(lm.fr, lm.fc), pos(lm.tr, lm.tc), t)!;
        final rad = cell * 0.42;
        final col = p.side == Side.red ? app.red : app.black;
        if (lastReveal) {
          drawFlip(canvas, ctr, rad, Curves.easeInOut.transform(f), p.label, col);
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
        final dc = dead.side == Side.red ? app.red : app.black;
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
    for (final mv in hints) {
      final ctr = pos(mv.tr, mv.tc);
      if (g.b[mv.tr][mv.tc] != null) {
        canvas.drawCircle(
            ctr,
            cell * 0.47,
            Paint()
              ..color = Colors.redAccent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3);
      } else {
        canvas.drawCircle(ctr, cell * 0.12, Paint()..color = Colors.teal.withOpacity(0.8));
      }
    }
  }

  @override
  bool shouldRepaint(covariant BlindPainter oldDelegate) => true;
}
