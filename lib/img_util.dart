import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'settings.dart';
import 'strings.dart';

bool isSvgPath(String p) => p.toLowerCase().endsWith('.svg');

/// 显示本地图片：普通图片 / GIF / WebP 用 Image，SVG 用 flutter_svg
Widget imageFileWidget(
  String path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  int? cacheWidth,
}) {
  final f = File(path);
  if (isSvgPath(path)) {
    return SvgPicture.file(f, fit: fit, width: width, height: height);
  }
  return Image.file(
    f,
    fit: fit,
    width: width,
    height: height,
    cacheWidth: cacheWidth,
    gaplessPlayback: true,
    errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
  );
}

Size? _svgSize(String t) {
  final vb = RegExp(r'viewBox\s*=\s*"([^"]+)"', caseSensitive: false).firstMatch(t);
  if (vb != null) {
    final n = vb.group(1)!.trim().split(RegExp(r'[\s,]+')).map(double.tryParse).toList();
    if (n.length == 4) {
      final w = n[2], h = n[3];
      if (w != null && h != null && w > 0 && h > 0) return Size(w, h);
    }
  }
  final wm = RegExp(r'<svg[^>]*?\swidth\s*=\s*"([0-9.]+)', caseSensitive: false).firstMatch(t);
  final hm = RegExp(r'<svg[^>]*?\sheight\s*=\s*"([0-9.]+)', caseSensitive: false).firstMatch(t);
  if (wm != null && hm != null) {
    final w = double.tryParse(wm.group(1)!);
    final h = double.tryParse(hm.group(1)!);
    if (w != null && h != null && w > 0 && h > 0) return Size(w, h);
  }
  return null;
}

/// 读取图片原始宽高（不解码整张图）
Future<Size?> imageNaturalSize(String path) async {
  try {
    if (isSvgPath(path)) {
      return _svgSize(await File(path).readAsString());
    }
    final bytes = await File(path).readAsBytes();
    final buf = await ui.ImmutableBuffer.fromUint8List(bytes);
    final d = await ui.ImageDescriptor.encoded(buf);
    final s = Size(d.width.toDouble(), d.height.toDouble());
    d.dispose();
    buf.dispose();
    return s;
  } catch (_) {
    return null;
  }
}

/// 选图来源：相册，或系统文件（可以选到 SVG）
Future<String?> pickImageChoose(BuildContext context) async {
  final choice = await showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: Text(tr('从相册选择')),
            onTap: () => Navigator.pop(ctx, 0),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: Text(tr('从文件选择（支持 SVG / GIF / WebP）')),
            onTap: () => Navigator.pop(ctx, 1),
          ),
        ],
      ),
    ),
  );
  if (choice == null) return null;
  return choice == 0 ? pickImage() : pickImageFile();
}
