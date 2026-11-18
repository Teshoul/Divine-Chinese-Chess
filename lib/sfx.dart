import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'sfx_data.dart';
import 'settings.dart';

/// 音效：普通按钮点击音 + 五档 AI 难度的专属音效
///
/// 音效数据内嵌在 sfx_data.dart 里，第一次启动时写到缓存目录再播放。
/// 播放时不抢系统音频焦点，所以不会打断音乐播放器。
class Sfx {
  static final Sfx I = Sfx._();
  Sfx._();

  final List<AudioPlayer> _clicks = <AudioPlayer>[];
  int _ci = 0;
  AudioPlayer? _lv;
  final Map<String, String> _paths = <String, String>{};
  AudioContext? _ctx;
  bool _started = false;
  bool _ready = false;

  Future<void> init() async {
    if (_started) return;
    _started = true;
    try {
      final tmp = await getTemporaryDirectory();
      final dir = Directory('${tmp.path}/sfx_v1');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      for (final e in kSfxData.entries) {
        final bytes = base64Decode(e.value.replaceAll(RegExp(r'\s'), ''));
        final f = File('${dir.path}/${e.key}.wav');
        if (!f.existsSync() || f.lengthSync() != bytes.length) {
          f.writeAsBytesSync(bytes, flush: true);
        }
        _paths[e.key] = f.path;
      }
      final ctx = AudioContext(
        android: AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.none,
        ),
      );
      _ctx = ctx;
      for (var i = 0; i < 3; i++) {
        final p = AudioPlayer();
        await p.setAudioContext(ctx);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setVolume(0.9);
        await p.setSource(DeviceFileSource(_paths['click']!));
        _clicks.add(p);
      }
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// 普通按钮：清脆的“咔哒”
  void click() {
    if (!_ready || !app.sfxOn || _clicks.isEmpty) return;
    final p = _clicks[_ci];
    _ci = (_ci + 1) % _clicks.length;
    _fire(() async {
      await p.seek(Duration.zero);
      await p.resume();
    });
  }

  /// AI 难度 0~4 的专属音效
  void level(int i) {
    if (!_ready || !app.sfxOn) return;
    final path = _paths['lv${i.clamp(0, 4).toInt()}'];
    if (path == null) return;
    _fire(() async {
      var p = _lv;
      if (p == null) {
        p = AudioPlayer();
        final c = _ctx;
        if (c != null) await p.setAudioContext(c);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setVolume(1.0);
        _lv = p;
      }
      await p.stop();
      await p.play(DeviceFileSource(path));
    });
  }

  void _fire(Future<void> Function() job) {
    job().catchError((Object _) {});
  }
}
