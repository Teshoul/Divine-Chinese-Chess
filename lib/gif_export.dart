import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'avatar_model.dart';
import 'img_util.dart';

/// 导出头像用：把“带动图贴纸”的头像烘焙成 GIF 动图（保持原画质，最长边最大 1024）。

/// 这份编辑里有没有动图贴纸（GIF / 动态 WebP 等多帧图片）
Future<bool> editHasAnimatedSticker(Map<String, dynamic> editJson) async {
  final its = editJson['it'];
  if (its is! List) return false;
  for (final it in its) {
    if (it is! Map || it['k'] != 'sticker') continue;
    final p = it['i'];
    if (p is! String || isSvgPath(p) || !File(p).existsSync()) continue;
    try {
      final codec = await ui.instantiateImageCodec(await File(p).readAsBytes());
      final n = codec.frameCount;
      codec.dispose();
      if (n > 1) return true;
    } catch (_) {}
  }
  return false;
}

class _Frame {
  final ui.Image image;
  final int ms;
  _Frame(this.image, this.ms);
}

class _Src {
  final List<_Frame> frames;
  late final int total = frames.fold<int>(0, (a, f) => a + f.ms);
  _Src(this.frames);
  bool get animated => frames.length > 1;
  ui.Image at(int t) {
    if (frames.length == 1) return frames.first.image;
    var x = t % max(1, total);
    for (final f in frames) {
      if (x < f.ms) return f.image;
      x -= f.ms;
    }
    return frames.last.image;
  }

  void dispose() {
    for (final f in frames) {
      f.image.dispose();
    }
  }
}

Future<_Src?> _load(String path) async {
  try {
    if (isSvgPath(path) || !File(path).existsSync()) return null;
    final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
    final n = min(codec.frameCount, 300);
    final fr = <_Frame>[];
    for (var i = 0; i < n; i++) {
      final f = await codec.getNextFrame();
      var ms = f.duration.inMilliseconds;
      if (ms < 20) ms = 100;
      fr.add(_Frame(f.image, ms));
    }
    codec.dispose();
    if (fr.isEmpty) return null;
    return _Src(fr);
  } catch (_) {
    return null;
  }
}

