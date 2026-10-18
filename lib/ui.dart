import 'dart:io';
import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'engine.dart';
import 'settings.dart';

Route<void> fadeRoute(Widget page) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondary) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// 新页面带弹性弹出（配合主页的“灵魂出窍”）
Route<void> soulRoute(Widget page) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, a, s) => page,
    transitionsBuilder: (context, a, s, child) {
      final pop = CurvedAnimation(
        parent: a,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOutBack),
        reverseCurve: Curves.easeInCubic,
      );
      final fade = CurvedAnimation(
        parent: a,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      );
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(pop),
          child: child,
        ),
      );
    },
  );
}

class Reveal extends StatelessWidget {
  final Animation<double> parent;
  final int index;
  final Widget child;
  const Reveal({super.key, required this.parent, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final start = min(index * 0.12, 0.6);
    final a = CurvedAnimation(
        parent: parent,
        curve: Interval(start, min(start + 0.4, 1.0), curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }
}

/// 按界面风格生成的盒子样式
BoxDecoration styled(Color color, {double? r, bool pressed = false}) {
  final radius = BorderRadius.circular(r ?? app.cardR);
  switch (app.uiStyle) {
    case 1:
      return BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.4),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.35),
              offset: Offset(pressed ? 1 : 4, pressed ? 1 : 4)),
        ],
      );
    case 2:
      final bd = Color.lerp(color, app.isDark ? Colors.white : Colors.black, 0.35)!;
      return BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: radius,
        border: Border.all(color: bd, width: 1.4),
      );
    case 3:
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.22)!, color],
        ),
        borderRadius: radius,
        border: Border.all(color: Colors.white.withOpacity(0.28), width: 1),
        boxShadow: [
          BoxShadow(
              color: Color.lerp(color, Colors.black, 0.45)!,
              offset: Offset(0, pressed ? 2 : 6)),
          BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 12,
              offset: Offset(0, pressed ? 4 : 10)),
        ],
      );
    default:
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.72)],
        ),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      );
  }
}

Color inkOn(Color c) => app.uiStyle == 2 ? c : Colors.white;
Color inkSub(Color c) =>
    app.uiStyle == 2 ? (app.isDark ? Colors.white70 : Colors.black54) : Colors.white70;

class PressCard extends StatefulWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback? onTap;
  const PressCard({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.sub,
    this.onTap,
  });

  @override
  State<PressCard> createState() => _PressCardState();
}

class _PressCardState extends State<PressCard> {
  bool down = false;

  @override
  Widget build(BuildContext context) {
    final ink = inkOn(widget.color);
    return GestureDetector(
      onTapDown: (_) => setState(() => down = true),
      onTapCancel: () => setState(() => down = false),
      onTapUp: (_) => setState(() => down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: styled(widget.color, pressed: down),
          child: Row(
            children: [
              Icon(widget.icon, color: ink, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: TextStyle(
                            color: ink, fontSize: 19, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(widget.sub,
                        style: TextStyle(color: inkSub(widget.color), fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: inkSub(widget.color)),
            ],
          ),
        ),
      ),
    );
  }
}

Widget sideTag(BuildContext context, Side s, {required bool active, bool mine = false}) {
  final isRed = s == Side.red;
  final col = isRed ? app.red : const Color(0xFF1B1B1B);
  final cs = Theme.of(context).colorScheme;
  final dark = app.isDark;
  final txt = active
      ? Colors.white
      : (isRed ? (dark ? Color.lerp(app.red, Colors.white, 0.4)! : app.red) : cs.onSurface);
  final border = isRed
      ? app.red.withOpacity(active ? 1 : 0.5)
      : (dark ? Colors.white.withOpacity(active ? 0.9 : 0.5) : Colors.black.withOpacity(active ? 1 : 0.5));
  return AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: active ? col : col.withOpacity(0.08),
      borderRadius: BorderRadius.circular(app.toggleShape == 0 ? 20 : 8),
      border: Border.all(color: border, width: 1.4),
    ),
    child: Text('${s.cn}${mine ? '（你）' : ''}',
        style: TextStyle(color: txt, fontWeight: FontWeight.w600)),
  );
}

/// 点击按钮（有按下动画）
class LitButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const LitButton({super.key, required this.icon, required this.label, this.onTap});

  @override
  State<LitButton> createState() => _LitButtonState();
}

class _LitButtonState extends State<LitButton> {
  bool down = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = widget.onTap != null;
    final base = cs.secondaryContainer;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => down = true) : null,
        onTapUp: enabled ? (_) => setState(() => down = false) : null,
        onTapCancel: enabled ? () => setState(() => down = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: down ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: 68,
            height: 56,
            decoration: styled(base, r: app.btnR, pressed: down),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 22, color: cs.onSecondaryContainer),
                const SizedBox(height: 2),
                Text(widget.label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.onSecondaryContainer)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 开关按钮：点一下亮起，再点一下熄灭
