import 'dart:io';
import 'dart:math';
import 'dart:ui' show ImageFilter, lerpDouble;
import 'package:flutter/material.dart';
import 'settings.dart';
import 'ui.dart';

class AvatarBox extends StatelessWidget {
  final double size;
  const AvatarBox({super.key, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = app.avatar;
    final f = (p != null && File(p).existsSync()) ? File(p) : null;
    final r = size * 0.2;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: Color(app.borderColor), width: max(2.0, size * 0.045)),
        color: cs.surfaceContainerHighest,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(max(0.0, r - 2)),
        child: f != null
            ? Image.file(f, fit: BoxFit.cover)
            : Icon(Icons.person, size: size * 0.6, color: cs.onSurfaceVariant),
      ),
    );
  }
}

void openProfile(BuildContext context, GlobalKey key) {
  Rect origin = const Rect.fromLTWH(16, 16, 52, 52);
  final ro = key.currentContext?.findRenderObject();
  if (ro is RenderBox && ro.hasSize) {
    origin = ro.localToGlobal(Offset.zero) & ro.size;
  }
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'close',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 520),
    transitionBuilder: (c, a, s, child) => child,
    pageBuilder: (c, a, s) => ProfileOverlay(anim: a, origin: origin),
  );
}

class ProfileOverlay extends StatelessWidget {
  final Animation<double> anim;
  final Rect origin;
  const ProfileOverlay({super.key, required this.anim, required this.origin});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final availH = size.height - mq.padding.top - mq.padding.bottom;
    final tw = size.width - 32;
    final th = min(availH - 32, 680.0);
    final target = Rect.fromLTWH(16, mq.padding.top + (availH - th) / 2, tw, th);
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(anim.value);
        final rect = Rect.lerp(origin, target, t)!;
        final radius = lerpDouble(origin.width * 0.22, app.cardR + 6, t)!;
        final content = max(0.0, (t - 0.55) / 0.45);
        final avatarOp = max(0.0, 1 - t / 0.25);
        final xMid = max(0.0, 1 - (t - 0.2).abs() / 0.2);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 0.001 + 14 * t, sigmaY: 0.001 + 14 * t),
                  child: Container(color: Colors.black.withOpacity(0.38 * t)),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: rect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Material(
                  color: Color.lerp(cs.surfaceContainerHigh, cs.surface, 0.3)!
                      .withOpacity(0.97),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: content,
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minWidth: tw,
                            maxWidth: tw,
                            minHeight: th,
                            maxHeight: th,
                            child: const ProfileContent(),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: avatarOp,
                            child: AvatarBox(size: rect.shortestSide),
                          ),
                        ),
                      ),
                      Center(
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: xMid,
                            child: Icon(Icons.close, size: 30, color: cs.onSurface),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
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
    if (p != null) app.change(() => app.avatar = p);
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    var init = DateTime(now.year - 20, 1, 1);
    try {
      if (app.birthday.isNotEmpty) init = DateTime.parse(app.birthday);
    } catch (_) {}
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (d != null) {
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      app.change(() => app.birthday = '${d.year}-$m-$day');
    }
  }

  Future<void> _pickBorder() async {
    final v = await pickColorDialog(context, Color(app.borderColor));
    if (v == null) return;
    app.change(() => app.borderColor = v == -1 ? 0xFF26A69A : v);
  }

  Future<void> _editNum(String title, int cur, void Function(int) set) async {
    final c = TextEditingController(text: '$cur');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修改$title'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(c.text) ?? cur),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (v != null) app.change(() => set(v < 0 ? 0 : v));
  }

  Widget _stat(BuildContext context, String label, int v, void Function(int) set) {
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
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        return Stack(
          children: [
            ListView(
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
                            decoration: const InputDecoration(labelText: '名字', isDense: true),
                          ),
                          const SizedBox(height: 8),
                          Text('点击头像更换图片',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 36),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: uidC,
                  onChanged: (v) => app.quiet(() => app.uid = v),
                  decoration: const InputDecoration(labelText: '编号', isDense: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioC,
                  maxLines: 3,
                  onChanged: (v) => app.quiet(() => app.bio = v),
                  decoration: const InputDecoration(labelText: '个人介绍', isDense: true),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickBirthday,
                        icon: const Icon(Icons.cake, size: 18),
                        label: Text(app.birthday.isEmpty ? '设置生日' : '生日 ${app.birthday}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Text('头像边框颜色')),
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
                const Text('统计（点击数字可修改）',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _stat(context, '胜', app.wins, (v) => app.wins = v),
                    _stat(context, '负', app.losses, (v) => app.losses = v),
                    _stat(context, '启动次数', app.launches, (v) => app.launches = v),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        );
      },
    );
  }
}
