import 'package:flutter/material.dart';
import 'strings.dart';

/// 背景图编辑器用：手机屏幕外形（刘海 / 挖孔 / 曲面…）和界面遮挡区域
class Zone {
  final String label;
  final double l, t, w, h;
  const Zone(this.label, this.l, this.t, this.w, this.h);
}

List<Zone> zonesFor(String slot) {
  if (slot == 'home') {
    return const [
      Zone('头像', 0.04, 0.03, 0.14, 0.06),
      Zone('标题', 0.3, 0.07, 0.4, 0.09),
      Zone('四宫格', 0.05, 0.29, 0.9, 0.42),
      Zone('设置按钮', 0.80, 0.905, 0.15, 0.07),
    ];
  }
  if (slot == 'game') {
    return const [
      Zone('标题栏', 0.0, 0.03, 1.0, 0.07),
      Zone('状态栏', 0.15, 0.10, 0.7, 0.09),
      Zone('棋盘', 0.02, 0.20, 0.96, 0.60),
      Zone('按钮栏', 0.0, 0.86, 1.0, 0.09),
    ];
  }
  return const [];
}

class ZonePainter extends CustomPainter {
  final List<Zone> zones;
  ZonePainter(this.zones);

  @override
  void paint(Canvas canvas, Size s) {
    for (final z in zones) {
      final r = Rect.fromLTWH(z.l * s.width, z.t * s.height, z.w * s.width, z.h * s.height);
      canvas.drawRect(r, Paint()..color = Colors.red.withOpacity(0.18));
      canvas.save();
      canvas.clipRect(r);
      final lp = Paint()
        ..color = Colors.red.withOpacity(0.55)
        ..strokeWidth = 1.2;
      for (double x = r.left - r.height; x < r.right; x += 8) {
        canvas.drawLine(Offset(x, r.bottom), Offset(x + r.height, r.top), lp);
      }
      canvas.restore();
      canvas.drawRect(
          r,
          Paint()
            ..color = Colors.red
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
      final tp = TextPainter(
        text: TextSpan(
          text: tr(z.label),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              backgroundColor: Color(0xCCD32F2F)),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r.width);
      tp.paint(canvas, r.topLeft + const Offset(2, 2));
    }
  }

  @override
  bool shouldRepaint(covariant ZonePainter old) => true;
}

// ───────────── 手机屏幕外形 ─────────────

class ScreenFrame {
  final String name;
  final double ar; // 高 / 宽，0 = 用当前手机的真实比例
  final double rad; // 圆角，占宽度的比例，>=0.5 就是圆形
  final int kind; // 0 无 1 刘海 2 水滴 3 居中挖孔 4 左上挖孔 5 右上挖孔 6 灵动岛 7 曲面 8 瀑布 9 折叠
  const ScreenFrame(this.name, this.ar, this.rad, this.kind);
}

const List<ScreenFrame> kScreenFrames = [
  ScreenFrame('标准全面屏', 2.05, 0.09, 0),
  ScreenFrame('直角全面屏', 2.05, 0, 0),
  ScreenFrame('16:9 直屏', 1.78, 0, 0),
  ScreenFrame('18:9 全面屏', 2.0, 0.06, 0),
  ScreenFrame('21:9 长屏', 2.33, 0.09, 0),
  ScreenFrame('刘海屏', 2.17, 0.09, 1),
  ScreenFrame('水滴屏', 2.1, 0.08, 2),
  ScreenFrame('居中挖孔', 2.1, 0.11, 3),
  ScreenFrame('左上挖孔', 2.1, 0.11, 4),
  ScreenFrame('右上挖孔', 2.1, 0.11, 5),
  ScreenFrame('灵动岛', 2.17, 0.14, 6),
  ScreenFrame('曲面屏', 2.15, 0.12, 7),
  ScreenFrame('瀑布屏', 2.2, 0.16, 8),
  ScreenFrame('折叠屏·内屏', 1.12, 0.05, 9),
  ScreenFrame('折叠屏·外屏', 2.5, 0.09, 3),
  ScreenFrame('平板 4:3', 1.33, 0.04, 0),
  ScreenFrame('平板 16:10', 1.6, 0.04, 0),
  ScreenFrame('大圆角屏', 2.05, 0.18, 0),
  ScreenFrame('方形屏', 1.0, 0.02, 0),
  ScreenFrame('圆形屏（手表）', 1.0, 0.5, 0),
  ScreenFrame('我的手机', 0, 0.09, 0),
];

Path screenFramePath(ScreenFrame f, Size s) {
  final r = f.rad * s.width;
  if (f.rad >= 0.5) return Path()..addOval(Offset.zero & s);
  if (r <= 0) return Path()..addRect(Offset.zero & s);
  return Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(r)));
}

class FrameClipper extends CustomClipper<Path> {
  final ScreenFrame f;
  FrameClipper(this.f);
  @override
  Path getClip(Size size) => screenFramePath(f, size);
  @override
  bool shouldReclip(covariant FrameClipper old) => old.f != f;
}

/// 刘海 / 挖孔 / 曲面边缘等遮挡物，画在预览框的最上层
class FramePainter extends CustomPainter {
  final ScreenFrame f;
  FramePainter(this.f);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final black = Paint()..color = const Color(0xEE000000);
    switch (f.kind) {
      case 1:
        canvas.drawRRect(
            RRect.fromRectAndCorners(Rect.fromLTWH(w * 0.3, 0, w * 0.4, w * 0.075),
                bottomLeft: Radius.circular(w * 0.04), bottomRight: Radius.circular(w * 0.04)),
            black);
        break;
      case 2:
        canvas.drawRRect(
            RRect.fromRectAndCorners(Rect.fromLTWH(w * 0.4, 0, w * 0.2, w * 0.055),
                bottomLeft: Radius.circular(w * 0.05), bottomRight: Radius.circular(w * 0.05)),
            black);
        break;
      case 3:
        canvas.drawCircle(Offset(w * 0.5, w * 0.045), w * 0.026, black);
        break;
      case 4:
        canvas.drawCircle(Offset(w * 0.12, w * 0.045), w * 0.026, black);
        break;
      case 5:
        canvas.drawCircle(Offset(w * 0.88, w * 0.045), w * 0.026, black);
        break;
      case 6:
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * 0.34, w * 0.03, w * 0.32, w * 0.065), Radius.circular(w * 0.04)),
            black);
        break;
      case 7:
      case 8:
        final ew = w * (f.kind == 7 ? 0.05 : 0.1);
        for (final left in [true, false]) {
          final r = left ? Rect.fromLTWH(0, 0, ew, s.height) : Rect.fromLTWH(w - ew, 0, ew, s.height);
          final g = LinearGradient(
            begin: left ? Alignment.centerLeft : Alignment.centerRight,
            end: left ? Alignment.centerRight : Alignment.centerLeft,
            colors: const [Color(0x99000000), Color(0x00000000)],
          );
          canvas.drawRect(r, Paint()..shader = g.createShader(r));
        }
        break;
      case 9:
        canvas.drawRect(Rect.fromLTWH(s.width / 2 - 1.2, 0, 2.4, s.height),
            Paint()..color = const Color(0x66000000));
        break;
    }
  }

  @override
  bool shouldRepaint(covariant FramePainter old) => old.f != f;
}

