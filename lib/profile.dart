import 'dart:io';
import 'dart:math';
import 'dart:ui' show ImageFilter, lerpDouble;
import 'package:flutter/material.dart';
import 'avatar_drawer.dart';
import 'fly.dart';
import 'glitch.dart';
import 'items.dart';
import 'liquid.dart';
import 'settings.dart';
import 'strings.dart';
import 'ui.dart';

/// 头像框。x 从 0 到 1 时，头像会渐变成 X（x 可以略微超过 1，用来做 Q 弹的回弹）
class AvatarBox extends StatelessWidget {
  final double size;
  final double x;
  final bool badge;
  const AvatarBox({super.key, this.size = 52, this.x = 0, this.badge = true});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: app.avatarRev,
      builder: (context, _, __) {
        final cs = Theme.of(context).colorScheme;
        final p = app.avatar;
        final isStar = p == kStarAvatar && app.owns('avatar_star');
        final f = (!isStar && p != null && p != kStarAvatar && File(p).existsSync())
            ? File(p)
            : null;
        final r = size * 0.2;
        final bw = max(2.0, size * 0.045);
        final xo = x.clamp(0.0, 1.0).toDouble();
        final Widget inner = isStar
            ? const StarAvatarFill()
            : (f != null
                ? Image.file(f, fit: BoxFit.cover, cacheWidth: 300, gaplessPlayback: true)
                : Center(child: Icon(Icons.person, size: size * 0.6, color: cs.onSurfaceVariant)));
        final box = Container(
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
                Opacity(opacity: 1 - xo, child: inner),
                if (xo > 0)
                  Opacity(
                    opacity: xo,
                    child: Transform.rotate(
                      angle: (x - 1) * pi / 2,
                      child: Transform.scale(
                        scale: 0.55 + 0.45 * x,
                        child: Center(
                            child: Icon(Icons.close, size: size * 0.55, color: cs.onSurface)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
        final corner = app.eqCorner;
        if (!badge || corner == null || size < 36) return box;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: box),
              Positioned(
                right: -size * 0.14,
                bottom: -size * 0.14,
                child: Opacity(opacity: 1 - xo, child: CornerView(id: corner, size: size * 0.42)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 个人资料层：头像按钮始终在最上面。
/// 点开时：头像方块先极快向右拉宽 → 略微停顿 → 极快向下拉长 → 内容渐显，Q 弹地变成 X；关闭是倒放。
class ProfileLayer extends StatelessWidget {
  final Animation<double> anim;
  final VoidCallback onToggle;
  const ProfileLayer({super.key, required this.anim, required this.onToggle});

  Rect _stageRect(double u, Rect o, Rect t, double screenW) {
    double eb(double x) => Curves.easeOutBack.transform(x.clamp(0.0, 1.0));
    final a = eb(u / 0.20);
    final c = eb((u - 0.28) / 0.22);
    final w = lerpDouble(o.width, t.width, a)!.clamp(o.width, screenW - o.left).toDouble();
    final h = lerpDouble(o.height, t.height, c)!.clamp(o.height, 4000.0).toDouble();
    return Rect.fromLTWH(o.left, o.top, w, h);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final cs = Theme.of(context).colorScheme;
    final top = mq.padding.top + 12;
    final origin = Rect.fromLTWH(16, top, 52, 52);
    final ty = top + 52 + 14;
    final th = min(size.height - ty - mq.padding.bottom - 20, 720.0);
    final tw = size.width - 32;
    final target = Rect.fromLTWH(16, ty, tw, th);

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: anim,
          builder: (context, _) {
            final u = anim.value;
            if (u == 0) return const SizedBox.shrink();
            final rect = _stageRect(u, Rect.fromLTWH(16, top, 52, 52), target, size.width);
            final dim = Curves.easeOut.transform(((u - 0.2) / 0.8).clamp(0.0, 1.0));
            final content = Curves.easeOut.transform(((u - 0.55) / 0.45).clamp(0.0, 1.0));
            final radius = lerpDouble(10, app.cardR + 6, Curves.easeOut.transform((u / 0.5).clamp(0.0, 1.0)))!;
            return Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: onToggle,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 0.01 + 14 * dim, sigmaY: 0.01 + 14 * dim),
                    child: ColoredBox(color: Colors.black.withOpacity(0.35 * dim)),
                  ),
                ),
                Positioned.fromRect(
                  rect: rect,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: app.divine
                        ? divineDecoration(radius, false)
                        : BoxDecoration(
                            color: cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(radius)),
                    child: Material(
                      type: MaterialType.transparency,
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
          left: origin.left,
          top: origin.top,
          child: GestureDetector(
            onTap: onToggle,
            child: AnimatedBuilder(
              animation: anim,
              builder: (context, _) => AvatarBox(
                size: 52,
                x: Curves.elasticOut.transform((anim.value / 0.5).clamp(0.0, 1.0)),
              ),
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

  final GlobalKey _avKey = GlobalKey();
  final GlobalKey _rowKey = GlobalKey();
  final Map<String, GlobalKey> _tileKeys = <String, GlobalKey>{};
  final Map<String, GlobalKey> _wornKeys = <String, GlobalKey>{};
  String? _hiddenItem;

  GlobalKey _tileKey(String id) => _tileKeys.putIfAbsent(id, () => GlobalKey());
  GlobalKey _wornKey(String id) => _wornKeys.putIfAbsent(id, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    final a = app.avatar;
    if (a != null && a != kStarAvatar && !app.avatars.contains(a)) app.avatars.add(a);
  }

  @override
  void dispose() {
    nameC.dispose();
    uidC.dispose();
    bioC.dispose();
    super.dispose();
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
            controller: c, keyboardType: TextInputType.number, autofocus: true, maxLength: 12),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('取消'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(c.text) ?? cur),
            child: Text(tr('确定')),
          ),
        ],
      ),
    );
    if (v != null) {
      setState(() => set(clampStat(v)));
      app.flush();
    }
  }

  // ───────────── 徽标 / 角标：飞行动画 ─────────────

  Rect _cornerRect(Rect av) =>
      Rect.fromLTWH(av.right - 0.28 * av.width, av.bottom - 0.28 * av.width, 0.42 * av.width, 0.42 * av.width);

  void _tapBadge(Item it) {
    if (_hiddenItem != null) return;
    final id = it.id;
    final tile = globalRectOf(_tileKey(id));
    if (app.eqBadges.contains(id)) {
      // 取消佩戴：已经戴着的徽标先快后慢地飞回徽标库里它的位置
      final worn = globalRectOf(_wornKey(id));
      app.toggleBadge(id);
      setState(() {});
      if (worn != null && tile != null) {
        setState(() => _hiddenItem = id);
        flyTo(
          context,
          from: worn,
          to: tile,
          child: BadgeView(id: id, h: worn.height),
          onDone: () {
            if (mounted) setState(() => _hiddenItem = null);
          },
        );
      }
      return;
    }
    final row = globalRectOf(_rowKey);
    if (tile == null || row == null) {
      app.toggleBadge(id);
      setState(() {});
      return;
    }
    final dest = Rect.fromLTWH(
      row.right + (app.eqBadges.isEmpty ? 0 : 4),
      row.top + (row.height - tile.height) / 2,
      tile.width,
      tile.height,
    );
    setState(() => _hiddenItem = id);
    flyTo(
      context,
      from: tile,
      to: dest,
      child: BadgeView(id: id, h: tile.height),
      onDone: () {
        app.toggleBadge(id);
        if (mounted) setState(() => _hiddenItem = null);
      },
    );
  }

  void _tapCorner(Item it) {
    if (_hiddenItem != null) return;
    final id = it.id;
    final tile = globalRectOf(_tileKey(id));
    final av = globalRectOf(_avKey);
    if (tile == null || av == null) {
      app.setCorner(id);
      setState(() {});
      return;
    }
    final spot = _cornerRect(av);
    if (app.eqCorner == id) {
      // 取消：角标飞回库里
      app.setCorner(id);
      setState(() => _hiddenItem = id);
      flyTo(
        context,
        from: spot,
        to: tile,
        child: CornerView(id: id, size: spot.width),
        onDone: () {
          if (mounted) setState(() => _hiddenItem = null);
        },
      );
      return;
    }
    final old = app.eqCorner;
    if (old != null) {
      final oldTile = globalRectOf(_tileKey(old));
      app.touchAvatar(() => app.eqCorner = null);
      if (oldTile != null) {
        flyTo(
          context,
          from: spot,
          to: oldTile,
          child: CornerView(id: old, size: spot.width),
        );
      }
    }
    setState(() => _hiddenItem = id);
    flyTo(
      context,
      from: tile,
      to: spot,
      child: CornerView(id: id, size: tile.width),
      onDone: () {
        app.setCorner(id);
        if (mounted) setState(() => _hiddenItem = null);
      },
    );
  }

  Widget _itemTile(Item it, bool on, VoidCallback tap) {
    final cs = Theme.of(context).colorScheme;
    final hidden = _hiddenItem == it.id;
    final preview = Opacity(
      opacity: hidden ? 0.0 : 1.0,
      child: it.kind == ItemKind.badge
          ? BadgeView(key: _tileKey(it.id), id: it.id, h: 18)
          : CornerView(key: _tileKey(it.id), id: it.id, size: 26),
    );
    return PressBox(
      color: on ? Color.lerp(cs.surfaceContainerHighest, app.primary, 0.5)! : cs.surfaceContainerHighest,
      r: 16,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      onTap: tap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          preview,
          const SizedBox(width: 8),
          Text(tr(it.name), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _wardrobe() {
    final cs = Theme.of(context).colorScheme;
    final badges = [
      for (final it in kItems)
        if (it.kind == ItemKind.badge && app.owns(it.id)) it
    ];
    final corners = [
      for (final it in kItems)
        if (it.kind == ItemKind.corner && app.owns(it.id)) it
    ];
    if (badges.isEmpty && corners.isEmpty) return const SizedBox.shrink();
    final small = TextStyle(fontSize: 12, color: cs.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('装扮'), style: const TextStyle(fontWeight: FontWeight.w700)),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(tr('徽标（可叠加，按佩戴顺序排在名字后面）'), style: small),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final it in badges)
                  _itemTile(it, app.eqBadges.contains(it.id), () => _tapBadge(it)),
              ],
            ),
          ],
          if (corners.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(tr('头像角标（一次只能戴一个）'), style: small),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final it in corners)
                  _itemTile(it, app.eqCorner == it.id, () => _tapCorner(it)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, int v, void Function(int) set) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: app.dev ? () => _editNum(label, v, set) : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: styled(cs.surfaceContainerHighest, r: app.cardR),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('$v',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ),
              ),
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
            Container(key: _avKey, child: const AvatarBox(size: 92)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameC,
                    onChanged: (v) => setState(() => app.quiet(() => app.name = v)),
                    decoration: InputDecoration(labelText: tr('名字'), isDense: true),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          app.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: BadgesRow(
                            key: _rowKey,
                            ids: List<String>.from(app.eqBadges),
                            h: 18,
                            keys: _wornKeys,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(tr('点击更换（来换一个可爱点的头像ᶻz ₍^_   ̫ _^₎喵...）'),
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AvatarDrawer(avatarKey: _avKey, onChanged: () {
          if (mounted) setState(() {});
        }),
        const SizedBox(height: 16),
        _wardrobe(),
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
              ? tr('设置生日（你的生日是什么时候啊？）')
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
        Text(tr('玩家数据记录（卸载后会清空，请注意导出数据备份）'), style: const TextStyle(fontWeight: FontWeight.w700)),
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
