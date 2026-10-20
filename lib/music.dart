import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings.dart';
import 'strings.dart';
import 'ui.dart';

class Track {
  final String path;
  final String name;
  const Track(this.path, this.name);
}

class MusicService extends ChangeNotifier {
  static final MusicService I = MusicService._();
  MusicService._();

  AudioPlayer? _p;
  final List<Track> tracks = <Track>[];
  int index = -1;
  bool playing = false;
  PlayerState _state = PlayerState.stopped;
  Duration pos = Duration.zero;
  Duration dur = Duration.zero;
  int loop = 0; // 0 列表循环 1 单曲循环 2 顺序播放
  bool error = false;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    final p = AudioPlayer();
    _p = p;
    p.onPlayerStateChanged.listen((s) {
      _state = s;
      playing = s == PlayerState.playing;
      notifyListeners();
    });
    p.onPositionChanged.listen((d) {
      pos = d;
      notifyListeners();
    });
    p.onDurationChanged.listen((d) {
      dur = d;
      notifyListeners();
    });
    p.onPlayerComplete.listen((_) => _onComplete());
    try {
      final sp = await SharedPreferences.getInstance();
      final s = sp.getString('music_v1');
      if (s != null) {
        final m = jsonDecode(s) as Map<String, dynamic>;
        for (final e in (m['t'] as List)) {
          final t = Map<String, dynamic>.from(e as Map);
          final path = t['p'] as String;
          if (File(path).existsSync()) tracks.add(Track(path, t['n'] as String));
        }
        final l = m['l'];
        if (l is num) loop = l.toInt().clamp(0, 2).toInt();
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
        'music_v1',
        jsonEncode({
          't': [
            for (final t in tracks) {'p': t.path, 'n': t.name}
          ],
          'l': loop,
        }),
      );
    } catch (_) {}
  }

  Future<void> playAt(int i) async {
    final p = _p;
    if (p == null || i < 0 || i >= tracks.length) return;
    index = i;
    error = false;
    pos = Duration.zero;
    dur = Duration.zero;
    notifyListeners();
    try {
      await p.stop();
      await p.play(DeviceFileSource(tracks[i].path));
    } catch (_) {
      error = true;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    final p = _p;
    if (p == null || tracks.isEmpty) return;
    if (index < 0) {
      await playAt(0);
      return;
    }
    if (playing) {
      await p.pause();
    } else if (_state == PlayerState.paused) {
      await p.resume();
    } else {
      await playAt(index);
    }
  }

  Future<void> next() async {
    if (tracks.isEmpty) return;
    await playAt((index + 1) % tracks.length);
  }

  Future<void> prev() async {
    if (tracks.isEmpty) return;
    await playAt((index - 1 + tracks.length) % tracks.length);
  }

  Future<void> seek(Duration d) async {
    await _p?.seek(d);
  }

  void cycleLoop() {
    loop = (loop + 1) % 3;
    _save();
    notifyListeners();
  }

  void _onComplete() {
    if (loop == 1) {
      playAt(index);
    } else if (index + 1 < tracks.length) {
      playAt(index + 1);
    } else if (loop == 0 && tracks.isNotEmpty) {
      playAt(0);
    } else {
      playing = false;
      pos = Duration.zero;
      notifyListeners();
    }
  }

  Future<void> remove(int i) async {
    if (i < 0 || i >= tracks.length) return;
    final t = tracks.removeAt(i);
    try {
      File(t.path).deleteSync();
    } catch (_) {}
    if (i == index) {
      await _p?.stop();
      index = -1;
      pos = Duration.zero;
      dur = Duration.zero;
      playing = false;
    } else if (i < index) {
      index--;
    }
    await _save();
    notifyListeners();
  }

  Future<void> replaceAll(List<Track> list) async {
    await _p?.stop();
    tracks
      ..clear()
      ..addAll(list);
    index = -1;
    playing = false;
    pos = Duration.zero;
    dur = Duration.zero;
    await _save();
    notifyListeners();
  }
  Future<int> addFiles() async {
    await init();
    FilePickerResult? r;
    app.beginExternal();
    try {
      r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav'],
        allowMultiple: true,
      );
    } catch (_) {
      return 0;
    }
    if (r == null) return 0;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/music');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    var n = 0;
    for (final f in r.files) {
      final src = f.path;
      if (src == null) continue;
      try {
        final safe = f.name.replaceAll(RegExp(r'[^\w.\-]+'), '_');
        final dest = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_$safe';
        await File(src).copy(dest);
        tracks.add(Track(
            dest, f.name.replaceAll(RegExp(r'\.(mp3|wav)$', caseSensitive: false), '')));
        n++;
      } catch (_) {}
    }
    await _save();
    notifyListeners();
    return n;
  }
}

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});
  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final m = MusicService.I;

  @override
  void initState() {
    super.initState();
    m.init();
  }

  String _fmt(Duration d) {
    final s = d.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _add() async {
    final n = await m.addFiles();
    if (!mounted || n <= 0) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(trf('已添加 {n} 首', {'n': '$n'}))));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('音乐播放器'))),
      body: AnimatedBuilder(
        animation: m,
        builder: (context, _) {
          final cur = (m.index >= 0 && m.index < m.tracks.length) ? m.tracks[m.index] : null;
          final maxMs = max(m.dur.inMilliseconds, 1).toDouble();
          final v = m.pos.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
          final loopIcon = const [Icons.repeat, Icons.repeat_one, Icons.trending_flat][m.loop];
          final loopName = const ['列表循环', '单曲循环', '顺序播放'][m.loop];
          final empty = m.tracks.isEmpty;
          return Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                padding: const EdgeInsets.all(16),
                decoration: styled(cs.surfaceContainerHigh, r: app.cardR),
                child: Column(
                  children: [
                    Icon(m.playing ? Icons.graphic_eq : Icons.music_note,
                        size: 40, color: app.primary),
                    const SizedBox(height: 8),
                    Text(cur?.name ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    if (m.error)
                      Text(tr('没办法播放该文件ᯠ˶｡  ̫`｡˶ᯄ੭'), style: TextStyle(color: cs.error)),
                    Slider(
                      value: v,
                      min: 0,
                      max: maxMs,
                      onChanged: cur == null
                          ? null
                          : (x) => m.seek(Duration(milliseconds: x.toInt())),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text(_fmt(m.pos)), Text(_fmt(m.dur))],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        LitButton(icon: loopIcon, label: tr(loopName), onTap: m.cycleLoop),
                        LitButton(
                            icon: Icons.skip_previous,
                            label: tr('上一首'),
                            onTap: empty ? null : m.prev),
                        LitButton(
                            icon: m.playing ? Icons.pause : Icons.play_arrow,
                            label: tr(m.playing ? '暂停' : '播放'),
                            onTap: empty ? null : m.toggle),
                        LitButton(
                            icon: Icons.skip_next,
                            label: tr('下一首'),
                            onTap: empty ? null : m.next),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.library_add),
                    label: Text(tr('添加音频')),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: empty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(tr('暂无音乐，点击“添加音频”导入 MP3 / WAV'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: cs.onSurfaceVariant)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: m.tracks.length,
                        itemBuilder: (c, i) {
                          final t = m.tracks[i];
                          final sel = i == m.index;
                          final ink = sel ? inkOn(app.primary) : cs.onSurface;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap: () => m.playAt(i),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                                decoration: styled(
                                    sel ? app.primary : cs.surfaceContainerHigh,
                                    r: app.btnR + 4),
                                child: Row(
                                  children: [
                                    Icon(
                                        sel && m.playing
                                            ? Icons.graphic_eq
                                            : Icons.music_note,
                                        color: ink),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(t.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: ink, fontWeight: FontWeight.w600)),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: ink),
                                      onPressed: () => m.remove(i),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
