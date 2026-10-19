import 'dart:math';
import 'package:flutter/material.dart';
import 'liquid.dart';

const String kStarAvatar = 'builtin:star';
const Color _gold = Color(0xFFFFC107);
const Color _paleGold = Color(0xFFFFF1B8);

Path starPath(Offset c, double r, {double pinch = 0.16}) {
  final k = r * pinch;
  return Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
    ..close();
}

/// 间歇式故障：每 3 秒一次主故障，另有短暂的小故障
double glitchLevel(double t) {
  final a = t % 3.0;
  if (a > 2.55 && a < 2.95) return 0.55 + 0.45 * sin((a - 2.55) * 55).abs();
  final b = (t + 1.3) % 5.1;
  if (b > 4.8 && b < 4.93) return 0.6;
  return 0.0;
}

void paintGlitchStar(Canvas canvas, Offset c, double r, double t,
    {double op = 1.0, bool glow = true}) {
  final g = glitchLevel(t);
  final k = 1 + 6 * g;
  final center = c + Offset(sin(t * 43) * r * 0.004 * k, cos(t * 51) * r * 0.004 * k);
  final rr = r * (1 + 0.025 * sin(t * 2.2));
  final path = starPath(center, rr);
  final rect = Rect.fromCircle(center: center, radius: rr);
  if (glow) {
    canvas.drawPath(
        path,
        Paint()
          ..color = _gold.withOpacity(0.38 * op)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, rr * 0.22));
  }
  final body = Paint()
    ..shader = RadialGradient(
      colors: [
        Colors.white.withOpacity(op),
        _paleGold.withOpacity(op),
        _gold.withOpacity(op),
        const Color(0xFFFF8F00).withOpacity(op),
      ],
      stops: const [0.0, 0.18, 0.5, 1.0],
    ).createShader(rect);
  if (g > 0) {
    final off = rr * 0.06 * g;
    canvas.drawPath(starPath(center + Offset(-off, 0), rr),
        Paint()..color = const Color(0xFFFF1744).withOpacity(0.65 * op));
    canvas.drawPath(starPath(center + Offset(off, 0), rr),
        Paint()..color = const Color(0xFF00E5FF).withOpacity(0.45 * op));
  }
  if (g == 0 || sin(t * 170) > -0.4) canvas.drawPath(path, body);
  if (g > 0) {
    for (var i = 0; i < 3; i++) {
      final by = center.dy - rr + 2 * rr * (0.1 + 0.75 * (0.5 + 0.5 * sin(t * 91 + i * 7.0)));
      final bh = rr * (0.08 + 0.05 * i);
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(center.dx - rr * 2, by, rr * 4, bh));
      canvas.translate(sin(t * 133 + i * 3.0) * rr * 0.22 * g, 0);
      canvas.drawPath(path, body);
      canvas.restore();
    }
  }
}

class _StarFillPainter extends CustomPainter {
  _StarFillPainter() : super(repaint: LiquidClock.I);

  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0xFF7F0D0D), Color(0xFF1C0304)])
              .createShader(rect));
    paintGlitchStar(canvas, rect.center, min(s.width, s.height) * 0.42, LiquidClock.I.t,
        glow: s.width > 40);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 动态头像内容（填满父容器）
class StarAvatarFill extends StatefulWidget {
  const StarAvatarFill({super.key});
  @override
  State<StarAvatarFill> createState() => _StarAvatarFillState();
}

class _StarAvatarFillState extends State<StarAvatarFill> {
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
        child: CustomPaint(painter: _StarFillPainter(), size: Size.infinite));
  }
}

/// 头像右下角的故障四角星角标
class StarBadge extends StatelessWidget {
  final double size;
  const StarBadge({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _gold, width: max(1.0, size * 0.07)),
      ),
      child: ClipOval(child: const StarAvatarFill()),
    );
  }
}

/// 名字后面的“神”字圆圈标志
class DivineMark extends StatelessWidget {
  final double size;
  const DivineMark({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(colors: [Color(0xFFB71C1C), Color(0xFF4A0707)]),
        border: Border.all(color: _gold, width: max(1.0, size * 0.08)),
      ),
      child: Text(
        '神',
        style: TextStyle(
          fontSize: size * 0.62,
          height: 1.0,
          color: _paleGold,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
