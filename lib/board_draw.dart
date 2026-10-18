import 'dart:math';
import 'package:flutter/material.dart';
import 'engine.dart';
import 'settings.dart';

Color get kRedC => app.red;
Color get kBlackC => app.black;
Color get kLineC => app.boardLine;
const Color kGold = Color(0xFFFFB300);

Color faceOf(Color col) =>
    col.toARGB32() == app.black.toARGB32() ? app.faceBlack : app.faceRed;

void drawText(Canvas canvas, String s, Offset center, double size, Color color) {
  final tp = TextPainter(
    text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: color, fontWeight: FontWeight.bold)),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

void drawBoard(Canvas canvas, double cell, double dy) {
  Offset p(int r, int c) => Offset(cell * (c + 0.5), dy + cell * (r + 0.5));
  final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, dy, cell * 9, cell * 10), Radius.circular(cell * 0.3));
  final lc = app.boardLine;
  canvas.drawRRect(rect.shift(Offset(0, cell * 0.06)), Paint()..color = Colors.black26);
  canvas.drawRRect(rect, Paint()..color = app.boardBg);
  canvas.drawRRect(
      rect,
      Paint()
        ..color = lc.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
  final line = Paint()
    ..color = lc
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;
  final glowP = Paint()
    ..color = lc.withOpacity(0.35)
    ..strokeWidth = 4
    ..style = PaintingStyle.stroke
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  void seg(Offset a, Offset b) {
    if (app.glow) canvas.drawLine(a, b, glowP);
    canvas.drawLine(a, b, line);
  }

  for (var r = 0; r < 10; r++) {
    seg(p(r, 0), p(r, 8));
  }
  for (var c = 0; c < 9; c++) {
    if (c == 0 || c == 8) {
      seg(p(0, c), p(9, c));
    } else {
      seg(p(0, c), p(4, c));
      seg(p(5, c), p(9, c));
    }
  }
  seg(p(0, 3), p(2, 5));
  seg(p(0, 5), p(2, 3));
  seg(p(7, 3), p(9, 5));
  seg(p(7, 5), p(9, 3));
  final river = lc.withOpacity(0.55);
  drawText(canvas, '楚 河', Offset(cell * 2.5, dy + cell * 5), cell * 0.5, river);
  drawText(canvas, '汉 界', Offset(cell * 6.5, dy + cell * 5), cell * 0.5, river);
}