class LitToggle extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool wide;
  const LitToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final round = app.toggleShape == 0;
    final radius = BorderRadius.circular(round ? (wide ? 26 : 22) : 8);
    final onFill = app.primary.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    final ink = value ? onFill : cs.onSurfaceVariant;
    final deco = value
        ? BoxDecoration(
            color: app.primary,
            borderRadius: radius,
            border: Border.all(color: Colors.white.withOpacity(0.55), width: 1),
            boxShadow: [
              BoxShadow(color: app.primary.withOpacity(0.6), blurRadius: 14, spreadRadius: 1),
            ],
          )
        : BoxDecoration(
            color: cs.onSurface.withOpacity(0.05),
            borderRadius: radius,
            border: Border.all(color: cs.outline.withOpacity(0.55), width: 1.2),
          );
    final Widget content = wide
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) Icon(icon, size: 20, color: ink),
              if (icon != null) const SizedBox(width: 8),
              Text(label, style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) Icon(icon, size: 22, color: ink),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(fontSize: 11, color: ink, fontWeight: FontWeight.w600)),
            ],
          );
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: wide ? null : 68,
        height: wide ? null : 56,
        padding: wide
            ? const EdgeInsets.symmetric(horizontal: 18, vertical: 12)
            : EdgeInsets.zero,
        decoration: deco,
        child: content,
      ),
    );
  }
}

/// 固定高度的底部按钮栏，按钮多了横向滑动，不会挤动棋盘
class ActionBar extends StatelessWidget {
  final List<Widget> children;
  const ActionBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: LayoutBuilder(
        builder: (context, cons) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: max(0.0, cons.maxWidth - 24)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (final c in children)
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 自定义图片层：缩放、位置、旋转、扭曲、透明度、模糊
class ImageSlot extends StatelessWidget {
  final String slot;
  const ImageSlot({super.key, required this.slot});

  @override
  Widget build(BuildContext context) {
    final l = app.layers[slot];
    final p = l?.path;
    if (l == null || p == null) return const SizedBox.shrink();
    final file = File(p);
    if (!file.existsSync()) return const SizedBox.shrink();
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          final co = cos(l.rot * pi / 180), si = sin(l.rot * pi / 180);
          final a11 = l.scale * (co - si * l.skewY);
          final a12 = l.scale * (co * l.skewX - si);
          final a21 = l.scale * (si + co * l.skewY);
          final a22 = l.scale * (si * l.skewX + co);
          Widget img = Image.file(
            file,
            fit: BoxFit.cover,
            width: w,
            height: h,
            errorBuilder: (ctx, e, s) => const SizedBox.shrink(),
          );
          if (l.blur > 0.1) {
            img = ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: l.blur, sigmaY: l.blur),
              child: img,
            );
          }
          final m = Matrix4(a11, a21, 0, 0, a12, a22, 0, 0, 0, 0, 1, 0, l.dx * w, l.dy * h, 0, 1);
          return ClipRect(
            child: Opacity(
              opacity: l.opacity,
              child: Transform(alignment: Alignment.center, transform: m, child: img),
            ),
          );
        },
      ),
    );
  }
}

/// 全局背景：渐变 + 全局图片
class AppBackdrop extends StatelessWidget {
  final Widget child;
  const AppBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    app.sysB = MediaQuery.platformBrightnessOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [app.bgTop, app.bgBottom],
            ),
          ),
        ),
        const ImageSlot(slot: 'global'),
        child,
      ],
    );
  }
}

/// 取色对话框：返回颜色值；-1 表示恢复默认；null 表示取消
Future<int?> pickColorDialog(BuildContext context, Color init) {
  var hsv = HSVColor.fromColor(init);
  const swatches = <Color>[
    Color(0xFFC62828), Color(0xFFEF6C00), Color(0xFFF9A825), Color(0xFF2E7D32),
    Color(0xFF00897B), Color(0xFF1565C0), Color(0xFF5E35B1), Color(0xFFAD1457),
    Color(0xFF212121), Color(0xFF757575), Color(0xFFEEEEEE), Color(0xFFFFFFFF),
  ];
  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final c = hsv.toColor();
        Widget row(String label, double v, double lo, double hi, ValueChanged<double> f) {
          return Row(
            children: [
              SizedBox(width: 44, child: Text(label)),
              Expanded(child: Slider(value: v, min: lo, max: hi, onChanged: f)),
            ],
          );
        }

        return AlertDialog(
          title: const Text('选择颜色'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 8),
                row('色相', hsv.hue, 0, 360, (v) => setS(() => hsv = hsv.withHue(v))),
                row('饱和', hsv.saturation, 0, 1, (v) => setS(() => hsv = hsv.withSaturation(v))),
                row('明暗', hsv.value, 0, 1, (v) => setS(() => hsv = hsv.withValue(v))),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in swatches)
                      GestureDetector(
                        onTap: () => setS(() => hsv = HSVColor.fromColor(s)),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: s,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, -1), child: const Text('恢复默认')),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.toARGB32()),
              child: const Text('确定'),
            ),
          ],
        );
      },
    ),
  );
}
