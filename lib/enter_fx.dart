import 'package:flutter/material.dart';
import 'ui.dart';

/// 点“开始”后：设置页先慢后快地滑出屏幕右侧（先轻轻往回收一下再冲出去）
class SlideAway extends StatefulWidget {
  final Widget child;
  const SlideAway({super.key, required this.child});

  @override
  State<SlideAway> createState() => SlideAwayState();
}

class SlideAwayState extends State<SlideAway> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 540));
  bool running = false;

  Future<void> run() async {
    if (running) return;
    setState(() => running = true);
    try {
      await _c.forward().orCancel;
    } catch (_) {}
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
      child: widget.child,
      builder: (context, ch) {
        final w = MediaQuery.sizeOf(context).width;
        final t = _c.value;
        final x = Curves.easeInBack.transform(t);
        final fade = 1.0 - Curves.easeIn.transform(((t - 0.3) / 0.7).clamp(0.0, 1.0));
        return IgnorePointer(
          ignoring: running,
          child: Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(w * 1.1 * x, 0),
              child: Transform.scale(scale: 1.0 - 0.05 * t, child: ch),
            ),
          ),
        );
      },
    );
  }
}

/// 设置页滑走之后：中间停一小会儿，棋盘从背景里渐渐浮现并微微放大到位（先快后慢）
Route<void> gameEnterRoute(Widget page) {
  return PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 1100),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, a, s) => AppBackdrop(child: page),
    transitionsBuilder: (context, a, s, child) {
      final fade = a.drive(
          CurveTween(curve: const Interval(0.2, 0.62, curve: Curves.easeOut)));
      final scale = a.drive(Tween<double>(begin: 0.93, end: 1.0)
          .chain(CurveTween(curve: const Interval(0.18, 1.0, curve: Curves.easeOutQuart))));
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(scale: scale, child: child),
      );
    },
  );
}

/// 页面里各个部分错开时间依次入场（跟随路由动画）
class Stagger extends StatelessWidget {
  final Animation<double> anim;
  final double begin;
  final double end;
  final Offset from;
  final Widget child;
  const Stagger({
    super.key,
    required this.anim,
    required this.begin,
    required this.end,
    required this.child,
    this.from = const Offset(0, 0.08),
  });

  @override
  Widget build(BuildContext context) {
    final t = anim.drive(
        CurveTween(curve: Interval(begin, end, curve: Curves.easeOutCubic)));
    return FadeTransition(
      opacity: t,
      child: SlideTransition(
        position: t.drive(Tween<Offset>(begin: from, end: Offset.zero)),
        child: child,
      ),
    );
  }
}
