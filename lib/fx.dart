import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'settings.dart';
import 'ui.dart';

final GlobalKey rootKey = GlobalKey();
Offset lastTap = Offset.zero;

double _maxR(Size s, Offset o) {
  final dx = max(o.dx, s.width - o.dx);
  final dy = max(o.dy, s.height - o.dy);
  return sqrt(dx * dx + dy * dy);
}

class CircleClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;
  final bool invert;
  CircleClipper(this.center, this.radius, {this.invert = false});

  @override
  Path getClip(Size size) {
    final circle = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    if (!invert) return circle;
    return Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), circle);
  }

  @override
  bool shouldReclip(CircleClipper old) =>
      old.radius != radius || old.center != center || old.invert != invert;
}

/// 从点击位置扩散到全屏，退出时缩回去
Route<void> revealRoute(Widget page) {
  final origin = lastTap;
  final mode = app.fxMode;
  return PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: Duration(milliseconds: mode == 2 ? 0 : 560),
    reverseTransitionDuration: Duration(milliseconds: mode == 2 ? 0 : 420),
    pageBuilder: (context, a, s) => AppBackdrop(child: page),
    transitionsBuilder: (context, a, s, child) {
      if (mode == 2) return child;
      final t = a.drive(CurveTween(curve: Curves.easeInOutCubic));
      if (mode == 1) return FadeTransition(opacity: t, child: child);
      return AnimatedBuilder(
        animation: t,
        child: child,
        builder: (context, ch) {
          final size = MediaQuery.sizeOf(context);
          return ClipPath(
            clipper: CircleClipper(origin, _maxR(size, origin) * t.value),
            child: ch,
          );
        },
      );
    },
  );
}

/// 主题切换：先截下旧画面，应用新主题后，旧画面从点击处裂开消失
Future<void> animatedChange(BuildContext context, VoidCallback change) async {
  final ro = rootKey.currentContext?.findRenderObject();
  if (app.fxMode == 2 || ro is! RenderRepaintBoundary) {
    app.change(change);
    return;
  }
  final origin = lastTap;
  final fade = app.fxMode == 1;
  ui.Image img;
  try {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    img = await ro.toImage(pixelRatio: dpr * 0.7);
  } catch (_) {
    app.change(change);
    return;
  }
  if (!context.mounted) {
    img.dispose();
    app.change(change);
    return;
  }
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ThemeFx(
      image: img,
      origin: origin,
      fade: fade,
      onDone: () {
        entry.remove();
        img.dispose();
      },
    ),
  );
  overlay.insert(entry);
  app.change(change);
}

class _ThemeFx extends StatefulWidget {
  final ui.Image image;
  final Offset origin;
  final bool fade;
  final VoidCallback onDone;
  const _ThemeFx(
      {required this.image, required this.origin, required this.fade, required this.onDone});

  @override
  State<_ThemeFx> createState() => _ThemeFxState();
}

class _ThemeFxState extends State<_ThemeFx> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: Duration(milliseconds: widget.fade ? 420 : 680));
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_c.value);
          final img = SizedBox.expand(child: RawImage(image: widget.image, fit: BoxFit.fill));
          if (widget.fade) return Opacity(opacity: 1 - t, child: img);
          final size = MediaQuery.sizeOf(context);
          return ClipPath(
            clipper: CircleClipper(widget.origin, _maxR(size, widget.origin) * t, invert: true),
            child: img,
          );
        },
      ),
    );
  }
}
