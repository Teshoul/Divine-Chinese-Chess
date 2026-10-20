import 'dart:convert';
import 'dart:io';
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

Future<Uint8List> buildBackupZip() async {
  await MusicService.I.init();
  final snap = app.exportMap();
  final ar = Archive();
  final done = <String, String>{};
  var n = 0;

  Future<String?> put(String? path, String dir) async {
    if (path == null || path.startsWith('builtin:')) return path;
    final old = done[path];
    if (old != null) return old;
    final f = File(path);
    if (!f.existsSync()) return null;
    final bytes = await f.readAsBytes();
    final entry = '$dir/${n++}${_ext(path)}';
    ar.addFile(ArchiveFile(entry, bytes.length, bytes));
    done[path] = entry;
    return entry;
  }

  snap['avatar'] = await put(snap['avatar'] as String?, 'files');
  final list = <String>[];
  for (final p in (snap['avatars'] as List)) {
    final e = await put(p as String?, 'files');
    if (e != null) list.add(e);
  }
  snap['avatars'] = list;
  final ly = snap['layers'];
  if (ly is Map) {
    for (final k in ly.keys.toList()) {
      final v = ly[k];
      if (v is Map) v['path'] = await put(v['path'] as String?, 'files');
    }
  }
  final music = <Map<String, dynamic>>[];
  for (final t in MusicService.I.tracks) {
    final e = await put(t.path, 'music');
    if (e != null) music.add({'e': e, 'n': t.name});
  }
  snap['music'] = music;

  final body = jsonEncode(snap);
  final bb = utf8.encode(body);
  ar.addFile(ArchiveFile('data.json', bb.length, bb));
  final sg = utf8.encode(signText(body));
  ar.addFile(ArchiveFile('sig.txt', sg.length, sg));
  final out = ZipEncoder().encode(ar);
  return Uint8List.fromList(out ?? <int>[]);
}

/// 返回 'ok' | 'cancel' | 'fail'
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
          Text(tr('给备份压缩包起个名字，方便你找到他(៸៸᳐⦁⩊⦁៸៸᳐ )੭（可随时再改）')),
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
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: Text(tr('保存'))),
      ],
    ),
  );
  if (name == null) return 'cancel';
  var safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  if (safe.isEmpty) safe = _defaultName();
  try {
    final bytes = await buildBackupZip();
    app.beginExternal();
    final path = await FilePicker.platform.saveFile(
      dialogTitle: tr('保存备份'),
      fileName: '$safe.zip',
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    return path == null ? 'cancel' : 'ok';
  } catch (_) {
    return 'fail';
  }
}

/// 返回 'ok' | 'cancel' | 'sig' | 'bad'
Future<String> importBackup() async {
  app.beginExternal();
  FilePickerResult? r;
  try {
    r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
  } catch (_) {
    return 'bad';
  }
  if (r == null || r.files.isEmpty) return 'cancel';
  final pf = r.files.first;
  Uint8List? bytes = pf.bytes;
  if (bytes == null && pf.path != null) {
    try {
      bytes = await File(pf.path!).readAsBytes();
    } catch (_) {}
  }
  if (bytes == null) return 'bad';

  Archive ar;
  try {
    ar = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    return 'bad';
  }
  ArchiveFile? data, sig;
  for (final e in ar) {
    if (e.name == 'data.json') data = e;
    if (e.name == 'sig.txt') sig = e;
  }
  if (data == null || sig == null) return 'bad';
  String body = '';
  try {
    body = utf8.decode(data.content as List<int>);
    if (signText(body) != utf8.decode(sig.content as List<int>).trim()) return 'sig';
  } catch (_) {
    return 'bad';
  }
  Map<String, dynamic> m;
  try {
    final x = jsonDecode(body);
    if (x is! Map) return 'bad';
    m = Map<String, dynamic>.from(x);
  } catch (_) {
    return 'bad';
  }

  final dir = await getApplicationDocumentsDirectory();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final out = <String, String>{};
  for (final e in ar) {
    if (!e.isFile) continue;
    final isMusic = e.name.startsWith('music/');
    if (!isMusic && !e.name.startsWith('files/')) continue;
    final base = e.name.split('/').last.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final d = Directory(isMusic ? '${dir.path}/music' : dir.path);
    if (!d.existsSync()) d.createSync(recursive: true);
    final dest = '${d.path}/imp_${stamp}_$base';
    try {
      await File(dest).writeAsBytes(e.content as List<int>);
      out[e.name] = dest;
    } catch (_) {}
  }

  String? mp(dynamic v) =>
      v is String ? (out[v] ?? (v.startsWith('builtin:') ? v : null)) : null;
  m['avatar'] = mp(m['avatar']);
  final av = <String>[];
  final avl = m['avatars'];
  if (avl is List) {
    for (final x in avl) {
      final p = mp(x);
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
    for (final x in ml) {
      if (x is Map) {
        final p = mp(x['e']);
        if (p != null) tracks.add(Track(p, '${x['n'] ?? ''}'));
      }
    }
  }
  try {
    app.importMap(m);
    await MusicService.I.init();
    await MusicService.I.replaceAll(tracks);
  } catch (_) {
    return 'bad';
  }
  return 'ok';
}
