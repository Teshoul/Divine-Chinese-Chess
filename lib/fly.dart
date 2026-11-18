import 'dart:math';
import 'package:flutter/material.dart';

/// 取一个带 GlobalKey 的小部件在屏幕上的矩形
Rect? globalRectOf(GlobalKey key) {
  final ctx = key.currentContext;
  if (ctx == null) return null;
  final ro = ctx.findRenderObject();
  if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
  return ro.localToGlobal(Offset.zero) & ro.size;
}

/// 让一个小部件从 from 先快后慢地飞到 to，飞行中会往上拱一下、略微放大
void flyTo(
  BuildContext context, {
  required Rect from,
  required Rect to,
  required Widget child,
  Duration duration = const Duration(milliseconds: 560),
  VoidCallback? onDone,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    onDone?.call();
    return;
  }
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Fly(
      from: from,
      to: to,
      duration: duration,
      onEnd: () {
        entry.remove();
        onDone?.call();
      },
      child: child,
    ),
  );
  overlay.insert(entry);
}

class _Fly extends StatefulWidget {
  final Rect from;
  final Rect to;
  final Duration duration;
  final VoidCallback onEnd;
  final Widget child;
  const _Fly({
    required this.from,
    required this.to,
    required this.duration,
    required this.onEnd,
    required this.child,
  });

  @override
  State<_Fly> createState() => _FlyState();
}

class _FlyState extends State<_Fly> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _c.forward().whenComplete(widget.onEnd);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_c.value);
        final rect = Rect.lerp(widget.from, widget.to, t)!;
        final arc = -sin(pi * t) * 22;
        final pop = 1.0 + 0.10 * sin(pi * t);
        return Positioned(
          left: rect.left,
          top: rect.top + arc,
          width: rect.width,
          height: rect.height,
          child: IgnorePointer(
            child: Material(
              type: MaterialType.transparency,
              child: Transform.scale(
                scale: pop,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox.fromSize(size: widget.from.size, child: widget.child),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
