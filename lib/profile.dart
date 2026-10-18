import 'dart:io';
import 'dart:math';
import 'dart:ui' show ImageFilter, lerpDouble;
import 'package:flutter/material.dart';
import 'settings.dart';
import 'strings.dart';
import 'ui.dart';

/// 头像框。x 从 0 到 1 时，头像会渐变成 X
class AvatarBox extends StatelessWidget {
  final double size;
  final double x;
  const AvatarBox({super.key, this.size = 52, this.x = 0});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: app.avatarRev,
      builder: (context, _, __) {
        final cs = Theme.of(context).colorScheme;
        final p = app.avatar;
        final f = (p != null && File(p).existsSync()) ? File(p) : null;
        final r = size * 0.2;
        final bw = max(2.0, size * 0.045);
        final Widget img = f != null
            ? Image.file(f, fit: BoxFit.cover, cacheWidth: 300, gaplessPlayback: true)
            : Center(child: Icon(Icons.person, size: size * 0.6, color: cs.onSurfaceVariant));
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: Color(app.borderColor), width: bw),
            color: cs.surfaceContainerHighest,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(max(0.0, r - bw)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(opacity: 1 - x, child: img),
                if (x > 0)
                  Opacity(
                    opacity: x,
                    child: Transform.rotate(
                      angle: (x - 1) * pi / 2,
                      child: Center(
                          child: Icon(Icons.close, size: size * 0.55, color: cs.onSurface)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 个人资料层：头像按钮始终在最上面，点击后变 X，面板从头像处展开
class ProfileLayer extends StatelessWidget {
  final Animation<double> anim;
  final VoidCallback onToggle;
  const ProfileLayer({super.key, required this.anim, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final cs = Theme.of(context).colorScheme;
    final top = mq.padding.top + 12;
    final origin = Rect.fromLTWH(16, top, 52, 52);
    final ty = top + 52 + 14;
    final th = min(size.height - ty - mq.padding.bottom - 20, 680.0);
    final tw = size.width - 32;
    final target = Rect.fromLTWH(16, ty, tw, th);

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: anim,
          builder: (context, _) {
            if (anim.value == 0) return const SizedBox.shrink();
            final t = Curves.easeInOutCubic.transform(anim.value);
            final rect = Rect.lerp(origin, target, t)!;
            final content = max(0.0, (t - 0.5) / 0.5);
            return Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: onToggle,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 0.01 + 14 * t, sigmaY: 0.01 + 14 * t),
                    child: ColoredBox(color: Colors.black.withOpacity(0.35 * t)),
                  ),
                ),
                Positioned.fromRect(
                  rect: rect,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(lerpDouble(10, app.cardR + 6, t)!),
                    child: Material(
                      color: cs.surfaceContainerHigh,
                      child: content > 0
                          ? Opacity(
                              opacity: content,
                              child: OverflowBox(
                                alignment: Alignment.topCenter,
                                minWidth: tw,
                                maxWidth: tw,
                                minHeight: th,
                                maxHeight: th,
                                child: const ProfileContent(),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        Positioned(
          left: 16,
          top: top,
          child: GestureDetector(
            onTap: onToggle,
            child: AnimatedBuilder(
              animation: anim,
              builder: (context, _) => AvatarBox(
                  size: 52, x: Curves.easeInOutCubic.transform(anim.value)),
            ),
          ),
        ),
      ],
    );
  }
}

String birthdayText(String iso) {
  final p = iso.split('-');
  if (p.length != 3) return iso;
  return trf('{y}年{m}月{d}日', {
    'y': p[0],
    'm': '${int.tryParse(p[1]) ?? p[1]}',
    'd': '${int.tryParse(p[2]) ?? p[2]}',
  });
}

class ProfileContent extends StatefulWidget {
  const ProfileContent({super.key});
  @override
  State<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<ProfileContent> {
  late final TextEditingController nameC = TextEditingController(text: app.name);
  late final TextEditingController uidC = TextEditingController(text: app.uid);
  late final TextEditingController bioC = TextEditingController(text: app.bio);

  @override
  void dispose() {
    nameC.dispose();
    uidC.dispose();
    bioC.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final p = await pickImage();
    if (p != null) app.touchAvatar(() => app.avatar = p);
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    var init = DateTime(now.year - 20, 1, 1);
    try {
      if (app.birthday.isNotEmpty) init = DateTime.parse(app.birthday);
    } catch (_) {}
    final d = await showDatePicker(
      context: context,
      locale: Locale(const ['zh', 'en', 'ja', 'ru'][app.lang]),
      helpText: tr('选择生日'),
      initialDate: init,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (d != null) {
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      setState(() => app.quiet(() => app.birthday = '${d.year}-$m-$day'));
    }
  }

  Future<void> _pickBorder() async {
    final old = app.borderColor;
    final v = await pickColorDialog(context, Color(old),
        onLive: (c) => app.touchAvatar(() => app.borderColor = c.toARGB32()));
    if (v == null) {
      app.touchAvatar(() => app.borderColor = old);
    } else if (v == -1) {
      app.touchAvatar(() => app.borderColor = 0xFF26A69A);
    } else {
      app.touchAvatar(() => app.borderColor = v);
    }
    if (mounted) setState(() {});
  }

  Future<void> _editNum(String title, int cur, void Function(int) set) async {
    final c = TextEditingController(text: '$cur');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trf('修改{x}', {'x': title})),
        content: TextField(
            controller: c, keyboardType: TextInputType.number, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('取消'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(c.text) ?? cur),
            child: Text(tr('确定')),
          ),
        ],
      ),
    );
    if (v != null) setState(() => app.quiet(() => set(v < 0 ? 0 : v)));
  }

  Widget _stat(String label, int v, void Function(int) set) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () => _editNum(label, v, set),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: styled(cs.surfaceContainerHighest, r: app.cardR),
          child: Column(
            children: [
              Text('$v', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Row(
          children: [
            GestureDetector(onTap: _pickAvatar, child: const AvatarBox(size: 92)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameC,
                    onChanged: (v) => app.quiet(() => app.name = v),
                    decoration: InputDecoration(labelText: tr('名字'), isDense: true),
                  ),
                  const SizedBox(height: 8),
                  Text(tr('点击头像更换图片'),
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: uidC,
          onChanged: (v) => app.quiet(() => app.uid = v),
          decoration: InputDecoration(labelText: tr('编号'), isDense: true),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: bioC,
          maxLines: 3,
          onChanged: (v) => app.quiet(() => app.bio = v),
          decoration: InputDecoration(labelText: tr('个人介绍'), isDense: true),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickBirthday,
          icon: const Icon(Icons.cake, size: 18),
          label: Text(app.birthday.isEmpty
              ? tr('设置生日')
              : '${tr('生日')}  ${birthdayText(app.birthday)}'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Text(tr('头像边框颜色'))),
            GestureDetector(
              onTap: _pickBorder,
              child: Container(
                width: 44,
                height: 30,
                decoration: BoxDecoration(
                  color: Color(app.borderColor),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(tr('统计（点击数字可修改）'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(
          children: [
            _stat(tr('胜'), app.wins, (v) => app.wins = v),
            _stat(tr('负'), app.losses, (v) => app.losses = v),
            _stat(tr('启动次数'), app.launches, (v) => app.launches = v),
          ],
        ),
      ],
    );
  }
}
