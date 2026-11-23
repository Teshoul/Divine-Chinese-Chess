import 'dart:math';
import 'package:flutter/material.dart';
import 'fx.dart';
import 'settings.dart';
import 'strings.dart';
import 'ui.dart';
import 'ai_ui.dart';
import 'sfx.dart';
import 'extras.dart';
import 'img_util.dart';

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
          appBar: AppBar(automaticallyImplyLeading: false, title: Text(tr('设置'))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
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
                            label: tr('果冻质感'),
                            value: app.glass,
                            onChanged: (v) => app.change(() => app.glass = v)),
                        LitToggle(
                            wide: true,
                            icon: Icons.landscape,
                            label: tr('主题装饰图案'),
                            value: app.decor,
                            onChanged: (v) => app.change(() => app.decor = v)),
                        LitToggle(
                            wide: true,
                            icon: Icons.volume_up,
                            label: tx('音效'),
                            value: app.sfxOn,
                            onChanged: (v) => app.change(() => app.sfxOn = v)),
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
              _sec(
                context,
                '局内音乐',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LitToggle(
                      wide: true,
                      icon: Icons.music_note,
                      label: tr('在对局里显示音乐按钮'),
                      value: app.gameMusic,
                      onChanged: (v) => app.change(() => app.gameMusic = v),
                    ),
                    const SizedBox(height: 14),
                    Text(tr('按钮位置')),
                    const SizedBox(height: 8),
                    _group(
                        const ['顶栏右侧', '棋手栏左侧', '棋手栏右侧'],
                        const [Icons.north_east, Icons.west, Icons.east],
                        app.gameMusicPos,
                        (i) => app.change(() => app.gameMusicPos = i)),
                    const SizedBox(height: 8),
                    Text(
                      tr('对局中点小按钮播放 / 暂停，点旁边的列表按钮拉出播放列表，可以随时切换你在“音乐”里上传的本地音频。联机对局里“棋手栏右侧”会自动改到左侧，避免挡住对手头像。'),
                      style: TextStyle(
                          fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
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
                    Text('${tr('版本')} 1.5.3'),
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

  /// 拖动 / 滑块：只刷新背景图层，所有页面每一帧都跟手
  void _live(VoidCallback f) {
    app.touchLayer(f);
    setState(() {});
  }

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
            onChanged: (nv) => _live(() => set(nv)),
          ),
        ),
      ],
    );
  }

  /// 按屏幕比例把整张图“适应屏幕”（完整显示）或“铺满屏幕”（填满，超出的部分保留在屏幕外）
  Future<void> _fit(bool cover) async {
    final p = l.path;
    if (p == null) return;
    final sz = await imageNaturalSize(p);
    if (!mounted) return;
    final scr = MediaQuery.sizeOf(context);
    var z = 1.0;
    if (sz != null && sz.width > 0 && sz.height > 0) {
      final rw = scr.width / sz.width, rh = scr.height / sz.height;
      final big = max(rw, rh), small = min(rw, rh);
      z = cover ? big / small : 1.0;
    }
    app.touchLayer(() {
      l.scale = z.clamp(0.1, 6.0).toDouble();
      l.dx = 0;
      l.dy = 0;
      l.rot = 0;
      l.skewX = 0;
      l.skewY = 0;
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final zones = _zones(widget.slot);
    final pw = min(220.0, MediaQuery.sizeOf(context).width * 0.56);
    final ph = pw * 2.05;
    final m = pw * 0.42; // 屏幕框外面留的一圈，用来显示被挪到屏幕外的那部分图
    final cw = pw + m * 2, ch = ph + m * 2;
    return Scaffold(
      appBar: AppBar(title: Text(tr(widget.title))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: Container(
              width: cw,
              height: ch,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: cs.surfaceContainerHighest.withOpacity(0.5),
                border: Border.all(color: cs.outline.withOpacity(0.6), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (d) {
                    _s0 = l.scale;
                    _r0 = l.rot;
                  },
                  onScaleUpdate: (d) => _live(() {
                    l.dx = (l.dx + d.focalPointDelta.dx / pw).clamp(-2.0, 2.0).toDouble();
                    l.dy = (l.dy + d.focalPointDelta.dy / ph).clamp(-2.0, 2.0).toDouble();
                    if (d.pointerCount >= 2) {
                      l.scale = (_s0 * d.scale).clamp(0.1, 6.0).toDouble();
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
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 框外：整张图半透明显示，没有任何部分被裁掉
                      Positioned(
                        left: m,
                        top: m,
                        width: pw,
                        height: ph,
                        child: Opacity(
                            opacity: 0.35, child: ImageSlot(slot: widget.slot, clip: false)),
                      ),
                      // 框内：就是真正在手机屏幕上看到的样子
                      Positioned(
                        left: m,
                        top: m,
                        width: pw,
                        height: ph,
                        child: ClipRect(
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
                      Positioned(
                        left: m,
                        top: m,
                        width: pw,
                        height: ph,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
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
          Text(tr('单指拖动移动，双指缩放 / 旋转；白框是手机屏幕，框外半透明的部分是被挪出屏幕的图片，整张图都会保留'),
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
                  final p = await pickImageChoose(context);
                  if (p != null) {
                    app.change(() => l.path = p);
                    app.touchLayer(() {});
                  }
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.image),
                label: Text(tr('选择图片')),
              ),
              OutlinedButton(
                onPressed: l.path == null ? null : () => _fit(false),
                child: Text(tr('适应屏幕')),
              ),
              OutlinedButton(
                onPressed: l.path == null ? null : () => _fit(true),
                child: Text(tr('铺满屏幕')),
              ),
              OutlinedButton(
                onPressed: () {
                  app.change(() => l.path = null);
                  app.touchLayer(() {});
                  setState(() {});
                },
                child: Text(tr('移除图片')),
              ),
              OutlinedButton(
                onPressed: () {
                  _live(() => l.resetTransform());
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
          _s('缩放', l.scale, 0.1, 6.0, (v) => l.scale = v),
          _s('水平位置', l.dx, -2.0, 2.0, (v) => l.dx = v),
          _s('垂直位置', l.dy, -2.0, 2.0, (v) => l.dy = v),
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
