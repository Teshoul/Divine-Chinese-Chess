import 'dart:math';
import 'package:flutter/material.dart';

class DecorPainter extends CustomPainter {
  final String id;
  final bool dark;
  const DecorPainter(this.id, this.dark);

  Paint _fill(Color c, double a) => Paint()..color = c.withOpacity(a);
  Paint _line(Color c, double a, double w) => Paint()
    ..color = c.withOpacity(a)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size s) {
    switch (id) {
      case 'guofeng':
        _guofeng(canvas, s);
        break;
      case 'starry':
        _starry(canvas, s);
        break;
      case 'furry':
        _furry(canvas, s);
        break;
      case 'tech':
        _tech(canvas, s);
        break;
      default:
        _mono(canvas, s);
    }
  }

  void _roof(Canvas c, double cx, double y, double w, double h, Paint p) {
    final path = Path()
      ..moveTo(cx - w / 2, y)
      ..quadraticBezierTo(cx - w * 0.33, y - h * 0.15, cx - w * 0.2, y - h * 0.8)
      ..lineTo(cx + w * 0.2, y - h * 0.8)
      ..quadraticBezierTo(cx + w * 0.33, y - h * 0.15, cx + w / 2, y)
      ..quadraticBezierTo(cx, y + h * 0.3, cx - w / 2, y)
      ..close();
    c.drawPath(path, p);
    c.drawRect(
        Rect.fromCenter(center: Offset(cx, y - h * 0.86), width: w * 0.46, height: h * 0.12),
        p);
  }

  void _guofeng(Canvas c, Size s) {
    final ink = dark ? const Color(0xFFFFE0B2) : const Color(0xFF5B3A1E);
    final a = dark ? 0.07 : 0.10;
    final p = _fill(ink, a);
    final w = s.width, h = s.height;
    c.drawCircle(Offset(w * 0.78, h * 0.14), w * 0.1,
        _fill(const Color(0xFFC62828), dark ? 0.12 : 0.14));
    for (var i = 0; i < 3; i++) {
      final r = w * (0.05 + 0.035 * i);
      c.drawArc(Rect.fromCircle(center: Offset(w * 0.22, h * 0.22), radius: r), pi, pi, false,
          _line(ink, a * 1.3, 2));
      c.drawArc(Rect.fromCircle(center: Offset(w * 0.3, h * 0.235), radius: r * 0.8), pi, pi,
          false, _line(ink, a * 1.3, 2));
    }
    final m1 = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.80)
      ..quadraticBezierTo(w * 0.18, h * 0.70, w * 0.34, h * 0.81)
      ..quadraticBezierTo(w * 0.5, h * 0.72, w * 0.68, h * 0.82)
      ..quadraticBezierTo(w * 0.85, h * 0.74, w, h * 0.80)
      ..lineTo(w, h)
      ..close();
    c.drawPath(m1, _fill(ink, a * 0.8));
    final m2 = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.90)
      ..quadraticBezierTo(w * 0.25, h * 0.83, w * 0.5, h * 0.9)
      ..quadraticBezierTo(w * 0.75, h * 0.96, w, h * 0.88)
      ..lineTo(w, h)
      ..close();
    c.drawPath(m2, _fill(ink, a * 1.1));
    for (var i = 0; i < 5; i++) {
      final tw = w * (0.17 - i * 0.022);
      final ty = h * 0.86 - i * h * 0.045;
      c.drawRect(
          Rect.fromCenter(
              center: Offset(w * 0.82, ty - h * 0.012), width: tw * 0.62, height: h * 0.026),
          p);
      _roof(c, w * 0.82, ty - h * 0.025, tw, h * 0.03, p);
    }
    c.drawRect(Rect.fromLTWH(w * 0.82 - 1.5, h * 0.86 - 5 * h * 0.045 - h * 0.07, 3, h * 0.05), p);
    for (var i = 0; i < 4; i++) {
      c.drawRect(Rect.fromLTWH(w * 0.12 + i * w * 0.04, h * 0.87 - h * 0.04, 3.5, h * 0.04), p);
    }
    _roof(c, w * 0.18, h * 0.87 - h * 0.04, w * 0.2, h * 0.05, p);
    c.drawRect(Rect.fromLTWH(w * 0.1, h * 0.87, w * 0.16, h * 0.008), p);
  }

  void _spark(Canvas c, Offset o, double r, Paint p) {
    final path = Path()
      ..moveTo(o.dx, o.dy - r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
      ..close();
    c.drawPath(path, p);
  }

  void _starry(Canvas c, Size s) {
    final ink = dark ? Colors.white : const Color(0xFF5E35B1);
    final r = Random(11);
    for (var i = 0; i < 80; i++) {
      final x = r.nextDouble() * s.width;
      final y = r.nextDouble() * s.height;
      final rad = 0.5 + r.nextDouble() * 1.6;
      c.drawCircle(Offset(x, y), rad,
          _fill(ink, (dark ? 0.35 : 0.18) * (0.4 + r.nextDouble() * 0.6)));
    }
    for (var i = 0; i < 6; i++) {
      _spark(c, Offset(r.nextDouble() * s.width, r.nextDouble() * s.height * 0.8),
          6 + r.nextDouble() * 8, _fill(ink, dark ? 0.4 : 0.22));
    }
    final cx = s.width * 0.8, cy = s.height * 0.13, mr = s.width * 0.09;
    final moon = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: mr)),
        Path()
          ..addOval(Rect.fromCircle(
              center: Offset(cx + mr * 0.45, cy - mr * 0.15), radius: mr * 0.85)));
    c.drawPath(moon, _fill(dark ? const Color(0xFFFFF3C4) : ink, dark ? 0.55 : 0.2));
    c.drawLine(Offset(s.width * 0.15, s.height * 0.1), Offset(s.width * 0.3, s.height * 0.16),
        _line(ink, dark ? 0.4 : 0.2, 1.6));
    c.drawCircle(Offset(s.width * 0.15, s.height * 0.1), 2.2, _fill(ink, dark ? 0.6 : 0.3));
  }

  void _paw(Canvas c, Offset o, double r, double rot, Paint p) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(rot);
    c.drawOval(Rect.fromCenter(center: Offset(0, r * 0.35), width: r * 1.5, height: r * 1.2), p);
    for (final d in const [
      [-0.75, -0.35],
      [-0.28, -0.85],
      [0.28, -0.85],
      [0.75, -0.35]
    ]) {
      c.drawOval(
          Rect.fromCenter(center: Offset(d[0] * r, d[1] * r), width: r * 0.5, height: r * 0.65),
          p);
    }
    c.restore();
  }

  void _cat(Canvas c, Offset o, double u, Paint p, bool flip) {
    c.save();
    c.translate(o.dx, o.dy);
    if (flip) c.scale(-1, 1);
    c.drawOval(Rect.fromCenter(center: Offset(0, -u * 1.1), width: u * 1.9, height: u * 2.2), p);
    c.drawCircle(Offset(0, -u * 2.55), u * 0.82, p);
    final ears = Path()
      ..moveTo(-u * 0.78, -u * 2.9)
      ..lineTo(-u * 0.62, -u * 3.75)
      ..lineTo(-u * 0.1, -u * 3.25)
      ..close()
      ..moveTo(u * 0.78, -u * 2.9)
      ..lineTo(u * 0.62, -u * 3.75)
      ..lineTo(u * 0.1, -u * 3.25)
      ..close();
    c.drawPath(ears, p);
    final tail = Path()
      ..moveTo(u * 0.8, -u * 0.3)
      ..quadraticBezierTo(u * 2.4, -u * 0.2, u * 1.9, -u * 1.9);
    c.drawPath(
        tail,
        Paint()
          ..color = p.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.42
          ..strokeCap = StrokeCap.round);
    c.restore();
  }

  void _furry(Canvas c, Size s) {
    final ink = dark ? const Color(0xFFFFCC80) : const Color(0xFF8D5524);
    final p = _fill(ink, dark ? 0.09 : 0.10);
    final r = Random(5);
    for (var i = 0; i < 9; i++) {
      _paw(c, Offset(r.nextDouble() * s.width, r.nextDouble() * s.height * 0.75),
          8 + r.nextDouble() * 8, (r.nextDouble() - 0.5) * 1.2, _fill(ink, dark ? 0.07 : 0.08));
    }
    _cat(c, Offset(s.width * 0.2, s.height - 12), s.width * 0.045, p, false);
    _cat(c, Offset(s.width * 0.8, s.height - 12), s.width * 0.05, p, true);
  }

  void _tech(Canvas c, Size s) {
    final ink = dark ? const Color(0xFF00E5FF) : const Color(0xFF00838F);
    final a = dark ? 0.08 : 0.10;
    final g = _line(ink, a * 0.8, 0.7);
    for (double x = 0; x < s.width; x += 44) {
      c.drawLine(Offset(x, 0), Offset(x, s.height), g);
    }
    for (double y = 0; y < s.height; y += 44) {
      c.drawLine(Offset(0, y), Offset(s.width, y), g);
    }
    final r = Random(3);
    final tp = _line(ink, a * 2.2, 1.6);
    for (var i = 0; i < 7; i++) {
      var x = r.nextInt((s.width / 44).floor()) * 44.0;
      var y = r.nextInt((s.height / 44).floor()) * 44.0;
      final path = Path()..moveTo(x, y);
      for (var k = 0; k < 4; k++) {
        final d = (r.nextBool() ? 1 : -1) * 44.0 * (1 + r.nextInt(2));
        if (r.nextBool()) {
          x += d;
        } else {
          y += d;
        }
        path.lineTo(x, y);
      }
      c.drawPath(path, tp);
      c.drawCircle(Offset(x, y), 4, _fill(ink, a * 3));
    }
    final b = _line(ink, a * 3, 2.4);
    const m = 14.0, len = 26.0;
    c.drawPath(Path()..moveTo(m, m + len)..lineTo(m, m)..lineTo(m + len, m), b);
    c.drawPath(
        Path()..moveTo(s.width - m - len, m)..lineTo(s.width - m, m)..lineTo(s.width - m, m + len),
        b);
    c.drawPath(
        Path()
          ..moveTo(m, s.height - m - len)
          ..lineTo(m, s.height - m)
          ..lineTo(m + len, s.height - m),
        b);
    c.drawPath(
        Path()
          ..moveTo(s.width - m - len, s.height - m)
          ..lineTo(s.width - m, s.height - m)
          ..lineTo(s.width - m, s.height - m - len),
        b);
  }

  void _mono(Canvas c, Size s) {
    final ink = dark ? Colors.white : Colors.black;
    for (var i = 1; i <= 6; i++) {
      c.drawCircle(Offset(s.width * 0.9, s.height * 0.12), s.width * 0.12 * i, _line(ink, 0.06, 1.2));
    }
    for (var i = 1; i <= 5; i++) {
      c.drawCircle(Offset(s.width * 0.05, s.height * 0.92), s.width * 0.1 * i, _line(ink, 0.06, 1.2));
    }
  }

  @override
  bool shouldRepaint(covariant DecorPainter old) => old.id != id || old.dark != dark;
}
