import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

const int kTcpPort = 45678;
const int kUdpPort = 45679;

class NetLink {
  final Socket socket;
  bool closed = false;
  Map<String, dynamic>? hello;
  final ValueNotifier<int> helloRev = ValueNotifier<int>(0);
  void Function(Map<String, dynamic>)? _handler;
  final List<Map<String, dynamic>> _backlog = [];

  NetLink(this.socket) {
    try {
      socket.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      try {
        final m = jsonDecode(line);
        if (m is Map) _emit(Map<String, dynamic>.from(m));
      } catch (_) {}
    }, onDone: _onClosed, onError: (_) => _onClosed());
  }

  set handler(void Function(Map<String, dynamic>)? h) {
    _handler = h;
    if (h != null && _backlog.isNotEmpty) {
      final items = List<Map<String, dynamic>>.from(_backlog);
      _backlog.clear();
      for (final m in items) {
        h(m);
      }
    }
  }

  
void _emit(Map<String, dynamic> m) {
  if (m['type'] == 'hello') {
    hello = m;
    helloRev.value++;
    return;
  }

  final h = _handler;
  if (h != null) {
    h(m);
  } else {
    _backlog.add(m);
  }
}

  void send(Map<String, dynamic> m) {
    if (closed) return;
    try {
      socket.write('${jsonEncode(m)}\n');
    } catch (_) {}
  }

  void _onClosed() {
    if (closed) return;
    closed = true;
    _emit({'type': 'closed'});
    try {
      socket.destroy();
    } catch (_) {}
  }

  void close() {
    closed = true;
    try {
      socket.destroy();
    } catch (_) {}
  }
}

Future<List<String>> localIps() async {
  final res = <String>[];
  try {
    final ifs = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false);
    for (final i in ifs) {
      for (final a in i.addresses) {
        res.add(a.address);
      }
    }
  } catch (_) {}
  return res;
}

class RoomHost {
  final String name;
  ServerSocket? _server;
  RawDatagramSocket? _udp;
  Timer? _timer;
  RoomHost(this.name);

  Future<void> start(void Function(NetLink) onClient) async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, kTcpPort,
        shared: true);
    _server!.listen((s) => onClient(NetLink(s)));
    _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _udp!.broadcastEnabled = true;
    final targets = <String>['255.255.255.255'];
    for (final ip in await localIps()) {
      final p = ip.split('.');
      if (p.length == 4) targets.add('${p[0]}.${p[1]}.${p[2]}.255');
    }
    final data = utf8.encode('CHESSROOM|$name');
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      for (final t in targets) {
        try {
          _udp?.send(data, InternetAddress(t), kUdpPort);
        } catch (_) {}
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _udp?.close();
    _server?.close();
  }
}

class RoomFinder {
  RawDatagramSocket? _sock;
  final Map<String, String> rooms = {};
  final Map<String, DateTime> _seen = {};

  Future<void> start(void Function() onChange) async {
    final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, kUdpPort,
        reuseAddress: true);
    _sock = s;
    s.listen((e) {
      if (e != RawSocketEvent.read) return;
      final d = s.receive();
      if (d == null) return;
      final txt = utf8.decode(d.data, allowMalformed: true);
      if (txt.startsWith('CHESSROOM|')) {
        final ip = d.address.address;
        final isNew = !rooms.containsKey(ip);
        rooms[ip] = txt.substring(10);
        _seen[ip] = DateTime.now();
        if (isNew) onChange();
      }
    });
  }

  bool prune() {
    final now = DateTime.now();
    final old = _seen.entries
        .where((e) => now.difference(e.value).inSeconds > 4)
        .map((e) => e.key)
        .toList();
    for (final k in old) {
      _seen.remove(k);
      rooms.remove(k);
    }
    return old.isNotEmpty;
  }

  void stop() {
    _sock?.close();
  }
}
