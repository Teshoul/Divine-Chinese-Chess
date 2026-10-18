import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'settings.dart';

const Color _red = Color(0xFFC62828);
const Color _deepRed = Color(0xFF7F0000);
const Color _gold = Color(0xFFFFB300);
const Color _paleGold = Color(0xFFFFE082);

class LiquidClock extends ChangeNotifier {
  static final LiquidClock I = LiquidClock._();
  LiquidClock._();
  final Stopwatch _sw = Stopwatch()..start();
  int _users = 0;
  bool _running = false;
  double get t => _sw.elapsedMilliseconds / 1000.0;

  void attach() {
    _users++;
    if (!_running) {
      _running = true;
      _loop();
    }
  }

  void detach() {
    if (_users > 0) _users--;
  }

  void _loop() {
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (_users <= 0) {
        _running = false;
        return;
      }
      notifyListeners();
      _loop();
    });
  }
}

class LiquidPainter extends CustomPainter {
  final double phase;
  final int mode; // 0 背景  1 色块
  final bool dark;
  LiquidPainter({this.phase = 0, this.mode = 1, this.dark = true})
      : super(repaint: LiquidClock.I);

  @override
  void paint(Canvas canvas, Size s) {
    final t = LiquidClock.I.t + phase;
    final w = s.width, h = s.height;
    if (w <= 0 || h <= 0) return;
    final rect = Offset.zero & s;
    final bg = mode == 0;
    final a = bg ? (dark ? const Color(0xFF2A0606) : const Color(0xFFFFF0C8)) : _deepRed;
    final b = bg ? (dark ? const Color(0xFF080000) : const Color(0xFFFFD27A)) : _red;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1 + 0.4 * sin(t * 0.15), -1),
          end: Alignment(1, 1 + 0.4 * cos(t * 0.13)),
          colors: [a, b],
        ).createShader(rect),
    );
    final n = bg ? 7 : 4;
    final big = max(w, h);
    for (var i = 0; i < n; i++) {
      final k = i * 1.93;
      final c = Offset(
        w * (0.5 + 0.46 * sin(t * (0.21 + 0.03 * i) + k)),
        h * (0.5 + 0.46 * cos(t * (0.17 + 0.025 * i) + k * 1.3)),
      );
      final r = big * ((bg ? 0.5 : 0.7) + 0.12 * sin(t * 0.4 + k));
      final col = i.isEven ? _gold : _red;
      final op = bg ? (dark ? 0.45 : 0.40) : 0.8;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [col.withOpacity(op), col.withOpacity(0)])
              .createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
    final layers = bg ? 3 : 2;
    for (var j = 0; j < layers; j++) {
      final y0 = h * (0.35 + 0.25 * j) + h * 0.03 * sin(t * 0.3 + j);
      final amp = h * (bg ? 0.035 : 0.06);
      final step = max(6.0, w / 36);
      final path = Path()..moveTo(0, h);
      for (double x = 0; x <= w + step; x += step) {
        final y = y0 +
            amp * sin(x / w * 2 * pi * (1.2 + 0.4 * j) + t * (0.8 + 0.25 * j) + j * 2) +
            amp * 0.5 * sin(x / w * 2 * pi * 2.6 - t * 0.9 + j);
        path.lineTo(x, y);
      }
      path
        ..lineTo(w + step, h)
        ..close();
      final col = j.isEven ? _paleGold : _red;
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [col.withOpacity(bg ? 0.22 : 0.3), col.withOpacity(0)],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant LiquidPainter old) =>
      old.phase != phase || old.mode != mode || old.dark != dark;
}

/// 红金交融的流动色块，用于按钮 / 卡片
class LiquidFill extends StatefulWidget {
  final double radius;
  final double phase;
  final Widget? child;
  const LiquidFill({super.key, this.radius = 16, this.phase = 0, this.child});

  @override
  State<LiquidFill> createState() => _LiquidFillState();
}

class _LiquidFillState extends State<LiquidFill> {
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: _paleGold.withOpacity(0.75), width: 1.4),
        boxShadow: [
          BoxShadow(color: _gold.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(max(0.0, widget.radius - 1.4)),
        child: CustomPaint(
          painter: LiquidPainter(phase: widget.phase),
          child: widget.child ?? const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// 全屏流动背景
class LiquidBackdrop extends StatefulWidget {
  const LiquidBackdrop({super.key});

  @override
  State<LiquidBackdrop> createState() => _LiquidBackdropState();
}

class _LiquidBackdropState extends State<LiquidBackdrop> {
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
    final dark = app.isDark;
    return RepaintBoundary(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: LiquidPainter(mode: 0, dark: dark)),
            Center(
              child: Material(
                type: MaterialType.transparency,
                child: Text(
                  '神',
                  style: TextStyle(
                    fontSize: 320,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: _gold.withOpacity(dark ? 0.07 : 0.12),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
