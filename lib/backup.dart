import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'music.dart';
import 'settings.dart';
import 'strings.dart';

String _ext(String p) {
  final i = p.lastIndexOf('.');
  if (i < 0 || p.length - i > 6) return '';
  return p.substring(i).toLowerCase();
}

String _defaultName() {
  final n = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return 'Divine-Chess-${n.year}${two(n.month)}${two(n.day)}';
}

// ───────── 在后台线程里做重活，界面不会卡死 ─────────

String _zipJob(String out, List<List<String>> pairs, String body, String sig) {
  final ar = Archive();
  for (final p in pairs) {
    final bytes = File(p[0]).readAsBytesSync();
    final f = ArchiveFile(p[1], bytes.length, bytes);
    f.compress = false; // 音频和图片本来就压缩过，直接存储，速度快很多
    ar.addFile(f);
  }
  final bb = utf8.encode(body);
  ar.addFile(ArchiveFile('data.json', bb.length, bb));
  final sg = utf8.encode(sig);
  ar.addFile(ArchiveFile('sig.txt', sg.length, sg));
  final data = ZipEncoder().encode(ar);
  if (data == null) throw StateError('zip failed');
  File(out).writeAsBytesSync(data, flush: true);
  return out;
}

Future<String> _zipInIsolate(
    String out, List<List<String>> pairs, String body, String sig) {
  return Isolate.run(() => _zipJob(out, pairs, body, sig));
}

Map<String, Object> _unzipJob(String zipPath, String docs, String music, int stamp) {
  final bytes = File(zipPath).readAsBytesSync();
  final ar = ZipDecoder().decodeBytes(bytes);
  var body = '';
  var sig = '';
  final files = <String, String>{};
  for (final e in ar) {
    if (!e.isFile) continue;
    final name = e.name;
    final data = e.content as List<int>;
    if (name == 'data.json') {
      body = utf8.decode(data);
      continue;
    }
    if (name == 'sig.txt') {
      sig = utf8.decode(data).trim();
      continue;
    }
    final isMusic = name.startsWith('music/');
    if (!isMusic && !name.startsWith('files/')) continue;
    final base = name.split('/').last.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final dir = isMusic ? music : docs;
    Directory(dir).createSync(recursive: true);
    final dest = '$dir/imp_${stamp}_$base';
    File(dest).writeAsBytesSync(data);
    files[name] = dest;
  }
  return <String, Object>{'body': body, 'sig': sig, 'files': files};
}

Future<Map<String, Object>> _unzipInIsolate(
    String zipPath, String docs, String music, int stamp) {
  return Isolate.run(() => _unzipJob(zipPath, docs, music, stamp));
}

// ───────── 进度提示 ─────────

void _showBusy(BuildContext context, String msg) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(
                width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 16),
            Expanded(child: Text(msg)),
          ],
        ),
      ),
    ),
  );
}

void _hideBusy(BuildContext context) {
  if (context.mounted) Navigator.of(context).pop();
}

// ───────── 导出 ─────────

