import 'dart:math';
import 'package:flutter/material.dart';
import 'music.dart';
import 'settings.dart';
import 'strings.dart';

/// 对局里的迷你音乐播放器：一个很小的胶囊（播放 / 暂停 + 列表），放在界面的空白处；
/// 点列表按钮会把播放列表拉出来，可以切歌、拖进度、切换循环方式。
/// 位置在 设置 → 局内音乐 里选，放进对局页的 Stack 最上层即可。
class InGameMusic extends StatefulWidget {
  final bool online;
  const InGameMusic({super.key, this.online = false});

  @override
  State<InGameMusic> createState() => _InGameMusicState();
}

class _InGameMusicState extends State<InGameMusic> with SingleTickerProviderStateMixin {
  final MusicService m = MusicService.I;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _a = CurvedAnimation(
      parent: _c, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
  bool _open = false;

  @override
  void initState() {
    super.initState();
    m.init();
  }

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

  String _fmt(Duration d) {
    final s = d.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Widget _mini(IconData icon, VoidCallback? onTap, {double size = 18, Color? color}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 30,
        height: 30,
        child: Icon(icon, size: size, color: color),
      ),
    );
  }

  Widget _pill(ColorScheme cs) {
    final ink = cs.onSurface;
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.74),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: cs.outline.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _mini(m.playing ? Icons.pause : Icons.play_arrow, () {
            if (m.tracks.isEmpty) {
              if (!_open) _toggle();
            } else {
              m.toggle();
            }
          }, color: m.playing ? app.primary : ink),
          Container(width: 1, height: 14, color: cs.outline.withOpacity(0.4)),
          _mini(_open ? Icons.expand_less : Icons.queue_music, _toggle, color: ink),
        ],
      ),
    );
  }

  Widget _panel(ColorScheme cs, double width) {
    final cur = (m.index >= 0 && m.index < m.tracks.length) ? m.tracks[m.index] : null;
    final maxMs = max(m.dur.inMilliseconds, 1).toDouble();
    final v = m.pos.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
    final loopIcon = const [Icons.repeat, Icons.repeat_one, Icons.trending_flat][m.loop];
    return Material(
      color: cs.surfaceContainerHigh.withOpacity(0.97),
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(m.playing ? Icons.graphic_eq : Icons.music_note, size: 16, color: app.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    cur?.name ?? tr('未播放'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (m.error)
              Text(tr('无法播放该文件'), style: TextStyle(color: cs.error, fontSize: 11)),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: v,
                min: 0,
                max: maxMs,
                onChanged: cur == null ? null : (x) => m.seek(Duration(milliseconds: x.toInt())),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(m.pos), style: const TextStyle(fontSize: 10)),
                Text(_fmt(m.dur), style: const TextStyle(fontSize: 10)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _mini(loopIcon, m.cycleLoop),
                _mini(Icons.skip_previous, m.tracks.isEmpty ? null : m.prev, size: 22),
                _mini(m.playing ? Icons.pause_circle : Icons.play_circle,
                    m.tracks.isEmpty ? null : m.toggle,
                    size: 28, color: app.primary),
                _mini(Icons.skip_next, m.tracks.isEmpty ? null : m.next, size: 22),
                _mini(Icons.library_add, () async {
                  await m.addFiles();
                }),
              ],
            ),
            const Divider(height: 10),
            if (m.tracks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(tr('暂无音乐，点上面的“添加”按钮导入 MP3 / WAV'),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 168),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: m.tracks.length,
                  itemBuilder: (c, i) {
                    final sel = i == m.index;
                    return InkWell(
                      onTap: () => m.playAt(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                        child: Row(
                          children: [
                            Icon(sel && m.playing ? Icons.graphic_eq : Icons.music_note,
                                size: 15, color: sel ? app.primary : cs.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                m.tracks[i].name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                                  color: sel ? app.primary : cs.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[app, m, _c]),
      builder: (context, _) {
        if (!app.gameMusic) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final mq = MediaQuery.of(context);
        var pos = app.gameMusicPos;
        if (widget.online && pos == 2) pos = 1; // 右上角是对手头像，改放左边
        final right = pos != 1;
        final top = pos == 0
            ? mq.padding.top + (kToolbarHeight - 30) / 2
            : mq.padding.top + kToolbarHeight + 7;
        final pw = min(280.0, mq.size.width - 16);
        final showPanel = _open || !_c.isDismissed;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (_open)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  child: const SizedBox.expand(),
                ),
              ),
            Positioned(
              top: top,
              left: right ? null : 8,
              right: right ? 8 : null,
              child: _pill(cs),
            ),
            if (showPanel)
              Positioned(
                top: top + 36,
                left: right ? null : 8,
                right: right ? 8 : null,
                child: FadeTransition(
                  opacity: _a,
                  child: SizeTransition(
                    sizeFactor: _a,
                    axisAlignment: -1,
                    child: _panel(cs, pw),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
