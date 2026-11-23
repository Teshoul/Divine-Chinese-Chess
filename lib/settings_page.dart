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
import 'xform.dart';

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
    final l = app.layers[slot]!;
    final has = l.path != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr(title)),
          subtitle: Text(tr(!has ? '未设置' : (l.enabled ? '已设置图片' : '已设置图片，当前未启用'))),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
              context, revealRoute(LayerEditorPage(slot: slot, title: title))),
        ),
        LitToggle(
          wide: true,
          icon: l.enabled ? Icons.visibility : Icons.visibility_off,
          label: tr(l.enabled ? '已启用' : '已停用'),
          value: l.enabled,
          onChanged: (v) => app.change(() => l.enabled = v),
        ),
        const SizedBox(height: 10),
      ],
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
                    Text('${tr('版本')} 1.5.2'),
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

// ───────────── 手机屏幕外形 ─────────────

class _Fr {
  final String name;
  final double ar; // 高 / 宽，0 = 用当前手机的真实比例
  final double rad; // 圆角，占宽度的比例，>=0.5 就是圆形
  final int kind; // 0 无 1 刘海 2 水滴 3 居中挖孔 4 左上挖孔 5 右上挖孔 6 灵动岛 7 曲面 8 瀑布 9 折叠
  const _Fr(this.name, this.ar, this.rad, this.kind);
}

const List<_Fr> _frames = [
  _Fr('标准全面屏', 2.05, 0.09, 0),
  _Fr('直角全面屏', 2.05, 0, 0),
  _Fr('16:9 直屏', 1.78, 0, 0),
  _Fr('18:9 全面屏', 2.0, 0.06, 0),
  _Fr('21:9 长屏', 2.33, 0.09, 0),
  _Fr('刘海屏', 2.17, 0.09, 1),
  _Fr('水滴屏', 2.1, 0.08, 2),
  _Fr('居中挖孔', 2.1, 0.11, 3),
  _Fr('左上挖孔', 2.1, 0.11, 4),
  _Fr('右上挖孔', 2.1, 0.11, 5),
  _Fr('灵动岛', 2.17, 0.14, 6),
  _Fr('曲面屏', 2.15, 0.12, 7),
  _Fr('瀑布屏', 2.2, 0.16, 8),
  _Fr('折叠屏·内屏', 1.12, 0.05, 9),
  _Fr('折叠屏·外屏', 2.5, 0.09, 3),
  _Fr('平板 4:3', 1.33, 0.04, 0),
  _Fr('平板 16:10', 1.6, 0.04, 0),
  _Fr('大圆角屏', 2.05, 0.18, 0),
  _Fr('方形屏', 1.0, 0.02, 0),
  _Fr('圆形屏（手表）', 1.0, 0.5, 0),
  _Fr('我的手机', 0, 0.09, 0),
];

Path _framePath(_Fr f, Size s) {
  final r = f.rad * s.width;
  if (f.rad >= 0.5) return Path()..addOval(Offset.zero & s);
  if (r <= 0) return Path()..addRect(Offset.zero & s);
  return Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(r)));
}

class _FrameClipper extends CustomClipper<Path> {
  final _Fr f;
  _FrameClipper(this.f);
  @override
  Path getClip(Size size) => _framePath(f, size);
  @override
  bool shouldReclip(covariant _FrameClipper old) => old.f != f;
}

