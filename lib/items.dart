import 'dart:math';
import 'package:flutter/material.dart';
import 'glitch.dart';
import 'liquid.dart';

enum ItemKind { badge, corner, avatar }

class Item {
  final String id;
  final ItemKind kind;
  final String name;
  final String desc;
  const Item(this.id, this.kind, this.name, this.desc);
}

/// 道具表：以后加新道具，在这里加一条即可（开发者模式会自动获得）
const List<Item> kItems = [
  Item('badge_divine', ItemKind.badge, '「神」徽标', '解锁隐藏主题「神」时获得'),
  Item('corner_star', ItemKind.corner, '故障星角标（动态）', '解锁隐藏主题「神」时获得'),
  Item('avatar_star', ItemKind.avatar, '故障星头像（动态）', '解锁隐藏主题「神」时获得'),
  Item('badge_ts', ItemKind.badge, 'Teshoul 徽标', '开发者专属'),
  Item('badge_dev', ItemKind.badge, '「开发者」徽标', '开发者专属'),
  Item('badge_admin', ItemKind.badge, '「管理员」徽标', '开发者专属'),
  Item('corner_zuo', ItemKind.corner, '「作」字角标', '开发者专属'),
  Item('corner_ts', ItemKind.corner, '「TS」角标（动态）', '开发者专属'),
  Item('corner_guan', ItemKind.corner, '「管」字角标', '开发者专属'),
];

Item? itemById(String id) {
  for (final i in kItems) {
    if (i.id == id) return i;
  }
  return null;
}

class BadgeView extends StatelessWidget {
  final String id;
  final double h;
  const BadgeView({super.key, required this.id, this.h = 16});

  Widget _rect(String text, List<Color> colors, Color border) {
    return Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: h * 0.42),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(h * 0.22),
        gradient: LinearGradient(colors: colors),
        border: Border.all(color: border, width: max(1.0, h * 0.07)),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          fontSize: h * 0.58,
          height: 1.0,
          color: Colors.white,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (id) {
      case 'badge_divine':
        return DivineMark(size: h);
      case 'badge_ts':
        return _rect('Teshoul', const [Color(0xFF311B92), Color(0xFF7B1FA2)],
            const Color(0xFFFFD54F));
      case 'badge_dev':
        return _rect('开发者', const [Color(0xFF004D40), Color(0xFF00ACC1)],
            const Color(0xFF80DEEA));
      case 'badge_admin':
        return _rect('管理员', const [Color(0xFFB71C1C), Color(0xFFE53935)],
            const Color(0xFFFFD54F));
      default:
        return const SizedBox.shrink();
    }
  }
}

/// 名字后面的徽标，可叠加，后戴的排在后面
class BadgesRow extends StatelessWidget {
  final List<String> ids;
  final double h;
  const BadgesRow({super.key, required this.ids, this.h = 16});

  @override
  Widget build(BuildContext context) {
    if (ids.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final id in ids)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: BadgeView(id: id, h: h),
          ),
      ],
    );
  }
}

class CornerView extends StatelessWidget {
  final String id;
  final double size;
  const CornerView({super.key, required this.id, this.size = 20});

  Widget _round(String t, List<Color> colors, Color ink) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: max(1.0, size * 0.07)),
      ),
      child: Text(
        t,
        style: TextStyle(
          fontSize: size * 0.56,
          height: 1.0,
          color: ink,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (id) {
      case 'corner_star':
        return StarBadge(size: size);
      case 'corner_zuo':
        return _round('作', const [Color(0xFFFFE082), Color(0xFFFFA000)], const Color(0xFF3E2723));
      case 'corner_guan':
        return _round('管', const [Color(0xFFEF5350), Color(0xFFB71C1C)], Colors.white);
      case 'corner_ts':
        return TsCorner(size: size);
      default:
        return const SizedBox.shrink();
    }
  }
}

/// “TS”动态角标
class TsCorner extends StatefulWidget {
  final double size;
  const TsCorner({super.key, required this.size});
  @override
  State<TsCorner> createState() => _TsCornerState();
}

class _TsCornerState extends State<TsCorner> {
  @override
  void initState() {
    super.initState();
    LiquidClock.I.attach();
  }

  @override
  void dispose() {
    LiquidClock.I.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(size: Size.square(widget.size), painter: _TsPainter()),
    );
  }
}

class _TsPainter extends CustomPainter {
  _TsPainter() : super(repaint: LiquidClock.I);

  @override
  void paint(Canvas canvas, Size s) {
    final t = LiquidClock.I.t;
    final c = s.center(Offset.zero);
    final r = s.shortestSide / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(
          transform: GradientRotation(t * 2.4),
          colors: const [
            Color(0xFF00E5FF),
            Color(0xFFD500F9),
            Color(0xFFFFD740),
            Color(0xFF00E5FF),
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(c, r * 0.78, Paint()..color = const Color(0xFF0B1020));
    final g = glitchLevel(t);
    void txt(Offset off, Color col) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'TS',
          style: TextStyle(
              fontSize: r, height: 1.0, color: col, fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c + off - Offset(tp.width / 2, tp.height / 2));
    }

    if (g > 0) {
      txt(Offset(-r * 0.12 * g, 0), const Color(0xAAFF1744));
      txt(Offset(r * 0.12 * g, 0), const Color(0xAA00E5FF));
    }
    txt(Offset(sin(t * 47) * r * 0.03 * (1 + 3 * g), 0), Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
