import 'package:flutter/material.dart';
import 'engine.dart';
import 'board_draw.dart';
import 'match_info.dart';
import 'settings.dart';
import 'ui.dart';

class GamePage extends StatefulWidget {
  final bool free;
  final MatchInfo? match;
  final bool mate;
  final bool strictInit;
  const GamePage({
    super.key,
    required this.free,
    this.match,
    this.mate = true,
    this.strictInit = false,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with TickerProviderStateMixin {
  final game = Game();
  int? sr, sc;
  List<Move> hints = [];
  Move? last;
  bool lastCap = false;
  bool flip = false;
  bool strict = true;
  bool autoMate = true;
  bool lost = false;
  String? over;
  late final AnimationController _ac;
  late final AnimationController _pulse;

  MatchInfo? get m => widget.match;
  bool get online => m != null;
  Side? get mySide => m == null ? null : (m!.first ? Side.red : Side.black);

  @override
  void initState() {
    super.initState();
    strict = widget.free ? widget.strictInit : true;
    autoMate = m != null ? m!.params['mate'] != false : widget.mate;
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))
      ..value = 1;
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
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

  void _reset() {
    game.reset();
    last = null;
    lastCap = false;
    over = null;
    clearSel();
    _ac.value = 1;
  }

  void _onNet(Map<String, dynamic> msg) {
    if (!mounted) return;
    final t = msg['type'];
    setState(() {
      if (t == 'move') {
        final mv = Move(msg['fr'] as int, msg['fc'] as int, msg['tr'] as int, msg['tc'] as int);
        final cap = game.b[mv.tr][mv.tc] != null;
        if (game.play(mv, strict: false)) {
          last = mv;
          lastCap = cap;
          clearSel();
          checkOver();
          _ac.forward(from: 0);
        }
      } else if (t == 'restart') {
        _reset();
      } else if (t == 'closed') {
        lost = true;
      }
    });
  }

  void select(int r, int c) {
    final p = game.b[r][c];
    setState(() {
      if (p == null ||
          (strict && p.side != game.turn) ||
          (online && p.side != mySide)) {
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
    if (!strict) return;
    if (autoMate && game.isCheckmated(game.turn)) {
      over = '${game.turn.cn}被绝杀，${game.turn.other.cn}获胜';
      return;
    }
    if (!game.hasLegalMove(game.turn)) {
      over = '${game.turn.cn}无路可走，${game.turn.other.cn}获胜';
    }
  }

  void onTap(int r, int c) {
    if (over != null || lost) return;
    if (online && game.turn != mySide) return;
    final p = game.b[r][c];
    if (sr != null) {
      final from = game.b[sr!][sc!];
      if (from != null && p != null && p.side == from.side) {
        select(r, c);
        return;
      }
      final mv = Move(sr!, sc!, r, c);
      final cap = p != null;
      if (game.play(mv, strict: strict)) {
        if (online) {
          m!.link.send({'type': 'move', 'fr': mv.fr, 'fc': mv.fc, 'tr': mv.tr, 'tc': mv.tc});
        }
        setState(() {
          last = mv;
          lastCap = cap;
          clearSel();
          checkOver();
        });
        _ac.forward(from: 0);
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
      lastCap = false;
      over = null;
      clearSel();
      _ac.value = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String msg;
    if (over != null) {
      msg = over!;
    } else if (lost) {
      msg = '对方已断开连接';
    } else if (online) {
      msg = game.turn == mySide ? '轮到你走棋' : '等待对方走棋…';
    } else {
      msg = '${game.turn.cn}走棋';
    }
    final title = widget.free ? '自由模式' : '普通对局';

    return Stack(
      fit: StackFit.expand,
      children: [
        const ImageSlot(slot: 'game'),
        Scaffold(
          appBar: AppBar(title: Text(online ? '$title · 联机' : title)),
          body: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      sideTag(context, Side.black,
                          active: over == null && game.turn == Side.black,
                          mine: online && mySide == Side.black),
                      const SizedBox(width: 12),
                      sideTag(context, Side.red,
                          active: over == null && game.turn == Side.red,
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
                          color: over != null ? cs.primary : cs.onSurface,
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
                            child: CustomPaint(
                              size: Size(cons.maxWidth, cons.maxHeight),
                              painter: BoardPainter(game, last, lastCap, sr, sc, hints, flip,
                                  _ac, _pulse),
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
                          label: '悔棋',
                          onTap: game.history.isEmpty ? null : undo),
                    LitButton(
                        icon: Icons.flip,
                        label: '翻转',
                        onTap: () => setState(() => flip = !flip)),
                    if (!online || m!.isHost)
                      LitButton(
                        icon: Icons.refresh,
                        label: '重开',
                        onTap: () {
                          setState(_reset);
                          if (online) m!.link.send({'type': 'restart'});
                        },
                      ),
                    if (widget.free && !online)
                      LitToggle(
                        icon: Icons.rule,
                        label: '规则校验',
                        value: strict,
                        onChanged: (v) => setState(() {
                          strict = v;
                          clearSel();
                        }),
                      ),
                    if (!online && strict)
                      LitToggle(
                        icon: Icons.flag,
                        label: '自动判绝杀',
                        value: autoMate,
                        onChanged: (v) => setState(() => autoMate = v),
                      ),
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

class BoardPainter extends CustomPainter {
  final Game game;
  final Move? last;
  final bool lastCap;
  final int? sr, sc;
  final List<Move> hints;
  final bool flip;
  final Animation<double> anim;
  final Animation<double> pulse;

  BoardPainter(this.game, this.last, this.lastCap, this.sr, this.sc, this.hints, this.flip,
      this.anim, this.pulse)
      : super(repaint: Listenable.merge([anim, pulse]));

  List<Piece> _dead(Side s) => [
        for (final h in game.history)
          if (h.captured != null && h.captured!.side == s) h.captured!
      ];

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
    for (final s in Side.values) {
      final list = _dead(s);
      var fresh = -1;
      if (game.history.isNotEmpty) {
        final cp = game.history.last.captured;
        if (cp != null && cp.side == s) fresh = list.length - 1;
      }
      drawTray(canvas, cell, s == Side.red ? redY : blackY, s, list,
          fresh: fresh, t: t, pulse: pulse.value);
    }

    final lm = last;
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
        final p = game.b[r][c];
        if (p == null) continue;
        if (animating && lm.tr == r && lm.tc == c) continue;
        drawPiece(canvas, pos(r, c), cell * 0.42, p.label,
            p.side == Side.red ? app.red : app.black);
      }
    }

    if (animating) {
      final p = game.b[lm.tr][lm.tc];
      if (p != null) {
        final ctr = Offset.lerp(pos(lm.fr, lm.fc), pos(lm.tr, lm.tc), t)!;
        drawPiece(canvas, ctr, cell * 0.42, p.label, p.side == Side.red ? app.red : app.black);
      }
      if (lastCap) {
        canvas.drawCircle(
            pos(lm.tr, lm.tc),
            cell * (0.3 + 0.7 * f),
            Paint()
              ..color = Colors.orangeAccent.withOpacity(1 - f)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4);
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
      if (game.b[mv.tr][mv.tc] != null) {
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
  bool shouldRepaint(covariant BoardPainter oldDelegate) => true;
}