/// 刘海 / 挖孔 / 曲面边缘等遮挡物，画在预览框的最上层
class _FramePainter extends CustomPainter {
  final _Fr f;
  _FramePainter(this.f);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final black = Paint()..color = const Color(0xEE000000);
    switch (f.kind) {
      case 1:
        canvas.drawRRect(
            RRect.fromRectAndCorners(Rect.fromLTWH(w * 0.3, 0, w * 0.4, w * 0.075),
                bottomLeft: Radius.circular(w * 0.04), bottomRight: Radius.circular(w * 0.04)),
            black);
        break;
      case 2:
        canvas.drawRRect(
            RRect.fromRectAndCorners(Rect.fromLTWH(w * 0.4, 0, w * 0.2, w * 0.055),
                bottomLeft: Radius.circular(w * 0.05), bottomRight: Radius.circular(w * 0.05)),
            black);
        break;
      case 3:
        canvas.drawCircle(Offset(w * 0.5, w * 0.045), w * 0.026, black);
        break;
      case 4:
        canvas.drawCircle(Offset(w * 0.12, w * 0.045), w * 0.026, black);
        break;
      case 5:
        canvas.drawCircle(Offset(w * 0.88, w * 0.045), w * 0.026, black);
        break;
      case 6:
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * 0.34, w * 0.03, w * 0.32, w * 0.065), Radius.circular(w * 0.04)),
            black);
        break;
      case 7:
      case 8:
        final ew = w * (f.kind == 7 ? 0.05 : 0.1);
        for (final left in [true, false]) {
          final r = left ? Rect.fromLTWH(0, 0, ew, s.height) : Rect.fromLTWH(w - ew, 0, ew, s.height);
          final g = LinearGradient(
            begin: left ? Alignment.centerLeft : Alignment.centerRight,
            end: left ? Alignment.centerRight : Alignment.centerLeft,
            colors: const [Color(0x99000000), Color(0x00000000)],
          );
          canvas.drawRect(r, Paint()..shader = g.createShader(r));
        }
        break;
      case 9:
        canvas.drawRect(Rect.fromLTWH(s.width / 2 - 1.2, 0, 2.4, s.height),
            Paint()..color = const Color(0x66000000));
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) => old.f != f;
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
  Xf get xf => l.xf;
  bool showZones = true;
  bool _warp = false;
  final XfDrag _xd = XfDrag();
  int _ptrs = 0;
  double _s0 = 1, _r0 = 0;
  static const double _mk = 0.42; // 屏幕框外面留的一圈（占框宽度的比例）

  @override
  void initState() {
    super.initState();
    _loadAr();
  }

  Future<void> _loadAr() async {
    final p = l.path;
    if (p == null) return;
    final sz = await imageNaturalSize(p);
    if (!mounted || sz == null || sz.height <= 0) return;
    final ar = sz.width / sz.height;
    if ((xf.ar - ar).abs() > 1e-3) {
      app.touchLayer(() => xf.ar = ar);
      setState(() {});
    }
  }

  _Fr get _fr => _frames[app.layerFrame.clamp(0, _frames.length - 1)];

  double _frAr(BuildContext c) {
    final f = _fr;
    if (f.ar > 0) return f.ar;
    final sz = MediaQuery.sizeOf(c);
    return sz.width <= 0 ? 2.0 : sz.height / sz.width;
  }

  /// 拖动 / 滑块：只刷新背景图层，所有页面每一帧都跟手
  void _live(VoidCallback f) {
    app.touchLayer(f);
    setState(() {});
  }

  double _wrap(double r) {
    while (r > 180) {
      r -= 360;
    }
    while (r < -180) {
      r += 360;
    }
    return r;
  }

  Widget _n(String label, double raw, double sMin, double sMax, void Function(double) set,
      {double nMin = -10000,
      double nMax = 10000,
      double mul = 100,
      int dec = 0,
      String suffix = '%'}) {
    return NumRow(
      label: tr(label),
      raw: raw,
      sMin: sMin,
      sMax: sMax,
      nMin: nMin,
      nMax: nMax,
      mul: mul,
      decimals: dec,
      suffix: suffix,
      onChanged: (v) => _live(() => set(v)),
    );
  }

  /// 把整张图“适应屏幕”（完整显示）或“铺满屏幕”（填满，超出的部分保留在屏幕外）
  Future<void> _fit(bool cover) async {
    final p = l.path;
    if (p == null) return;
    final sz = await imageNaturalSize(p);
    if (!mounted) return;
    final ar = _frAr(context);
    var z = 1.0;
    double? iar;
    if (sz != null && sz.width > 0 && sz.height > 0) {
      iar = sz.width / sz.height;
      final rw = 1 / sz.width, rh = ar / sz.height;
      final big = max(rw, rh), small = min(rw, rh);
      z = cover ? big / small : 1.0;
    }
    app.touchLayer(() {
      xf.resetAll();
      xf.scale = z.clamp(0.1, 6.0).toDouble();
      if (iar != null) xf.ar = iar;
    });
    setState(() {});
  }

  Widget _frameButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < _frames.length; i++)
          i == app.layerFrame
              ? FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 36)),
                  child: Text(tr(_frames[i].name)),
                )
              : OutlinedButton(
                  onPressed: () {
                    app.change(() => app.layerFrame = i);
                    setState(() {});
                  },
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 36)),
                  child: Text(tr(_frames[i].name)),
                ),
      ],
    );
  }

  List<Widget> _cornerRows() {
    const names = ['左上', '右上', '右下', '左下'];
    final out = <Widget>[];
    for (var i = 0; i < 4; i++) {
      out.add(_n('${names[i]}角 X', xf.p[i * 2], -0.5, 0.5, (v) => xf.p[i * 2] = v,
          nMin: -3, nMax: 3));
      out.add(_n('${names[i]}角 Y', xf.p[i * 2 + 1], -0.5, 0.5, (v) => xf.p[i * 2 + 1] = v,
          nMin: -3, nMax: 3));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final zones = _zones(widget.slot);
    final scr = MediaQuery.sizeOf(context);
    final fr = _fr;
    final ar = _frAr(context);
    final pw = max(80.0, min(min(240.0, scr.width * 0.56), scr.height * 0.5 / (ar + _mk * 2)));
    final ph = pw * ar;
    final m = pw * _mk;
    final cw = pw + m * 2, ch = ph + m * 2;
    final box = Size(pw, ph);
    final hasImg = l.path != null;
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
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) {
                    _ptrs++;
                    if (_ptrs == 1 && hasImg) {
                      if (_xd.begin(xf, box, e.localPosition - Offset(m, m), _warp)) {
                        setState(() {});
                      }
                    }
                  },
                  onPointerMove: (e) {
                    if (_xd.active) {
                      _live(() => _xd.update(xf, box, e.localPosition - Offset(m, m), _warp));
                    }
                  },
                  onPointerUp: (e) {
                    if (_ptrs > 0) _ptrs--;
                    if (_ptrs == 0 && _xd.active) setState(() => _xd.end());
                  },
                  onPointerCancel: (e) {
                    if (_ptrs > 0) _ptrs--;
                    if (_ptrs == 0 && _xd.active) setState(() => _xd.end());
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (d) {
                      _s0 = xf.scale;
                      _r0 = xf.rot;
                    },
                    onScaleUpdate: (d) {
                      if (_xd.active) return;
                      _live(() {
                        xf.dx += d.focalPointDelta.dx / pw;
                        xf.dy += d.focalPointDelta.dy / ph;
                        if (d.pointerCount >= 2) {
                          xf.scale = (_s0 * d.scale).clamp(0.05, 20.0).toDouble();
                          xf.rot = _wrap(_r0 + d.rotation * 180 / pi);
                        }
                      });
                    },
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
                              opacity: 0.35,
                              child: ImageSlot(slot: widget.slot, clip: false, force: true)),
                        ),
                        // 框内：就是真正在手机屏幕上看到的样子（按选的屏幕外形裁切）
                        Positioned(
                          left: m,
                          top: m,
                          width: pw,
                          height: ph,
                          child: ClipPath(
                            clipper: _FrameClipper(fr),
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
                                ImageSlot(slot: widget.slot, force: true),
                                if (showZones)
                                  IgnorePointer(child: CustomPaint(painter: _ZonePainter(zones))),
                                IgnorePointer(child: CustomPaint(painter: _FramePainter(fr))),
                              ],
                            ),
                          ),
                        ),
                        // 屏幕外框
                        Positioned(
                          left: m,
                          top: m,
                          width: pw,
                          height: ph,
                          child: IgnorePointer(
                            child: ClipPath(
                              clipper: _FrameClipper(fr),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white, width: 2),
                                  borderRadius: fr.rad >= 0.5
                                      ? BorderRadius.circular(pw)
                                      : BorderRadius.circular(fr.rad * pw),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 图片的高亮框 + 手柄
                        if (hasImg)
                          Positioned(
                            left: m,
                            top: m,
                            width: pw,
                            height: ph,
                            child: IgnorePointer(
                              child: CustomPaint(painter: XfPainter(xf, _warp, _xd.h, _xd)),
                            ),
                          ),
                      ],
                    ),
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
          Text(
              tr('单指拖动移动，双指缩放 / 旋转；拖高亮框的角缩放、边中点单独拉宽 / 拉高、上方圆点旋转；白框是手机屏幕，框外半透明的部分是被挪出屏幕的图片，整张图都会保留'),
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 12),
          LitToggle(
            wide: true,
            icon: l.enabled ? Icons.visibility : Icons.visibility_off,
            label: tr(l.enabled ? '这张图片已启用' : '这张图片已停用'),
            value: l.enabled,
            onChanged: (v) {
              app.change(() => l.enabled = v);
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () async {
                  final p = await pickImageChoose(context);
                  if (p != null) {
                    app.change(() {
                      l.path = p;
                      xf.ar = 0;
                    });
                    app.touchLayer(() {});
                    await _loadAr();
                  }
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.image),
                label: Text(tr('选择图片')),
              ),
              OutlinedButton(
                onPressed: !hasImg ? null : () => _fit(false),
                child: Text(tr('适应屏幕')),
              ),
              OutlinedButton(
                onPressed: !hasImg ? null : () => _fit(true),
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
                onPressed: () => _live(() => l.resetTransform()),
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
          const SizedBox(height: 16),
          Text(tr('手机屏幕外形'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(tr('选和你手机最像的屏幕框来预览（刘海、挖孔、曲面边缘都会画出来）；“我的手机”按这台设备的真实比例。'),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 8),
          _frameButtons(),
          const SizedBox(height: 16),
          Text(tr('大小与位置'), style: const TextStyle(fontWeight: FontWeight.w800)),
          _n('缩放', xf.scale, 0.1, 6.0, (v) => xf.scale = v.clamp(0.01, 50.0).toDouble(),
              nMin: 0.01, nMax: 50),
          _n('水平位置', xf.dx, -2.0, 2.0, (v) => xf.dx = v, nMin: -20, nMax: 20),
          _n('垂直位置', xf.dy, -2.0, 2.0, (v) => xf.dy = v, nMin: -20, nMax: 20),
          _n('旋转', xf.rot, -180.0, 180.0, (v) => xf.rot = v,
              nMin: -3600, nMax: 3600, mul: 1, dec: 1, suffix: '°'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(tr('变形'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              SizedBox(
                width: 190,
                child: LitToggle(
                  wide: true,
                  icon: Icons.transform,
                  label: tr(_warp ? '隐藏变形手柄' : '显示变形手柄'),
                  value: _warp,
                  onChanged: (v) => setState(() => _warp = v),
                ),
              ),
            ],
          ),
          _n('宽度', xf.sx, 0.05, 4.0, (v) => xf.sx = v.clamp(0.01, 50.0).toDouble(),
              nMin: 0.01, nMax: 50),
          _n('高度', xf.sy, 0.05, 4.0, (v) => xf.sy = v.clamp(0.01, 50.0).toDouble(),
              nMin: 0.01, nMax: 50),
          _n('水平倾斜', xf.skewX, -0.8, 0.8, (v) => xf.skewX = v, nMin: -5, nMax: 5),
          _n('垂直倾斜', xf.skewY, -0.8, 0.8, (v) => xf.skewY = v, nMin: -5, nMax: 5),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              LitToggle(
                icon: Icons.flip,
                label: tr('水平翻转'),
                value: xf.flipX,
                onChanged: (v) => _live(() => xf.flipX = v),
              ),
              OutlinedButton(
                onPressed: () => _live(() => xf.resetWarp()),
                child: Text(tr('重置变形')),
              ),
            ],
          ),
          if (_warp) ...[
            const SizedBox(height: 8),
            Text(tr('四个角的透视（拖动图上橙色的角，或在这里输入数值）'),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            ..._cornerRows(),
          ],
          const SizedBox(height: 12),
          Text(tr('外观'), style: const TextStyle(fontWeight: FontWeight.w800)),
          _n('透明度', l.opacity, 0.0, 1.0, (v) => l.opacity = v.clamp(0.0, 1.0).toDouble(),
              nMin: 0, nMax: 1),
          _n('模糊', l.blur, 0.0, 20.0, (v) => l.blur = v.clamp(0.0, 60.0).toDouble(),
              nMin: 0, nMax: 60, mul: 1, dec: 1, suffix: ''),
        ],
      ),
    );
  }
}