void _disc(Canvas canvas, Offset ctr, double rad, Color face, Color ring,
    {bool glow = false}) {
  final th = rad * 0.16;
  final edge = Color.lerp(face, Colors.black, 0.45)!;
  canvas.drawCircle(
      ctr + Offset(0, th + 2),
      rad,
      Paint()
        ..color = Colors.black38
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  final side = Paint()..color = edge;
  canvas.drawCircle(ctr + Offset(0, th), rad, side);
  canvas.drawRect(Rect.fromLTRB(ctr.dx - rad, ctr.dy, ctr.dx + rad, ctr.dy + th), side);
  if (glow) {
    canvas.drawCircle(
        ctr,
        rad,
        Paint()
          ..color = ring.withOpacity(0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }
  canvas.drawCircle(ctr, rad, Paint()..color = face);
  canvas.drawCircle(ctr - Offset(rad * 0.25, rad * 0.3), rad * 0.55,
      Paint()..color = Colors.white.withOpacity(0.10));
  canvas.drawCircle(
      ctr,
      rad,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
  canvas.drawCircle(
      ctr,
      rad * 0.82,
      Paint()
        ..color = ring.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
}

void drawPiece(Canvas canvas, Offset ctr, double rad, String label, Color col) {
  _disc(canvas, ctr, rad, faceOf(col), col, glow: app.glow);
  drawText(canvas, label, ctr, rad * 1.2, col);
}

void drawHidden(Canvas canvas, Offset ctr, double rad, {String? hint}) {
  final ink = app.preset.hidInk;
  _disc(canvas, ctr, rad, app.preset.hid, ink);
  drawText(canvas, hint ?? app.preset.hidText, ctr, rad * 1.2, ink.withOpacity(0.9));
}

/// 翻面动画：f 从 0 到 1，带厚度的侧边
void drawFlip(Canvas canvas, Offset ctr, double rad, double f, String label, Color col) {
  final ang = f * pi;
  final cs = cos(ang);
  final sn = sin(ang);
  final w = cs.abs();
  final front = cs < 0;
  final face = front ? faceOf(col) : app.preset.hid;
  final ring = front ? col : app.preset.hidInk;
  final edge = Color.lerp(face, Colors.black, 0.5)!;
  final th = rad * 0.34;
  final c = ctr - Offset(0, sn * rad * 0.45);

  canvas.drawOval(
      Rect.fromCenter(
          center: ctr + Offset(0, rad * 0.95),
          width: rad * 1.7 * (1 - 0.4 * sn),
          height: rad * 0.4),
      Paint()..color = Colors.black26);

  final bodyW = max(2 * rad * w + th * sn, 1.0);
  canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: bodyW, height: 2 * rad),
          Radius.circular(min(bodyW, 2 * rad) / 2)),
      Paint()..color = edge);

  final shift = (front ? 1 : -1) * th * sn / 2;
  final faceRect = Rect.fromCenter(
      center: c + Offset(shift, 0), width: max(2 * rad * w, 0.5), height: 2 * rad);
  canvas.drawOval(faceRect, Paint()..color = face);
  canvas.drawOval(
      faceRect,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
  if (w > 0.25) {
    canvas.save();
    canvas.translate(faceRect.center.dx, faceRect.center.dy);
    canvas.scale(w, 1.0);
    drawText(canvas, front ? label : app.preset.hidText, Offset.zero, rad * 1.2, ring);
    canvas.restore();
  }
}

/// 阵亡区：红方红色框，黑方黑色框（深色主题下带极细白边）
void drawTray(Canvas canvas, double cell, double y, Side side, List<Piece> dead,
    {int fresh = -1, double t = 1, double pulse = 0}) {
  final isRed = side == Side.red;
  final dark = app.isDark;
  final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, y + cell * 0.08, cell * 9, cell * 0.84),
      Radius.circular(cell * 0.25));
  final Color labelCol;
  if (isRed) {
    canvas.drawRRect(rr, Paint()..color = app.red.withOpacity(dark ? 0.22 : 0.12));
    canvas.drawRRect(
        rr,
        Paint()
          ..color = app.red.withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
    labelCol = dark ? Color.lerp(app.red, Colors.white, 0.4)! : app.red;
  } else {
    canvas.drawRRect(rr, Paint()..color = const Color(0xFF111111).withOpacity(0.94));
    canvas.drawRRect(
        rr,
        Paint()
          ..color = dark ? Colors.white.withOpacity(0.8) : Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = dark ? 0.7 : 1.6);
    labelCol = Colors.white70;
  }
  drawText(canvas, tr(isRed ? '红方\n阵亡' : '黑方\n阵亡'),
      Offset(cell * 0.75, y + cell * 0.5), cell * 0.26, labelCol);
  for (var i = 0; i < dead.length; i++) {
    final ctr = Offset(cell * 1.55 + i * cell * 0.46, y + cell * 0.5);
    final isNew = i == fresh;
    final scale = isNew ? 1 + 0.9 * (1 - t) : 1.0;
    final p = dead[i];
    drawPiece(canvas, ctr, cell * 0.21 * scale, p.label,
        p.side == Side.red ? app.red : app.black);
    if (isNew) {
      canvas.drawCircle(
          ctr,
          cell * (0.29 + 0.03 * pulse),
          Paint()
            ..color = kGold.withOpacity(0.55 + 0.45 * pulse)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6);
    }
  }
}