/// 返回 'ok' | 'cancel' | 'fail:原因'
Future<String> exportBackup(BuildContext context) async {
  final ctl = TextEditingController(text: _defaultName());
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('导出数据')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('给备份压缩包起个名字（可随时再改）')),
          const SizedBox(height: 10),
          TextField(
            controller: ctl,
            autofocus: true,
            decoration: const InputDecoration(suffixText: '.zip', isDense: true),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('取消'))),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: Text(tr('保存'))),
      ],
    ),
  );
  if (name == null) return 'cancel';
  if (!context.mounted) return 'cancel';
  var safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  if (safe.isEmpty) safe = _defaultName();

  _showBusy(context, tr('正在打包备份，请稍候…'));
  String? tmp;
  Uint8List? bytes;
  try {
    await MusicService.I.init();
    final snap = app.exportMap();
    final pairs = <List<String>>[];
    final done = <String, String>{};
    var n = 0;
    String? put(String? path, String dir) {
      if (path == null || path.startsWith('builtin:')) return path;
      final old = done[path];
      if (old != null) return old;
      if (!File(path).existsSync()) return null;
      final entry = '$dir/${n++}${_ext(path)}';
      pairs.add([path, entry]);
      done[path] = entry;
      return entry;
    }

    snap['avatar'] = put(snap['avatar'] as String?, 'files');
    final list = <String>[];
    final avs = snap['avatars'];
    if (avs is List) {
      for (final p in avs) {
        final e = put(p as String?, 'files');
        if (e != null) list.add(e);
      }
    }
    snap['avatars'] = list;
    final ly = snap['layers'];
    if (ly is Map) {
      for (final k in ly.keys.toList()) {
        final v = ly[k];
        if (v is Map) v['path'] = put(v['path'] as String?, 'files');
      }
    }
    final music = <Map<String, dynamic>>[];
    for (final t in MusicService.I.tracks) {
      final e = put(t.path, 'music');
      if (e != null) music.add({'e': e, 'n': t.name});
    }
    snap['music'] = music;

    final body = jsonEncode(snap);
    final sig = signText(body);
    final cache = await getTemporaryDirectory();
    final out = '${cache.path}/backup_${DateTime.now().millisecondsSinceEpoch}.zip';
    tmp = await _zipInIsolate(out, pairs, body, sig);
    bytes = await File(tmp).readAsBytes();
  } catch (e) {
    _hideBusy(context);
    return 'fail:$e';
  }
  _hideBusy(context);

  try {
    app.beginExternal();
    final path = await FilePicker.platform.saveFile(
      dialogTitle: tr('保存备份'),
      fileName: '$safe.zip',
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    return path == null ? 'cancel' : 'ok';
  } catch (e) {
    return 'fail:$e';
  } finally {
    try {
      if (tmp != null) File(tmp).deleteSync();
    } catch (_) {}
    try {
      await FilePicker.platform.clearTemporaryFiles();
    } catch (_) {}
  }
}

// ───────── 导入 ─────────

/// 返回 'ok' | 'cancel' | 'sig' | 'bad:原因'
Future<String> importBackup(BuildContext context) async {
  app.beginExternal();
  FilePickerResult? r;
  try {
    r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: false,
    );
  } catch (e) {
    return 'bad:$e';
  }
  if (r == null || r.files.isEmpty) return 'cancel';
  final zipPath = r.files.first.path;
  if (zipPath == null) return 'bad:无法读取所选文件';
  if (!context.mounted) return 'cancel';

  _showBusy(context, tr('正在导入，请稍候…'));
  try {
    final docs = (await getApplicationDocumentsDirectory()).path;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final res = await _unzipInIsolate(zipPath, docs, '$docs/music', stamp);
    final body = res['body'] as String;
    final sig = res['sig'] as String;
    if (body.isEmpty || sig.isEmpty) return 'bad:压缩包里缺少数据文件';
    if (signText(body) != sig) return 'sig';
    final files = Map<String, String>.from(res['files'] as Map);

    final x = jsonDecode(body);
    if (x is! Map) return 'bad:数据格式不对';
    final m = Map<String, dynamic>.from(x);

    String? mp(dynamic v) =>
        v is String ? (files[v] ?? (v.startsWith('builtin:') ? v : null)) : null;
    m['avatar'] = mp(m['avatar']);
    final av = <String>[];
    final avl = m['avatars'];
    if (avl is List) {
      for (final e in avl) {
        final p = mp(e);
        if (p != null) av.add(p);
      }
    }
    m['avatars'] = av;
    final ly = m['layers'];
    if (ly is Map) {
      for (final k in ly.keys.toList()) {
        final v = ly[k];
        if (v is Map) v['path'] = mp(v['path']);
      }
    }
    final tracks = <Track>[];
    final ml = m['music'];
    if (ml is List) {
      for (final e in ml) {
        if (e is Map) {
          final p = mp(e['e']);
          if (p != null) tracks.add(Track(p, '${e['n'] ?? ''}'));
        }
      }
    }
    app.importMap(m);
    await MusicService.I.init();
    await MusicService.I.replaceAll(tracks);
    return 'ok';
  } catch (e) {
    return 'bad:$e';
  } finally {
    _hideBusy(context);
    try {
      await FilePicker.platform.clearTemporaryFiles();
    } catch (_) {}
  }
}
