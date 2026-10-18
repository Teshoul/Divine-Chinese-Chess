import 'dart:math';
import 'package:flutter/material.dart';
import 'settings.dart';
import 'ui.dart';

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
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _preset(BuildContext context, Preset p) {
    final cs = Theme.of(context).colorScheme;
    final sel = app.presetId == p.id;
    return GestureDetector(
      onTap: () => app.change(() {
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
            color: sel ? app.primary : cs.outline.withOpacity(0.4),
            width: sel ? 2.5 : 1,
          ),
          boxShadow: sel
              ? [BoxShadow(color: app.primary.withOpacity(0.5), blurRadius: 12)]
              : const [],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  for (final c in p.tiles) Expanded(child: Container(height: 22, color: c)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
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
          Expanded(child: Text(label)),
          if (app.custom.containsKey(key))
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '恢复默认',
              icon: const Icon(Icons.restart_alt, size: 20),
              onPressed: () => app.change(() => app.custom.remove(key)),
            ),
          GestureDetector(
            onTap: () async {
              final v = await pickColorDialog(context, c);
              if (v == null) return;
              app.change(() {
                if (v == -1) {
                  app.custom.remove(key);
                } else {
                  app.custom[key] = v;
                }
              });
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
      title: Text(title),
      subtitle: Text(has ? '已设置图片' : '未设置'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        fadeRoute(LayerEditorPage(slot: slot, title: title)),
      ),
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
          appBar: AppBar(title: const Text('设置')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _sec(
                context,
                '主题',
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [for (final p in kPresets) _preset(context, p)],
                ),
              ),
              _sec(
                context,
                '显示模式',
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < 3; i++)
                      LitToggle(
                        wide: true,
                        label: const ['跟随系统', '浅色', '深色'][i],
                        icon: const [
                          Icons.brightness_auto,
                          Icons.light_mode,
                          Icons.dark_mode
                        ][i],
                        value: app.themeMode == i,
                        onChanged: (_) => app.change(() => app.themeMode = i),
                      ),
                  ],
                ),
              ),
              _sec(
                context,
                '界面风格',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < 4; i++)
                          LitToggle(
                            wide: true,
                            label: const ['圆润', '方正', '简洁', '立体'][i],
                            icon: const [
                              Icons.blur_circular,
                              Icons.crop_square,
                              Icons.horizontal_rule,
                              Icons.layers
                            ][i],
                            value: app.uiStyle == i,
                            onChanged: (_) => app.change(() => app.uiStyle = i),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('开关按钮形状'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < 2; i++)
                          LitToggle(
                            wide: true,
                            label: const ['圆角', '方角'][i],
                            icon: const [Icons.circle, Icons.square][i],
                            value: app.toggleShape == i,
                            onChanged: (_) => app.change(() => app.toggleShape = i),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('效果预览'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        LitButton(icon: Icons.undo, label: '按钮', onTap: () {}),
                        LitToggle(icon: Icons.rule, label: '亮起', value: true, onChanged: (_) {}),
                        LitToggle(icon: Icons.rule, label: '熄灭', value: false, onChanged: (_) {}),
                      ],
                    ),
                  ],
                ),
              ),
              _sec(
                context,
                '自定义颜色',
                Column(
                  children: [
                    for (final e in names.entries)
                      _colorRow(context, e.key, e.value, cur[e.key]!),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => app.change(() => app.custom.clear()),
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: const Text('全部恢复默认'),
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
                    _nav(context, '全局背景（所有页面）', 'global'),
                    _nav(context, '主菜单图片', 'home'),
                    _nav(context, '对局页图片', 'game'),
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

class LayerEditorPage extends StatefulWidget {
  final String slot;
  final String title;
  const LayerEditorPage({super.key, required this.slot, required this.title});
  @override
  State<LayerEditorPage> createState() => _LayerEditorPageState();
}

class _LayerEditorPageState extends State<LayerEditorPage> {
  ImgLayer get l => app.layers[widget.slot]!;

  Widget _s(String label, double v, double lo, double hi, void Function(double) set) {
    final x = max(lo, min(hi, v));
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label)),
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: SizedBox(
              width: 170,
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
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
                      Center(
                        child: Text('预览',
                            style: TextStyle(color: cs.onSurface.withOpacity(0.3))),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                label: const Text('选择图片'),
              ),
              OutlinedButton(
                onPressed: () {
                  app.change(() => l.path = null);
                  setState(() {});
                },
                child: const Text('移除图片'),
              ),
              OutlinedButton(
                onPressed: () {
                  app.change(() => l.resetTransform());
                  setState(() {});
                },
                child: const Text('重置变换'),
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
          const SizedBox(height: 8),
          Text('图片会放在界面的下方，不遮挡按钮。', style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
