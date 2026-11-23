import 'dart:math';
import 'package:flutter/material.dart';
import 'avatar_model.dart';
import 'img_util.dart';
import 'settings.dart';

/// 按编辑数据实时画出头像（图片本身不被改动，所以动图照常播放）
class AvatarView extends StatelessWidget {
  final String path;
  final AvatarEdit edit;
  final bool showOutside; // 编辑器里把框外的部分半透明地显示出来
  final GlobalKey? boundaryKey; // 用来截取静态快照
  final int? selected; // 被选中的贴图（显示选框）
  final double radiusFrac; // 圆角占边长的比例，0 = 直角
  final int cache;
  const AvatarView({
    super.key,
    required this.path,
    required this.edit,
    this.showOutside = false,
    this.boundaryKey,
    this.selected,
    this.radiusFrac = 0,
    this.cache = 700,
  });

  Widget _base(double s) {
    Widget w = SizedBox(
      width: s,
      height: s,
      child: imageFileWidget(path, fit: BoxFit.contain, width: s, height: s, cacheWidth: cache),
    );
    w = Transform(transform: edit.baseMatrix(s), child: w);
    final cf = edit.colorFilter();
    if (cf != null) w = ColorFiltered(colorFilter: cf, child: w);
    return w;
  }

  Widget _itemBox(AvatarItem it, double s, Widget child) {
    final sz = s * 0.26 * it.scale;
    final bw = it.kind == 'text' ? sz * 3 : sz;
    return Positioned(
      left: it.x * s - bw / 2,
      top: it.y * s - sz / 2,
      width: bw,
      height: sz,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..rotateZ(it.rot * pi / 180)
          ..scale(it.flip ? -1.0 : 1.0, 1.0, 1.0),
        child: child,
      ),
    );
  }

  List<Widget> _items(double s) {
    final out = <Widget>[];
    for (final it in edit.items) {
      final Widget child;
      switch (it.kind) {
        case 'sticker':
          child = imageFileWidget(it.id, fit: BoxFit.contain, cacheWidth: 500);
          break;
        case 'text':
          final c = Color(it.color);
          child = FittedBox(
            fit: BoxFit.contain,
            child: Text(
              it.id,
              maxLines: 1,
              style: TextStyle(
                color: c,
                fontWeight: FontWeight.w900,
                height: 1.1,
                shadows: [
                  Shadow(
                    color: c.computeLuminance() > 0.5 ? Colors.black54 : Colors.white54,
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          );
          break;
        default:
          child = CustomPaint(painter: ShapePainter(it.id, Color(it.color)));
      }
      out.add(_itemBox(it, s, child));
    }
    return out;
  }

  Widget _content(double s) {
    final composite = SizedBox(
      width: s,
      height: s,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          _base(s),
          if (edit.strokes.isNotEmpty)
            Positioned.fill(child: CustomPaint(painter: StrokePainter(edit.strokes))),
          ..._items(s),
        ],
      ),
    );
    Widget framed = RepaintBoundary(key: boundaryKey, child: ClipRect(child: composite));
    if (radiusFrac > 0) {
      framed = ClipRRect(borderRadius: BorderRadius.circular(s * radiusFrac), child: framed);
    }
    final sel = selected;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (showOutside)
          Positioned(
            left: 0,
            top: 0,
            width: s,
            height: s,
            child: IgnorePointer(child: Opacity(opacity: 0.38, child: _base(s))),
          ),
        Positioned.fill(child: framed),
        if (sel != null && sel >= 0 && sel < edit.items.length)
          _itemBox(
            edit.items[sel],
            s,
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF00E5FF), width: 1.6),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      var s = min(c.maxWidth, c.maxHeight);
      if (!s.isFinite || s <= 0) s = 100;
      return SizedBox(width: s, height: s, child: _content(s));
    });
  }
}

/// 头像库 / 个人主页 / 对局头像框统一用这个：有编辑数据就按编辑后的样子显示，没有就居中铺满
class AvatarImage extends StatelessWidget {
  final String path;
  final int cache;
  const AvatarImage({super.key, required this.path, this.cache = 300});

  @override
  Widget build(BuildContext context) {
    final e = app.editOf(path);
    if (e == null) {
      return imageFileWidget(path, fit: BoxFit.cover, cacheWidth: cache);
    }
    return AvatarView(path: path, edit: e, cache: max(cache * 2, 600));
  }
}
