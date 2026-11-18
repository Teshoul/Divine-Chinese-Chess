import 'dart:io';
import 'package:flutter/material.dart';
import 'ai_ui.dart';
import 'fly.dart';
import 'glitch.dart';
import 'settings.dart';

/// 头像缩略图（头像库、飞行动画、确认弹窗共用）
Widget avatarThumb(String p,
    {double size = 56, bool selected = false, bool lifted = false}) {
  final Widget img = p == kStarAvatar
      ? const StarAvatarFill()
      : Image.file(
          File(p),
          fit: BoxFit.cover,
          cacheWidth: 200,
          errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
        );
  final r = size * 0.18;
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(r),
      border: Border.all(
        color: selected ? app.primary : Colors.white.withOpacity(0.28),
        width: selected ? 3 : 1,
      ),
      boxShadow: lifted
          ? const [BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 6))]
          : const [],
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(max0(r - 1)), child: img),
  );
}

double max0(double v) => v < 0 ? 0 : v;

Color _contrast(Color face) =>
    ThemeData.estimateBrightnessForColor(face) == Brightness.dark ? Colors.white : Colors.black87;

/// 头像库：点按钮像抽屉一样拉出来；长按拖动可调整顺序；拖进垃圾桶可删除（会二次确认）；
/// 点一个头像，它会先快后慢地飞到当前头像的位置完成切换。
class AvatarDrawer extends StatefulWidget {
  final GlobalKey avatarKey;
  final VoidCallback onChanged;
  const AvatarDrawer({super.key, required this.avatarKey, required this.onChanged});

  @override
  State<AvatarDrawer> createState() => _AvatarDrawerState();
}

