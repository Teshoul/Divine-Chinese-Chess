import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'glitch.dart';

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

/// “神”主题的金红面板
BoxDecoration divineDecoration(double r, bool pressed) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(r),
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFB71C1C), Color(0xFF7F0D0D), Color(0xFF4A0707)],
    ),
    border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.85), width: 1.4),
    boxShadow: [
      BoxShadow(
          color: _gold.withOpacity(0.35),
          blurRadius: pressed ? 6 : 16,
          offset: Offset(0, pressed ? 2 : 6)),
      BoxShadow(
          color: Colors.black54, blurRadius: 8, offset: Offset(0, pressed ? 1 : 3)),
    ],
  );
}

class LiquidPainter extends CustomPainter {
  final double phase;
  LiquidPainter({this.phase = 0}) : super(repaint: LiquidClock.I);

  @override
  void paint(Canvas canvas, Size s) {
    final t = LiquidClock.I.t + phase;
    final w = s.width, h = s.height;
    if (w <= 0 || h <= 0) return;
    final rect = Offset.zero & s;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1 + 0.4 * sin(t * 0.15), -1),
          end: Alignment(1, 1 + 0.4 * cos(t * 0.13)),
          colors: const [_deepRed, _red],
        ).createShader(rect),
    );
    final big = max(w, h);
    for (var i = 0; i < 4; i++) {
      final k = i * 1.93;
      final c = Offset(
        w * (0.5 + 0.46 * sin(t * (0.21 + 0.03 * i) + k)),
        h * (0.5 + 0.46 * cos(t * (0.17 + 0.025 * i) + k * 1.3)),
      );
      final r = big * (0.7 + 0.12 * sin(t * 0.4 + k));
      final col = i.isEven ? _gold : _red;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [col.withOpacity(0.8), col.withOpacity(0)])
              .createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
    for (var j = 0; j < 2; j++) {
      final y0 = h * (0.35 + 0.25 * j) + h * 0.03 * sin(t * 0.3 + j);
      final amp = h * 0.06;
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
            colors: [col.withOpacity(0.3), col.withOpacity(0)],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant LiquidPainter old) => old.phase != phase;
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

double _fr(double v) => v - v.floorToDouble();

class _MeteorPainter extends CustomPainter {
  _MeteorPainter() : super(repaint: LiquidClock.I);

  @override
  void paint(Canvas canvas, Size s) {
    final t = LiquidClock.I.t;
    final w = s.width, h = s.height;
    if (w <= 0 || h <= 0) return;
    final rect = Offset.zero & s;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C0304), Color(0xFF3B0709), Color(0xFF120203)],
        ).createShader(rect),
    );
    final cc = Offset(w * 0.5, h * 0.44);
    canvas.drawCircle(
      cc,
      w * 0.85,
      Paint()
        ..shader = RadialGradient(colors: [_gold.withOpacity(0.22), Colors.transparent])
            .createShader(Rect.fromCircle(center: cc, radius: w * 0.85)),
    );
    for (var i = 0; i < 40; i++) {
      final x = _fr(sin(i * 12.9898) * 43758.5453) * w;
      final y = _fr(sin(i * 78.233) * 12345.6789) * h;
      final a = 0.15 + 0.45 * (0.5 + 0.5 * sin(t * (0.8 + _fr(i * 0.37)) + i));
      canvas.drawCircle(Offset(x, y), 0.8 + _fr(i * 0.61) * 1.2,
          Paint()..color = _paleGold.withOpacity(a));
    }
    const dx = -0.6, dy = 0.8;
    for (var i = 0; i < 18; i++) {
      final period = 2.4 + _fr(i * 0.7371) * 3.2;
      final u = _fr(t / period + _fr(i * 0.618034));
      final lane = _fr(i * 0.754877 + 0.13);
      final sx = w * (-0.1 + 1.5 * lane);
      final sy = -h * 0.15;
      final travel = h * 1.45;
      final head = Offset(sx + dx * travel * u, sy + dy * travel * u);
      final tl = h * (0.10 + 0.16 * _fr(i * 0.331));
      final tail = head - Offset(dx * tl, dy * tl);
      final a = sin(pi * u).clamp(0.0, 1.0).toDouble();
      final wd = 1.4 + 2.6 * _fr(i * 0.173);
      canvas.drawLine(
        tail,
        head,
        Paint()
          ..strokeWidth = wd
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(
            tail,
            head,
            [_gold.withOpacity(0), _gold.withOpacity(0.9 * a), Colors.white.withOpacity(a)],
            const [0.0, 0.7, 1.0],
          ),
      );
      canvas.drawCircle(
        head,
        wd * 1.6,
        Paint()
          ..color = const Color(0xFFFFF3C4).withOpacity(a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    paintGlitchStar(canvas, cc, w * 0.42, t, op: 0.55);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// “神”主题背景：金流星 + 间歇故障的大四角星
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
    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(painter: _MeteorPainter(), size: Size.infinite),
      ),
    );
  }
}
