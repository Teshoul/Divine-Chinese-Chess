import 'package:flutter/material.dart';
import 'engine.dart';
import 'board_draw.dart';
import 'match_info.dart';
import 'ui.dart';

class GamePage extends StatefulWidget {
  final bool free;
  final MatchInfo? match;
  const GamePage({super.key, required this.free, this.match});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
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

  MatchInfo? get m => widget.match;
  bool get online => m != null;
  Side? get mySide =>
      m == null ? null : (m!.first ? Side.red : Side.black);

  @override
  void initState() {
    super.initState();
    strict = !widget.free;
    autoMate = m?.params['mate'] != false;
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420))
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
        final mv = Move(msg['fr'] as int, msg['fc'] as int, msg['tr'] as int,
            msg['tc'] as int);
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
          m!.link.send({
            'type': 'move',
            'fr': mv.fr,
            'fc': mv.fc,
            'tr': mv.tr,
            'tc': mv.tc
          });
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
    final title = widget.free ? '自由模式' : '标准对局';

    return Scaffold(
      appBar: AppBar(title: Text(online ? '$title · 联机' : title)),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Row(
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (c, a) => FadeTransition(
                  opacity: a, child: ScaleTransition(scale: a, child: c)),
              child: Padding(
                key: ValueKey(msg),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(msg,
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: over != null ? cs.primary : cs.onSurface)),
              ),
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
                          painter: BoardPainter(
                              game, last, lastCap, sr, sc, hints, flip, _ac),
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
                  if (!online)
                    FilledButton.tonalIcon(
                        onPressed: game.history.isEmpty ? null : undo,
                        icon: const Icon(Icons.undo),
                        label: const Text('悔棋')),
                  FilledButton.tonalIcon(
                      onPressed: () => setState(() => flip = !flip),
                      icon: const Icon(Icons.flip),
                      label: const Text('翻转')),
                  if (!online || m!.isHost)
                    FilledButton.tonalIcon(
                        onPressed: () {
                          setState(_reset);
                          if (online) m!.link.send({'type': 'restart'});
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('重开')),
                  if (widget.free && !online)
                    FilterChip(
                      label: const Text('规则校验'),
                      selected: strict,
                      onSelected: (v) => setState(() {
                        strict = v;
                        clearSel();
                      }),
                    ),
                  if (!online && strict)
                    FilterChip(
                      label: const Text('自动判绝杀'),
                      selected: autoMate,
                      onSelected: (v) => setState(() => autoMate = v),
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

class BoardPainter extends CustomPainter {
  final Game game;
  final Move? last;
  final bool lastCap;
  final int? sr, sc;
  final List<Move> hints;
  final bool flip;
  final Animation<double> anim;

  BoardPainter(this.game, this.last, this.lastCap, this.sr, this.sc,
      this.hints, this.flip, this.anim)
      : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 9;
    Offset pos(int r, int c) {
      final rr = flip ? 9 - r : r;
      final cc = flip ? 8 - c : c;
      return Offset(cell * (cc + 0.5), cell * (rr + 0.5));
    }

    drawBoard(canvas, cell, 0);
    final f = anim.value;
    final t = Curves.easeOutCubic.transform(f);
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
        if (animating && lm!.tr == r && lm.tc == c) continue;
        drawPiece(canvas, pos(r, c), cell * 0.42, p.label,
            p.side == Side.red ? kRedC : kBlackC);
      }
    }

    if (animating) {
      final p = game.b[lm!.tr][lm.tc];
      if (p != null) {
        final ctr = Offset.lerp(pos(lm.fr, lm.fc), pos(lm.tr, lm.tc), t)!;
        drawPiece(canvas, ctr, cell * 0.42, p.label,
            p.side == Side.red ? kRedC : kBlackC);
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
