import 'package:flutter/material.dart';

const Color kRedC = Color(0xFFC62828);
const Color kBlackC = Color(0xFF212121);
const Color kLineC = Color(0xFF5B3A1E);

void drawText(Canvas canvas, String s, Offset center, double size, Color color) {
  final tp = TextPainter(
    text: TextSpan(
        text: s,
        style: TextStyle(
            fontSize: size, color: color, fontWeight: FontWeight.bold)),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

void drawBoard(Canvas canvas, double cell, double dy) {
  Offset p(int r, int c) => Offset(cell * (c + 0.5), dy + cell * (r + 0.5));
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(0, dy, cell * 9, cell * 10),
        Radius.circular(cell * 0.3)),
    Paint()..color = const Color(0xFFE9CB93),
  );
  final line = Paint()
    ..color = kLineC
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;
  for (var r = 0; r < 10; r++) {
    canvas.drawLine(p(r, 0), p(r, 8), line);
  }
  for (var c = 0; c < 9; c++) {
    if (c == 0 || c == 8) {
      canvas.drawLine(p(0, c), p(9, c), line);
    } else {
      canvas.drawLine(p(0, c), p(4, c), line);
      canvas.drawLine(p(5, c), p(9, c), line);
    }
  }
  canvas.drawLine(p(0, 3), p(2, 5), line);
  canvas.drawLine(p(0, 5), p(2, 3), line);
  canvas.drawLine(p(7, 3), p(9, 5), line);
  canvas.drawLine(p(7, 5), p(9, 3), line);
  final river = kLineC.withOpacity(0.6);
  drawText(canvas, '楚 河', Offset(cell * 2.5, dy + cell * 5), cell * 0.5, river);
  drawText(canvas, '汉 界', Offset(cell * 6.5, dy + cell * 5), cell * 0.5, river);
}

void drawPiece(
    Canvas canvas, Offset ctr, double rad, String label, Color col) {
  canvas.drawCircle(ctr + const Offset(0, 2), rad, Paint()..color = Colors.black26);
  canvas.drawCircle(ctr, rad, Paint()..color = const Color(0xFFF6E3B4));
  canvas.drawCircle(
      ctr,
      rad,
      Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
  canvas.drawCircle(
      ctr,
      rad * 0.82,
      Paint()
        ..color = col.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
  drawText(canvas, label, ctr, rad * 1.2, col);
}

void drawHidden(Canvas canvas, Offset ctr, double rad, {String hint = '暗'}) {
  const col = Color(0xFF6D4C41);
  canvas.drawCircle(ctr + const Offset(0, 2), rad, Paint()..color = Colors.black26);
  canvas.drawCircle(ctr, rad, Paint()..color = const Color(0xFFC9A66B));
  canvas.drawCircle(
      ctr,
      rad,
      Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
  canvas.drawCircle(
      ctr,
      rad * 0.82,
      Paint()
        ..color = col.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
  drawText(canvas, hint, ctr, rad * 1.2, col.withOpacity(0.85));
}