class _AvatarDrawerState extends State<AvatarDrawer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
    reverseDuration: const Duration(milliseconds: 380),
  );
  late final Animation<double> _sf =
      CurvedAnimation(parent: _c, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: const Interval(0.15, 1.0, curve: Curves.easeOut));
  bool _open = false;
  bool _dragging = false;
  String? _hidden;
  final Map<String, GlobalKey> _keys = <String, GlobalKey>{};

  GlobalKey _k(String p) => _keys.putIfAbsent(p, () => GlobalKey());

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  void _pick(String p) {
    if (app.avatar == p || _hidden != null) return;
    final from = globalRectOf(_k(p));
    final to = globalRectOf(widget.avatarKey);
    if (from == null || to == null) {
      app.touchAvatar(() => app.avatar = p);
      setState(() {});
      widget.onChanged();
      return;
    }
    setState(() => _hidden = p);
    flyTo(
      context,
      from: from,
      to: to,
      child: avatarThumb(p, size: from.width),
      onDone: () {
        app.touchAvatar(() => app.avatar = p);
        if (mounted) setState(() => _hidden = null);
        widget.onChanged();
      },
    );
  }

  void _reorder(String a, String b) {
    final i = app.avatars.indexOf(a);
    final j = app.avatars.indexOf(b);
    if (i < 0 || j < 0 || i == j) return;
    app.touchAvatar(() {
      final it = app.avatars.removeAt(i);
      app.avatars.insert(j, it);
    });
    setState(() {});
    widget.onChanged();
  }

  Future<void> _add() async {
    final p = await pickImage();
    if (p == null) return;
    app.touchAvatar(() {
      if (!app.avatars.contains(p)) app.avatars.add(p);
      app.avatar = p;
    });
    if (mounted) setState(() {});
    widget.onChanged();
  }

  Future<void> _confirmDelete(String p) async {
    if (p == kStarAvatar) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        const bold = TextStyle(fontWeight: FontWeight.w800, fontSize: 15);
        return AlertDialog(
          title: Text(tx('删除头像')),
          content: Row(
            children: [
              avatarThumb(p, size: 52),
              const SizedBox(width: 14),
              Expanded(child: Text(tx('确定要从头像库删除这张头像吗？删除后无法恢复。'))),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: 110,
              child: ChunkyButton(
                selected: false,
                onTap: () => Navigator.pop(ctx, false),
                face: cs.surfaceContainerHighest,
                faceOn: cs.surfaceContainerHighest,
                glow: cs.outline,
                height: 44,
                radius: 12,
                depth: 4,
                child: Text(tx('取消'), style: bold.copyWith(color: cs.onSurface)),
              ),
            ),
            SizedBox(
              width: 110,
              child: ChunkyButton(
                selected: false,
                onTap: () => Navigator.pop(ctx, true),
                face: const Color(0xFFB71C1C),
                faceOn: const Color(0xFFB71C1C),
                glow: Colors.redAccent,
                height: 44,
                radius: 12,
                depth: 4,
                haptic: 2,
                child: Text(tx('删除'), style: bold.copyWith(color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    app.touchAvatar(() {
      app.avatars.remove(p);
      if (app.avatar == p) app.avatar = null;
    });
    try {
      File(p).deleteSync();
    } catch (_) {}
    _keys.remove(p);
    if (mounted) setState(() {});
    widget.onChanged();
  }

  Widget _tile(String p, {bool fixed = false}) {
    final sel = app.avatar == p;
    final visual = AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: _hidden == p ? 0.0 : 1.0,
      child: avatarThumb(p, size: 56, selected: sel),
    );
    final core = KeyedSubtree(
      key: _k(p),
      child: GestureDetector(onTap: () => _pick(p), child: visual),
    );
    if (fixed) return core;
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != p,
      onAcceptWithDetails: (d) => _reorder(d.data, p),
      builder: (ctx, cand, rej) {
        final hot = cand.isNotEmpty;
        return AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          scale: hot ? 1.16 : 1.0,
          child: LongPressDraggable<String>(
            data: p,
            delay: const Duration(milliseconds: 260),
            onDragStarted: () => setState(() => _dragging = true),
            onDragEnd: (_) {
              if (mounted) setState(() => _dragging = false);
            },
            feedback: Material(
              type: MaterialType.transparency,
              child: Transform.scale(
                scale: 1.18,
                child: avatarThumb(p, size: 56, selected: true, lifted: true),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.25, child: avatarThumb(p, size: 56)),
            child: core,
          ),
        );
      },
    );
  }

  Widget _trash(ColorScheme cs) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => true,
      onAcceptWithDetails: (d) => _confirmDelete(d.data),
      builder: (ctx, cand, rej) {
        final hot = cand.isNotEmpty;
        return AnimatedScale(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          scale: hot ? 1.3 : (_dragging ? 1.12 : 1.0),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: (_dragging || hot) ? 1.0 : 0.55,
            child: ChunkyButton(
              selected: hot,
              onTap: () {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(content: Text(tx('把头像拖到这里可以删除'))),
                );
              },
              face: cs.surfaceContainerHighest,
              faceOn: const Color(0xFF5A0F0F),
              glow: Colors.redAccent,
              height: 34,
              radius: 11,
              depth: 4,
              child: Icon(
                hot ? Icons.delete_forever : Icons.delete_outline,
                size: 20,
                color: hot ? const Color(0xFFFF5252) : cs.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _addTile(ColorScheme cs) {
    return SizedBox(
      width: 56,
      child: ChunkyButton(
        selected: false,
        onTap: _add,
        face: cs.surfaceContainerHighest,
        faceOn: cs.surfaceContainerHighest,
        glow: app.primary,
        height: 52,
        radius: 10,
        depth: 4,
        child: Icon(Icons.add, color: cs.onSurfaceVariant),
      ),
    );
  }

  Widget _body(ColorScheme cs) {
    final items = <Widget>[];
    if (app.owns('avatar_star')) items.add(_tile(kStarAvatar, fixed: true));
    for (final p in List<String>.from(app.avatars)) {
      items.add(_tile(p));
    }
    items.add(_addTile(cs));
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.surfaceContainerHighest.withOpacity(0.45),
        border: Border.all(color: cs.outline.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tx('长按拖动可调整顺序，拖到右上角的垃圾桶可删除'),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 46, child: _trash(cs)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 10, children: items),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = app.avatars.length + (app.owns('avatar_star') ? 1 : 0);
    final faceOn = Color.lerp(cs.surfaceContainerHighest, app.primary, 0.55)!;
    final ink = _open ? _contrast(faceOn) : cs.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChunkyButton(
          selected: _open,
          onTap: _toggle,
          face: cs.surfaceContainerHighest,
          faceOn: faceOn,
          glow: app.primary,
          height: 46,
          radius: 14,
          depth: 5,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library, size: 20, color: ink),
              const SizedBox(width: 8),
              Text('${tx('头像库')}  ($count)',
                  style: TextStyle(fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutBack,
                child: Icon(Icons.keyboard_arrow_down, color: ink),
              ),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            if (_c.isDismissed) return const SizedBox(width: double.infinity);
            return SizeTransition(
              sizeFactor: _sf,
              axisAlignment: -1,
              child: FadeTransition(opacity: _fade, child: _body(cs)),
            );
          },
        ),
      ],
    );
  }
}
