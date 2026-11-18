import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'sfx.dart';
import 'ui.dart';

/// 方块按钮的展开转场：
/// 向左/向右极快拉出 → 略微停顿 → 极快从底部拉满到屏幕顶 → 中速扩大到全屏。
/// 返回时是它的倒放；按钮留在原位，图标 Q 弹地变成 X，再点一下就关闭。
Route<void> squareExpandRoute({
  required Widget page,
  required Rect origin,
  required bool rightward,
  required Color color,
  required IconData icon,
  Color iconColor = Colors.white,
}) {
  return PageRouteBuilder<void>(
    opaque: false,
    transitionDuration: const Duration(milliseconds: 1350),
    reverseTransitionDuration: const Duration(milliseconds: 1000),
    pageBuilder: (context, a, s) => AppBackdrop(child: page),
    transitionsBuilder: (context, a, s, child) => _ExpandStage(
      anim: a,
      origin: origin,
      rightward: rightward,
      color: color,
      icon: icon,
      iconColor: iconColor,
      page: child,
    ),
  );
}

class _RRectClipper extends CustomClipper<Path> {
  final Rect rect;
  final double radius;
  _RRectClipper(this.rect, this.radius);

  @override
  Path getClip(Size size) =>
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

  @override
  bool shouldReclip(_RRectClipper old) => old.rect != rect || old.radius != radius;
}

class _ExpandStage extends StatelessWidget {
  final Animation<double> anim;
  final Rect origin;
  final bool rightward;
  final Color color;
  final IconData icon;
  final Color iconColor;
  final Widget page;
  const _ExpandStage({
    required this.anim,
    required this.origin,
    required this.rightward,
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.page,
  });

  Rect _rect(double u, Size sc) {
    final o = origin;
    final w = sc.width;
    final h = sc.height;
    final w1 = w * 0.58;
    double eb(double x) => Curves.easeOutBack.transform(x.clamp(0.0, 1.0));
    final ua = eb(u / 0.16);
    final uc = eb((u - 0.24) / 0.16);
    final ud = Curves.easeInOutCubic.transform(((u - 0.40) / 0.60).clamp(0.0, 1.0));
    final wA = lerpDouble(o.width, w1, ua)!;
    double left;
    double right;
    if (rightward) {
      left = o.left;
      right = left + wA;
    } else {
      right = o.right;
      left = right - wA;
    }
    left = lerpDouble(left, 0, ud)!;
    right = lerpDouble(right, w, ud)!;
    final top = lerpDouble(o.top, 0, uc)!;
    final bottom = lerpDouble(o.bottom, h, uc)!;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  Widget build(BuildContext context) {
    final sc = MediaQuery.sizeOf(context);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final u = anim.value;
        final rect = _rect(u, sc);
        final ud = Curves.easeInOutCubic.transform(((u - 0.40) / 0.60).clamp(0.0, 1.0));
        final radius = lerpDouble(14, 0, Curves.easeIn.transform(ud))!;
        final pageT = Curves.easeIn.transform(((u - 0.62) / 0.38).clamp(0.0, 1.0));
        final m = Curves.elasticOut.transform(((u - 0.60) / 0.34).clamp(0.0, 1.0));
        final dark = Color.lerp(color, Colors.black, 0.35)!;
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipPath(
              clipper: _RRectClipper(rect, radius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color, dark],
                      ),
                    ),
                  ),
                  IgnorePointer(
                    ignoring: pageT < 0.95,
                    child: Opacity(opacity: pageT, child: page),
                  ),
                ],
              ),
            ),
            Positioned.fromRect(
              rect: origin,
              child: _MorphButton(
                m: m,
                color: color,
                icon: icon,
                iconColor: iconColor,
                onTap: () {
                  if (anim.status == AnimationStatus.completed) {
                    Sfx.I.click();
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 留在原位的方块按钮：图标 Q 弹地变成 X
class _MorphButton extends StatelessWidget {
  final double m;
  final Color color;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  const _MorphButton({
    required this.m,
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final a = (1 - m).clamp(0.0, 1.0).toDouble();
    final x = m.clamp(0.0, 1.0).toDouble();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(color, Colors.white, 0.16)!, color],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.28), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.30),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: a,
              child: Transform.rotate(
                angle: m * pi / 2,
                child: Icon(icon, color: iconColor, size: 28),
              ),
            ),
            Opacity(
              opacity: x,
              child: Transform.rotate(
                angle: (m - 1) * pi / 2,
                child: Transform.scale(
                  scale: 0.5 + 0.5 * m,
                  child: Icon(Icons.close, color: iconColor, size: 30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
