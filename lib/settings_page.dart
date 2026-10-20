import 'dart:math';
import 'package:flutter/material.dart';
import 'fx.dart';
import 'settings.dart';
import 'strings.dart';
import 'ui.dart';
import 'extras.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Widget _sec(BuildContext context, String title, Widget child) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: styled(cs.surfaceContainerHigh, r: app.cardR),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(title), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _group(List<String> labels, List<IconData> icons, int cur, ValueChanged<int> set) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < labels.length; i++)
          LitToggle(
            wide: true,
            label: tr(labels[i]),
            icon: icons[i],
            value: cur == i,
            onChanged: (_) => set(i),
          ),
      ],
    );
  }

  Widget _preset(BuildContext context, Preset p) {
    final cs = Theme.of(context).colorScheme;
    final sel = app.presetId == p.id;
    return GestureDetector(
      onTap: () => animatedChange(context, () {
        app.presetId = p.id;
        app.custom.clear();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(min(app.cardR, 16.0)),
          border: Border.all(
              color: sel ? app.primary : cs.outline.withOpacity(0.4), width: sel ? 2.5 : 1),
          boxShadow:
              sel ? [BoxShadow(color: app.primary.withOpacity(0.5), blurRadius: 12)] : const [],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [for (final c in p.tiles) Expanded(child: Container(height: 22, color: c))],
              ),
            ),
            const SizedBox(height: 8),
            Text(tr(p.name), style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _colorRow(BuildContext context, String key, String label, Color c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(tr(label))),
          if (app.custom.containsKey(key))
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.restart_alt, size: 20),
              onPressed: () => app.change(() => app.custom.remove(key)),
            ),
          GestureDetector(
            onTap: () async {
              final had = app.custom[key];
              final v = await pickColorDialog(context, c,
                  onLive: (x) => app.change(() => app.custom[key] = x.toARGB32()));
              if (v == null) {
                app.change(() {
                  if (had == null) {
                    app.custom.remove(key);
                  } else {
                    app.custom[key] = had;
                  }
                });
              } else if (v == -1) {
                app.change(() => app.custom.remove(key));
              }
            },
            child: Container(
              width: 44,
              height: 30,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nav(BuildContext context, String title, String slot) {
    final has = app.layers[slot]?.path != null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(tr(title)),
      subtitle: Text(tr(has ? '已设置图片' : '未设置')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
          context, revealRoute(LayerEditorPage(slot: slot, title: title))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final cur = <String, Color>{
          'primary': app.primary,
          'bgTop': app.bgTop,
          'bgBottom': app.bgBottom,
          'boardBg': app.boardBg,
          'boardLine': app.boardLine,
          'red': app.red,
          'black': app.black,
        };
        const names = <String, String>{
          'primary': '主色（按钮 / 高亮）',
          'bgTop': '背景上部',
          'bgBottom': '背景下部',
          'boardBg': '棋盘底色',
          'boardLine': '棋盘线条',
          'red': '红方棋色',
          'black': '黑方棋色',
        };
        return Scaffold(
          appBar: AppBar(title: Text(tr('设置'))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _sec(context, '主题',
                  Wrap(spacing: 10, runSpacing: 10, children: [for (final p in app.presets) _preset(context, p)])),
              _sec(
                context,
                '显示模式',
                _group(const ['跟随系统', '浅色', '深色'],
                    const [Icons.brightness_auto, Icons.light_mode, Icons.dark_mode],
                    app.themeMode, (i) => animatedChange(context, () => app.themeMode = i)),
              ),
              _sec(
                context,
                '界面风格',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _group(
                        const ['圆润', '方正', '简洁', '立体'],
                        const [Icons.blur_circular, Icons.crop_square, Icons.horizontal_rule, Icons.layers],
                        app.uiStyle,
                        (i) => animatedChange(context, () => app.uiStyle = i)),
                    const SizedBox(height: 14),
                    Text(tr('开关按钮形状')),
                    const SizedBox(height: 8),
                    _group(const ['圆角', '方角'], const [Icons.circle, Icons.square],
                        app.toggleShape, (i) => app.change(() => app.toggleShape = i)),
                    const SizedBox(height: 14),
                    Text(tr('效果预览')),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        LitButton(icon: Icons.undo, label: tr('按钮'), onTap: () {}),
                        LitToggle(icon: Icons.rule, label: tr('亮起'), value: true, onChanged: (_) {}),
                        LitToggle(icon: Icons.rule, label: tr('熄灭'), value: false, onChanged: (_) {}),
                      ],
                    ),
                  ],
                ),
              ),
              _sec(
                context,
                '动画',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('动画手感')),
                    const SizedBox(height: 8),
                    _group(
                        const ['关闭', '高效', '舒适', '液态Q弹'],
                        const [Icons.block, Icons.bolt, Icons.spa, Icons.bubble_chart],
                        app.animLevel,
                        (i) => app.change(() => app.animLevel = i)),
                    const SizedBox(height: 14),
                    Text(tr('切换动画')),
                    const SizedBox(height: 8),
                    _group(
                        const ['圆形扩散', '渐变', '无'],
                        const [Icons.radio_button_checked, Icons.blur_on, Icons.block],
                        app.fxMode,
                        (i) => app.change(() => app.fxMode = i)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        LitToggle(
                            wide: true,
                            icon: Icons.water_drop,
                            label: tr('液态玻璃质感'),
                            value: app.glass,
                            onChanged: (v) => app.change(() => app.glass = v)),
                        LitToggle(
                            wide: true,
                            icon: Icons.landscape,
                            label: tr('主题装饰图案'),
                            value: app.decor,
                            onChanged: (v) => app.change(() => app.decor = v)),
                      ],
                    ),
                  ],
                ),
              ),
              _sec(
                context,
                '语言',
                _group(const ['中文', 'English', '日本語', 'Русский'],
                    const [Icons.translate, Icons.translate, Icons.translate, Icons.translate],
                    app.lang, (i) => app.change(() => app.lang = i)),
              ),
              _sec(
                context,
                '自定义颜色',
                Column(
                  children: [
                    for (final e in names.entries) _colorRow(context, e.key, e.value, cur[e.key]!),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => app.change(() => app.custom.clear()),
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: Text(tr('全部恢复默认')),
                      ),
                    ),
                  ],
                ),
              ),
              _sec(
                context,
                '自定义图片',
                Column(
                  children: [
                    _nav(context, '全局背景', 'global'),
                    _nav(context, '主菜单图片', 'home'),
                    _nav(context, '对局页图片', 'game'),
                  ],
                ),
              ),
              const ExtrasSections(),
              _sec(
                context,
                '关于',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('作者：Teshoul（刘小壮）')),
                    const SizedBox(height: 6),
                    Text(tr('本应用由 Claude 辅助创作')),
                    const SizedBox(height: 6),
                    Text(tr('开源仓库： https://github.com/Teshoul/Divine-Chinese-Chess')),
                    const SizedBox(height: 6),
                    Text('${tr('版本')} 1.5.0'),
                    const SizedBox(height: 6),
                    Text('${tr('存储状态')}：${app.storageStatus}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Z {
  final String label;
  final double l, t, w, h;
  const _Z(this.label, this.l, this.t, this.w, this.h);
}