Future<ui.Image> _renderFrame(
    AvatarEdit edit, _Src base, Map<int, _Src> stickers, int t, int side) async {
  final s = side.toDouble();
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, Rect.fromLTWH(0, 0, s, s));
  final full = Rect.fromLTWH(0, 0, s, s);
  c.clipRect(full);
  final cf = edit.colorFilter();
  if (cf != null) c.saveLayer(full, Paint()..colorFilter = cf);
  c.save();
  c.transform(edit.baseMatrix(s).storage);
  paintImage(
      canvas: c,
      rect: full,
      image: base.at(t),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high);
  c.restore();
  if (cf != null) c.restore();
  if (edit.strokes.isNotEmpty) StrokePainter(edit.strokes).paint(c, Size(s, s));
  for (var i = 0; i < edit.items.length; i++) {
    final it = edit.items[i];
    final sz = s * 0.26 * it.scale;
    final bw = it.kind == 'text' ? sz * 3 : sz;
    c.save();
    c.translate(it.x * s, it.y * s);
    c.rotate(it.rot * pi / 180);
    if (it.flip) c.scale(-1, 1);
    final r = Rect.fromLTWH(-bw / 2, -sz / 2, bw, sz);
    if (it.kind == 'sticker') {
      final src = stickers[i];
      if (src != null) {
        paintImage(
            canvas: c,
            rect: r,
            image: src.at(t),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high);
      }
    } else if (it.kind == 'text') {
      final col = Color(it.color);
      final tp = TextPainter(
        text: TextSpan(
          text: it.id,
          style: TextStyle(
            color: col,
            fontSize: 100,
            fontWeight: FontWeight.w900,
            height: 1.1,
            shadows: [
              Shadow(
                  color: col.computeLuminance() > 0.5 ? Colors.black54 : Colors.white54,
                  blurRadius: 3),
            ],
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      if (tp.width > 0 && tp.height > 0) {
        final k = min(bw / tp.width, sz / tp.height);
        c.save();
        c.scale(k, k);
        tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
        c.restore();
      }
    } else {
      c.translate(r.left, r.top);
      ShapePainter(it.id, Color(it.color)).paint(c, Size(bw, sz));
    }
    c.restore();
  }
  final pic = rec.endRecording();
  final img = await pic.toImage(side, side);
  pic.dispose();
  return img;
}

// ───────────── GIF 编码（在后台线程里做）─────────────

class _Enc {
  final Uint8List pal; // 256*3
  final Uint8List lzw; // 已经分好子块
  final bool transparent;
  _Enc(this.pal, this.lzw, this.transparent);
}

_Enc _encodeFrameJob(TransferableTypedData td, int side) {
  final rgba = td.materialize().asUint8List();
  final n = side * side;
  var hasTr = false;
  // 取样做中位切分
  final samples = <int>[];
  final step = max(1, n ~/ 20000);
  for (var i = 0; i < n; i++) {
    if (rgba[i * 4 + 3] < 128) {
      hasTr = true;
      continue;
    }
    if (i % step == 0) {
      samples.add((rgba[i * 4] << 16) | (rgba[i * 4 + 1] << 8) | rgba[i * 4 + 2]);
    }
  }
  final maxColors = hasTr ? 255 : 256;
  var boxes = <List<int>>[samples.isEmpty ? [0] : samples];
  while (boxes.length < maxColors) {
    var bi = -1, bScore = 0;
    for (var i = 0; i < boxes.length; i++) {
      final b = boxes[i];
      if (b.length < 2) continue;
      final sc = b.length;
      if (sc > bScore) {
        bScore = sc;
        bi = i;
      }
    }
    if (bi < 0) break;
    final b = boxes.removeAt(bi);
    var rmin = 255, rmax = 0, gmin = 255, gmax = 0, bmin = 255, bmax = 0;
    for (final v in b) {
      final r = v >> 16, g = (v >> 8) & 255, bb = v & 255;
      if (r < rmin) rmin = r;
      if (r > rmax) rmax = r;
      if (g < gmin) gmin = g;
      if (g > gmax) gmax = g;
      if (bb < bmin) bmin = bb;
      if (bb > bmax) bmax = bb;
    }
    final dr = rmax - rmin, dg = gmax - gmin, db = bmax - bmin;
    final shift = (dr >= dg && dr >= db) ? 16 : (dg >= db ? 8 : 0);
    b.sort((x, y) => ((x >> shift) & 255).compareTo((y >> shift) & 255));
    final mid = b.length ~/ 2;
    boxes.add(b.sublist(0, mid));
    boxes.add(b.sublist(mid));
  }
  final pal = Uint8List(768);
  final pr = <int>[], pg = <int>[], pb = <int>[];
  for (final b in boxes) {
    if (b.isEmpty) continue;
    var r = 0, g = 0, bb = 0;
    for (final v in b) {
      r += v >> 16;
      g += (v >> 8) & 255;
      bb += v & 255;
    }
    pr.add(r ~/ b.length);
    pg.add(g ~/ b.length);
    pb.add(bb ~/ b.length);
  }
  final pc = pr.length;
  for (var i = 0; i < pc; i++) {
    pal[i * 3] = pr[i];
    pal[i * 3 + 1] = pg[i];
    pal[i * 3 + 2] = pb[i];
  }
  // 15 位颜色 → 最近调色板编号
  final lut = Uint8List(32768);
  for (var k = 0; k < 32768; k++) {
    final r = ((k >> 10) << 3) + 4, g = (((k >> 5) & 31) << 3) + 4, b = ((k & 31) << 3) + 4;
    var best = 0, bd = 1 << 30;
    for (var i = 0; i < pc; i++) {
      final dr = pr[i] - r, dg = pg[i] - g, db = pb[i] - b;
      final d = dr * dr * 3 + dg * dg * 4 + db * db * 2;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    lut[k] = best;
  }
  final idx = Uint8List(n);
  for (var i = 0; i < n; i++) {
    if (rgba[i * 4 + 3] < 128) {
      idx[i] = 255;
    } else {
      idx[i] = lut[((rgba[i * 4] >> 3) << 10) | ((rgba[i * 4 + 1] >> 3) << 5) | (rgba[i * 4 + 2] >> 3)];
    }
  }
  return _Enc(pal, _lzw(idx), hasTr);
}

Uint8List _lzw(Uint8List data) {
  final out = BytesBuilder(copy: false);
  final blk = <int>[];
  void put(int b) {
    blk.add(b);
    if (blk.length == 255) {
      out.addByte(255);
      out.add(blk);
      blk.clear();
    }
  }

  out.addByte(8); // 最小码长
  var cur = 0, curBits = 0;
  var nBits = 9, maxcode = 511, free = 258;
  var clearFlag = false;
  void emit(int code) {
    cur |= code << curBits;
    curBits += nBits;
    while (curBits >= 8) {
      put(cur & 255);
      cur >>= 8;
      curBits -= 8;
    }
    if (clearFlag) {
      nBits = 9;
      maxcode = 511;
      clearFlag = false;
    } else if (free > maxcode && nBits < 12) {
      nBits++;
      maxcode = (1 << nBits) - 1;
    }
  }

  final dict = <int, int>{};
  emit(256);
  var ent = data[0];
  for (var i = 1; i < data.length; i++) {
    final c = data[i];
    final key = (ent << 8) | c;
    final v = dict[key];
    if (v != null) {
      ent = v;
      continue;
    }
    emit(ent);
    if (free < 4096) {
      dict[key] = free++;
    } else {
      dict.clear();
      free = 258;
      clearFlag = true;
      emit(256);
    }
    ent = c;
  }
  emit(ent);
  emit(257);
  if (curBits > 0) put(cur & 255);
  if (blk.isNotEmpty) {
    out.addByte(blk.length);
    out.add(blk);
  }
  out.addByte(0);
  return out.toBytes();
}

/// 把头像烘焙成 GIF，写到 outPath。成功返回 true；底图或贴纸读不了时返回 false（调用方保持原样导出）。
Future<bool> bakeAvatarGif(String path, Map<String, dynamic> editJson, String outPath) async {
  final edit = AvatarEdit.fromJson(editJson);
  final base = await _load(path);
  if (base == null) return false;
  final stickers = <int, _Src>{};
  final all = <_Src>[base];
  try {
    for (var i = 0; i < edit.items.length; i++) {
      final it = edit.items[i];
      if (it.kind != 'sticker') continue;
      final s = await _load(it.id);
      if (s != null) {
        stickers[i] = s;
        all.add(s);
      }
    }
    var dur = 0;
    for (final s in all) {
      if (s.animated) dur = max(dur, s.total);
    }
    if (dur <= 0) dur = 100;
    dur = min(dur, 12000);
    var stepMs = max(40, ((dur / 120) / 10).ceil() * 10);
    final frames = max(1, (dur / stepMs).ceil());
    final bi = base.frames.first.image;
    var side = max(bi.width, bi.height).clamp(256, 1024).toInt();
    side = min(side, sqrt(120e6 / frames).floor());
    side = max(128, side - side % 2);

    final b = BytesBuilder();
    b.add('GIF89a'.codeUnits);
    b.add([side & 255, side >> 8, side & 255, side >> 8, 0x70, 0, 0]);
    b.add([0x21, 0xFF, 0x0B, ...'NETSCAPE2.0'.codeUnits, 3, 1, 0, 0, 0]);
    final delay = max(2, (stepMs / 10).round());
    for (var f = 0; f < frames; f++) {
      final img = await _renderFrame(edit, base, stickers, f * stepMs, side);
      final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      if (bd == null) return false;
      final td = TransferableTypedData.fromList(
          [bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes)]);
      final e = await Isolate.run(() => _encodeFrameJob(td, side));
      b.add([0x21, 0xF9, 4, (2 << 2) | (e.transparent ? 1 : 0), delay & 255, delay >> 8, 255, 0]);
      b.add([0x2C, 0, 0, 0, 0, side & 255, side >> 8, side & 255, side >> 8, 0x87]);
      b.add(e.pal);
      b.add(e.lzw);
    }
    b.addByte(0x3B);
    await File(outPath).writeAsBytes(b.toBytes(), flush: true);
    return true;
  } finally {
    for (final s in all) {
      s.dispose();
    }
  }
}
