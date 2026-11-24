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
import 'avatar_editor.dart';

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

class LayerEditorPage extends StatelessWidget {
  final String slot;
  final String title;
  const LayerEditorPage({super.key, required this.slot, required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr(title))),
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder<int>(
          valueListenable: app.layerRev,
          builder: (context, _, __) {
            final l = app.layers[slot]!;
            final p = l.path;
            if (p == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wallpaper, size: 64, color: cs.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text(tr('还没有选择图片'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        tr('选好图片后，可以像编辑头像一样缩放、变形、调色、涂鸦、加图形 / 贴纸 / 文字，还可以选不同形状的手机屏幕来对位'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () async {
                          final f = await pickImageChoose(context);
                          if (f != null) {
                            app.change(() {
                              l.path = f;
                              l.edit.xf.ar = 0;
                            });
                            app.touchLayer(() {});
                          }
                        },
                        icon: const Icon(Icons.image),
                        label: Text(tr('选择图片')),
                      ),
                    ],
                  ),
                ),
              );
            }
            return AvatarEditorPage(
              key: ValueKey<String>('bg_$slot'),
              path: p,
              slot: slot,
              onCancel: () => Navigator.maybePop(context),
              onDone: (a, b, c) {},
            );
          },
        ),
      ),
    );
  }
}