List<_Z> _zones(String slot) {
  if (slot == 'home') {
    return const [
      _Z('头像', 0.04, 0.03, 0.14, 0.06),
      _Z('标题', 0.3, 0.07, 0.4, 0.09),
      _Z('四宫格', 0.05, 0.29, 0.9, 0.42),
      _Z('设置按钮', 0.80, 0.905, 0.15, 0.07),
    ];
  }
  if (slot == 'game') {
    return const [
      _Z('标题栏', 0.0, 0.03, 1.0, 0.07),
      _Z('状态栏', 0.15, 0.10, 0.7, 0.09),
      _Z('棋盘', 0.02, 0.20, 0.96, 0.60),
      _Z('按钮栏', 0.0, 0.86, 1.0, 0.09),
    ];
  }
  return const [];
}

class _ZonePainter extends CustomPainter {
  final List<_Z> zones;
  _ZonePainter(this.zones);

  @override
  void paint(Canvas canvas, Size s) {
    for (final z in zones) {
      final r = Rect.fromLTWH(z.l * s.width, z.t * s.height, z.w * s.width, z.h * s.height);
      canvas.drawRect(r, Paint()..color = Colors.red.withOpacity(0.18));
      canvas.save();
      canvas.clipRect(r);
      final lp = Paint()
        ..color = Colors.red.withOpacity(0.55)
        ..strokeWidth = 1.2;
      for (double x = r.left - r.height; x < r.right; x += 8) {
        canvas.drawLine(Offset(x, r.bottom), Offset(x + r.height, r.top), lp);
      }
      canvas.restore();
      canvas.drawRect(
          r,
          Paint()
            ..color = Colors.red
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
      final tp = TextPainter(
        text: TextSpan(
          text: tr(z.label),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              backgroundColor: Color(0xCCD32F2F)),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r.width);
      tp.paint(canvas, r.topLeft + const Offset(2, 2));
    }
  }

  @override
  bool shouldRepaint(covariant _ZonePainter old) => true;
}

class LayerEditorPage extends StatefulWidget {
  final String slot;
  final String title;
  const LayerEditorPage({super.key, required this.slot, required this.title});
  @override
  State<LayerEditorPage> createState() => _LayerEditorPageState();
}

class _LayerEditorPageState extends State<LayerEditorPage> {
  ImgLayer get l => app.layers[widget.slot]!;
  bool showZones = true;
  double _s0 = 1, _r0 = 0;

