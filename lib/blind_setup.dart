import 'package:flutter/material.dart';
import 'engine.dart';
import 'blind.dart';
import 'board_draw.dart';
import 'settings.dart';
import 'strings.dart';
import 'ui.dart';

class BlindSetupPage extends StatefulWidget {
  final String buttonText;
  final BlindConfig? initial;
  final void Function(BuildContext, BlindConfig) onConfirm;
  const BlindSetupPage(
      {super.key, required this.buttonText, required this.onConfirm, this.initial});

  @override
  State<BlindSetupPage> createState() => _BlindSetupPageState();
}

class _BlindSetupPageState extends State<BlindSetupPage> {
  final layout = Game().b;
  late List<List<bool>> up;
  late bool kp;
  late bool ae;

  static const _types = [
    PType.king,
    PType.advisor,
    PType.elephant,
    PType.horse,
    PType.rook,
    PType.cannon,
    PType.pawn
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.initial ?? BlindConfig.kingsOnly();
    up = [for (final row in c.up) List<bool>.from(row)];
    kp = c.kingInPalace;
    ae = c.advElephantLimit;
  }

  void applyRule(bool Function(PType, Side) f) {
    setState(() {
      for (var r = 0; r < 10; r++) {
        for (var c = 0; c < 9; c++) {
          final p = layout[r][c];
          if (p != null) up[r][c] = f(p.type, p.side);
        }
      }
    });
  }

  bool typeAllUp(PType t, Side s) {
    var any = false;
    for (var r = 0; r < 10; r++) {
      for (var c = 0; c < 9; c++) {
        final p = layout[r][c];
        if (p != null && p.type == t && p.side == s) {
          any = true;
          if (!up[r][c]) return false;
        }
      }
    }
    return any;
  }

  void toggleType(PType t, Side s) {
    final target = !typeAllUp(t, s);
    setState(() {
      for (var r = 0; r < 10; r++) {
        for (var c = 0; c < 9; c++) {
          final p = layout[r][c];
          if (p != null && p.type == t && p.side == s) up[r][c] = target;
        }
      }
    });
  }

  Widget _card(String title, Widget child) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: styled(cs.surfaceContainerHigh, r: app.cardR),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(title), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _pill(String zh, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return PressBox(
      color: cs.secondaryContainer,
      r: app.btnR,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      onTap: onTap,
      child: Text(tr(zh),
          style: TextStyle(
              color: cs.onSecondaryContainer, fontWeight: FontWeight.w600)),
    );
  }

  Widget typeRow(Side s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(s == Side.red ? '红方' : '黑方'),
              style: TextStyle(fontWeight: FontWeight.w700, color: s == Side.red ? kRedC : null)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _types)
                LitToggle(
                  wide: true,
                  label: Piece(t, s).label,
                  value: typeAllUp(t, s),
                  onChanged: (_) => toggleType(t, s),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('盲棋设置'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _card(
            '快速预设',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill('仅将帅明（默认）', () => applyRule((t, s) => t == PType.king)),
                _pill('将帅+仕士明',
                    () => applyRule((t, s) => t == PType.king || t == PType.advisor)),
                _pill('全明', () => applyRule((t, s) => true)),
                _pill('全暗', () => applyRule((t, s) => false)),
              ],
            ),
          ),
          _card(
            '按棋子类型（高亮 = 开局明牌）',
            Column(children: [typeRow(Side.red), typeRow(Side.black)]),
          ),
          _card(
            '点棋盘上的棋子可单独设置（浅色=明，棕色=暗）',
            LayoutBuilder(builder: (ctx, cons) {
              final cell = cons.maxWidth / 9;
              return GestureDetector(
                onTapUp: (d) {
                  final c = (d.localPosition.dx / cell).floor();
                  final r = (d.localPosition.dy / cell).floor();
                  if (c >= 0 && c <= 8 && r >= 0 && r <= 9 && layout[r][c] != null) {
                    setState(() => up[r][c] = !up[r][c]);
                  }
                },
                child: CustomPaint(
                  size: Size(cons.maxWidth, cell * 10),
                  painter: SetupPainter(layout, up),
                ),
              );
            }),
          ),
          _card(
            '盲棋设置',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    LitToggle(
                      wide: true,
                      icon: Icons.fort,
                      label: tr('将/帅限制在九宫内'),
                      value: kp,
                      onChanged: (v) => setState(() => kp = v),
                    ),
                    LitToggle(
                      wide: true,
                      icon: Icons.shield,
                      label: tr('仕/相翻开后受限制'),
                      value: ae,
                      onChanged: (v) => setState(() => ae = v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(tr('关闭时翻出的仕、相可在全盘走动，不会被卡死'),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 12),
                Text(
                  tr('规则：暗子第一步按它所在位置的原棋子走法移动，走完翻开随机身份与阵营；暗子可被任何棋子直接吃掉，被吃后亮出身份并按颜色放到棋盘外对应一侧；吃掉将/帅获胜。'),
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: () => widget.onConfirm(
              context,
              BlindConfig(
                up: [for (final row in up) List<bool>.from(row)],
                kingInPalace: kp,
                advElephantLimit: ae,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(widget.buttonText, style: const TextStyle(fontSize: 17)),
            ),
          ),
        ],
      ),
    );
  }
}

class SetupPainter extends CustomPainter {
  final List<List<Piece?>> layout;
  final List<List<bool>> up;
  SetupPainter(this.layout, this.up);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 9;
    drawBoard(canvas, cell, 0);
    for (var r = 0; r < 10; r++) {
      for (var c = 0; c < 9; c++) {
        final p = layout[r][c];
        if (p == null) continue;
        final ctr = Offset(cell * (c + 0.5), cell * (r + 0.5));
        if (up[r][c]) {
          drawPiece(canvas, ctr, cell * 0.42, p.label, p.side == Side.red ? kRedC : kBlackC);
        } else {
          drawHidden(canvas, ctr, cell * 0.42, hint: p.label);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant SetupPainter oldDelegate) => true;
}
