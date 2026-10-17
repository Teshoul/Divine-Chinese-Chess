import 'package:flutter/material.dart';
import 'engine.dart';
import 'blind.dart';
import 'board_draw.dart';

class BlindSetupPage extends StatefulWidget {
  final String buttonText;
  final BlindConfig? initial;
  final void Function(BuildContext, BlindConfig) onConfirm;
  const BlindSetupPage(
      {super.key,
      required this.buttonText,
      required this.onConfirm,
      this.initial});

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

  Widget typeRow(Side s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
              width: 48,
              child: Text(s.cn,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: s == Side.red ? kRedC : null))),
          Expanded(
            child: Wrap(
              spacing: 6,
              children: [
                for (final t in _types)
                  FilterChip(
                    label: Text(Piece(t, s).label),
                    selected: typeAllUp(t, s),
                    onSelected: (_) => toggleType(t, s),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
    return Scaffold(
      appBar: AppBar(title: const Text('盲棋设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('快速预设', style: head),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                  label: const Text('仅将帅明（默认）'),
                  onPressed: () => applyRule((t, s) => t == PType.king)),
              ActionChip(
                  label: const Text('将帅+仕士明'),
                  onPressed: () => applyRule(
                      (t, s) => t == PType.king || t == PType.advisor)),
              ActionChip(
                  label: const Text('全明'),
                  onPressed: () => applyRule((t, s) => true)),
              ActionChip(
                  label: const Text('全暗'),
                  onPressed: () => applyRule((t, s) => false)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('按棋子类型（高亮 = 开局明牌）', style: head),
          const SizedBox(height: 8),
          typeRow(Side.red),
          typeRow(Side.black),
          const SizedBox(height: 12),
          const Text('点棋盘上的棋子可单独设置（浅色=明，棕色=暗）', style: head),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (ctx, cons) {
            final cell = cons.maxWidth / 9;
            return GestureDetector(
              onTapUp: (d) {
                final c = (d.localPosition.dx / cell).floor();
                final r = (d.localPosition.dy / cell).floor();
                if (c >= 0 && c <= 8 && r >= 0 && r <= 9 &&
                    layout[r][c] != null) {
                  setState(() => up[r][c] = !up[r][c]);
                }
              },
              child: CustomPaint(
                size: Size(cons.maxWidth, cell * 10),
                painter: SetupPainter(layout, up),
              ),
            );
          }),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('将/帅限制在九宫内'),
            value: kp,
            onChanged: (v) => setState(() => kp = v),
          ),
          SwitchListTile(
            title: const Text('仕/相翻开后受限制'),
            subtitle: const Text('关闭时翻出的仕、相可在全盘走动，不会被卡死'),
            value: ae,
            onChanged: (v) => setState(() => ae = v),
          ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                  '规则：暗子第一步按它所在位置的原棋子走法移动，走完翻开随机身份与阵营；'
                  '暗子可被任何棋子直接吃掉，被吃后亮出身份并按颜色放到棋盘外对应一侧；'
                  '吃掉将/帅获胜。'),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => widget.onConfirm(
                context,
                BlindConfig(
                    up: [for (final row in up) List<bool>.from(row)],
                    kingInPalace: kp,
                    advElephantLimit: ae)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(widget.buttonText,
                  style: const TextStyle(fontSize: 17)),
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
          drawPiece(canvas, ctr, cell * 0.42, p.label,
              p.side == Side.red ? kRedC : kBlackC);
        } else {
          drawHidden(canvas, ctr, cell * 0.42, hint: p.label);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant SetupPainter oldDelegate) => true;
}
