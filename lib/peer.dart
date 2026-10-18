import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'net.dart';
import 'settings.dart';
import 'strings.dart';

class PeerInfo {
  final String name;
  final String uid;
  final Uint8List? avatar;
  final int border;
  const PeerInfo({this.name = '', this.uid = '', this.avatar, this.border = 0xFF26A69A});
}

Future<Map<String, dynamic>> buildHello() async {
  String? b64;
  final p = app.avatar;
  if (p != null) {
    try {
      final f = File(p);
      if (f.existsSync()) {
        final bytes = await f.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 96);
        final fr = await codec.getNextFrame();
        final data = await fr.image.toByteData(format: ui.ImageByteFormat.png);
        fr.image.dispose();
        codec.dispose();
        if (data != null) {
          b64 = base64Encode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        }
      }
    } catch (_) {}
  }
  return <String, dynamic>{
    'type': 'hello',
    'name': app.name,
    'uid': app.uid,
    'avatar': b64,
    'border': app.borderColor,
  };
}

PeerInfo? peerFromHello(Map<String, dynamic> m) {
  try {
    Uint8List? av;
    final a = m['avatar'];
    if (a is String && a.isNotEmpty) av = base64Decode(a);
    return PeerInfo(
      name: '${m['name'] ?? ''}',
      uid: '${m['uid'] ?? ''}',
      avatar: av,
      border: m['border'] is num ? (m['border'] as num).toInt() : 0xFF26A69A,
    );
  } catch (_) {
    return null;
  }
}

class PlayerBadge extends StatelessWidget {
  final String name;
  final String? file;
  final Uint8List? bytes;
  final int border;
  const PlayerBadge(
      {super.key, required this.name, this.file, this.bytes, required this.border});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    ImageProvider? img;
    if (bytes != null) {
      img = MemoryImage(bytes!);
    } else if (file != null && File(file!).existsSync()) {
      img = ResizeImage(FileImage(File(file!)), width: 160);
    }
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Color(border), width: 2.4),
              color: cs.surfaceContainerHighest,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7.5),
              child: img != null
                  ? Image(image: img, fit: BoxFit.cover, gaplessPlayback: true)
                  : Icon(Icons.person, color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 72,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class OpponentBadge extends StatefulWidget {
  final NetLink link;
  const OpponentBadge({super.key, required this.link});

  @override
  State<OpponentBadge> createState() => _OpponentBadgeState();
}

class _OpponentBadgeState extends State<OpponentBadge> {
  PeerInfo? p;

  @override
  void initState() {
    super.initState();
    final h = widget.link.hello;
    if (h != null) p = peerFromHello(h);
    widget.link.helloRev.addListener(_sync);
  }

  void _sync() {
    final h = widget.link.hello;
    if (h != null && mounted) setState(() => p = peerFromHello(h));
  }

  @override
  void dispose() {
    widget.link.helloRev.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = p;
    return PlayerBadge(
      name: (v == null || v.name.isEmpty) ? tr('对手') : v.name,
      bytes: v?.avatar,
      border: v?.border ?? 0xFF26A69A,
    );
  }
}

/// 左下角是自己，右上角是对手
List<Widget> onlineBadges(BuildContext context, NetLink link) {
  final pad = MediaQuery.paddingOf(context);
  return [
    Positioned(
      top: pad.top + kToolbarHeight + 2,
      right: 8,
      child: OpponentBadge(link: link),
    ),
    Positioned(
      bottom: pad.bottom + 8,
      left: 8,
      child: PlayerBadge(name: app.name, file: app.avatar, border: app.borderColor),
    ),
  ];
}