  Widget _s(String label, double v, double lo, double hi, void Function(double) set) {
    final x = max(lo, min(hi, v));
    return Row(
      children: [
        SizedBox(width: 84, child: Text(tr(label))),
        Expanded(
          child: Slider(
            value: x,
            min: lo,
            max: hi,
            onChanged: (nv) => setState(() => set(nv)),
            onChangeEnd: (_) => app.change(() {}),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final zones = _zones(widget.slot);
    final pw = min(240.0, MediaQuery.sizeOf(context).width * 0.62);
    final ph = pw * 2.05;
    return Scaffold(
      appBar: AppBar(title: Text(tr(widget.title))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: Container(
              width: pw,
              height: ph,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outline, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (d) {
                    _s0 = l.scale;
                    _r0 = l.rot;
                  },
                  onScaleUpdate: (d) => setState(() {
                    l.dx = (l.dx + d.focalPointDelta.dx / pw).clamp(-1.0, 1.0).toDouble();
                    l.dy = (l.dy + d.focalPointDelta.dy / ph).clamp(-1.0, 1.0).toDouble();
                    if (d.pointerCount >= 2) {
                      l.scale = (_s0 * d.scale).clamp(0.3, 3.0).toDouble();
                      var r = _r0 + d.rotation * 180 / pi;
                      while (r > 180) {
                        r -= 360;
                      }
                      while (r < -180) {
                        r += 360;
                      }
                      l.rot = r;
                    }
                  }),
                  onScaleEnd: (_) => app.change(() {}),
                  child: Stack(
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
                      ImageSlot(slot: widget.slot),
                      if (showZones)
                        IgnorePointer(child: CustomPaint(painter: _ZonePainter(zones))),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.slot == 'global'
                ? tr('全局背景铺在所有页面最下方，页面内容会盖在它上面。')
                : tr('红色斜纹区域会被界面元素遮挡'),
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          Text(tr('单指拖动移动，双指缩放 / 旋转'),
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () async {
                  final p = await pickImage();
                  if (p != null) app.change(() => l.path = p);
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.image),
                label: Text(tr('选择图片')),
              ),
              OutlinedButton(
                onPressed: () {
                  app.change(() => l.path = null);
                  setState(() {});
                },
                child: Text(tr('移除图片')),
              ),
              OutlinedButton(
                onPressed: () {
                  app.change(() => l.resetTransform());
                  setState(() {});
                },
                child: Text(tr('重置变换')),
              ),
              if (zones.isNotEmpty)
                LitToggle(
                  wide: true,
                  icon: Icons.grid_4x4,
                  label: tr('显示遮挡区域'),
                  value: showZones,
                  onChanged: (v) => setState(() => showZones = v),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _s('缩放', l.scale, 0.3, 3.0, (v) => l.scale = v),
          _s('水平位置', l.dx, -1.0, 1.0, (v) => l.dx = v),
          _s('垂直位置', l.dy, -1.0, 1.0, (v) => l.dy = v),
          _s('旋转', l.rot, -180.0, 180.0, (v) => l.rot = v),
          _s('水平扭曲', l.skewX, -0.8, 0.8, (v) => l.skewX = v),
          _s('垂直扭曲', l.skewY, -0.8, 0.8, (v) => l.skewY = v),
          _s('透明度', l.opacity, 0.0, 1.0, (v) => l.opacity = v),
          _s('模糊', l.blur, 0.0, 20.0, (v) => l.blur = v),
        ],
      ),
    );
  }
}
