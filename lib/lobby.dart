import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'engine.dart';
import 'blind.dart';
import 'blind_page.dart';
import 'blind_setup.dart';
import 'net.dart';

class LobbyPage extends StatelessWidget {
  const LobbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('局域网对战')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: const Icon(Icons.add_home, size: 32),
              title: const Text('创建房间'),
              subtitle: const Text('当房主，选择模式和执红执黑'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HostPage())),
            ),
          ),
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: const Icon(Icons.login, size: 32),
              title: const Text('加入房间'),
              subtitle: const Text('搜索同一WiFi下的房间，或手动输入IP'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const JoinPage())),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('提示：两台手机要连同一个WiFi，或者一台开热点、另一台连上它。'),
          ),
        ],
      ),
    );
  }
}

class HostPage extends StatefulWidget {
  const HostPage({super.key});
  @override
  State<HostPage> createState() => _HostPageState();
}

class _HostPageState extends State<HostPage> {
  int mode = 1;
  int sideSel = 2;
  BlindConfig cfg = BlindConfig.kingsOnly();
  RoomHost? host;
  List<String> ips = [];
  bool waiting = false;
  bool handed = false;
  String? err;

  Future<void> create() async {
    setState(() => err = null);
    try {
      final ipList = await localIps();
      final h = RoomHost('象棋房间');
      await h.start(_onClient);
      host = h;
      if (mounted) {
        setState(() {
          ips = ipList;
          waiting = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => err = '创建失败：$e');
    }
  }

  void _onClient(NetLink link) {
    if (handed || !mounted) {
      link.close();
      return;
    }
    handed = true;
    host?.stop();
    final seed = Random().nextInt(1 << 30);
    final hostSide = sideSel == 0
        ? Side.red
        : sideSel == 1
            ? Side.black
            : (Random().nextBool() ? Side.red : Side.black);
    final c = mode == 0 ? BlindConfig.allUp() : cfg;
    final title = mode == 0 ? '标准对局' : '盲棋';
    link.send({
      'type': 'start',
      'cfg': c.toJson(),
      'seed': seed,
      'title': title,
      'hostSide': hostSide == Side.red ? 'red' : 'black',
    });
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => BlindPage(
                cfg: c,
                seed: seed,
                title: title,
                link: link,
                mySide: hostSide,
                isHost: true)));
  }

  @override
  void dispose() {
    if (!handed) host?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创建房间')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: waiting
            ? [
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 20),
                const Center(
                    child: Text('等待对方加入…', style: TextStyle(fontSize: 18))),
                const SizedBox(height: 12),
                Center(
                    child: Text('你的IP：${ips.isEmpty ? '未知' : ips.join(' / ')}',
                        textAlign: TextAlign.center)),
                const SizedBox(height: 6),
                const Center(child: Text('对方搜不到时，可让对方手动输入这个IP')),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () {
                    host?.stop();
                    host = null;
                    setState(() => waiting = false);
                  },
                  child: const Text('取消'),
                ),
              ]
            : [
                const Text('模式',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('标准')),
                    ButtonSegment(value: 1, label: Text('盲棋')),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) => setState(() => mode = s.first),
                ),
                if (mode == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('标准联机暂无将军提示，吃掉将/帅为胜。'),
                  ),
                if (mode == 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.tune),
                      label: const Text('设置盲棋规则'),
                      onPressed: () async {
                        final r = await Navigator.push<BlindConfig>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => BlindSetupPage(
                                    buttonText: '确定',
                                    initial: cfg,
                                    onConfirm: (ctx, c) =>
                                        Navigator.pop(ctx, c))));
                        if (r != null) setState(() => cfg = r);
                      },
                    ),
                  ),
                const SizedBox(height: 20),
                const Text('你执',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('红')),
                    ButtonSegment(value: 1, label: Text('黑')),
                    ButtonSegment(value: 2, label: Text('随机')),
                  ],
                  selected: {sideSel},
                  onSelectionChanged: (s) => setState(() => sideSel = s.first),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: create,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('创建房间', style: TextStyle(fontSize: 17)),
                  ),
                ),
                if (err != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(err!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
              ],
      ),
    );
  }
}

class JoinPage extends StatefulWidget {
  const JoinPage({super.key});
  @override
  State<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends State<JoinPage> {
  final finder = RoomFinder();
  final ipCtl = TextEditingController();
  Timer? timer;
  NetLink? pending;
  bool busy = false;
  bool handed = false;
  String? err;

  @override
  void initState() {
    super.initState();
    finder.start(() {
      if (mounted) setState(() {});
    }).catchError((_) {});
    timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (finder.prune() && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    finder.stop();
    ipCtl.dispose();
    if (!handed) pending?.close();
    super.dispose();
  }

  Future<void> connect(String ip) async {
    if (busy || ip.trim().isEmpty) return;
    setState(() {
      busy = true;
      err = null;
    });
    try {
      final s = await Socket.connect(ip.trim(), kTcpPort,
          timeout: const Duration(seconds: 5));
      final link = NetLink(s);
      pending = link;
      link.handler = (m) {
        if (m['type'] == 'start' && !handed) {
          handed = true;
          link.handler = null;
          if (!mounted) {
            link.close();
            return;
          }
          final cfg =
              BlindConfig.fromJson(Map<String, dynamic>.from(m['cfg'] as Map));
          final hostSide = m['hostSide'] == 'red' ? Side.red : Side.black;
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => BlindPage(
                      cfg: cfg,
                      seed: m['seed'] as int,
                      title: (m['title'] ?? '盲棋') as String,
                      link: link,
                      mySide: hostSide.other,
                      isHost: false)));
        } else if (m['type'] == 'closed') {
          if (mounted) {
            setState(() {
              busy = false;
              err = '房主已断开';
            });
          }
        }
      };
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = '连接失败，请确认在同一WiFi且IP正确';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rooms = finder.rooms.entries.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('加入房间')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('附近的房间',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (rooms.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('正在搜索同一WiFi下的房间…\n搜不到的话，可以在下面手动输入房主的IP。'),
            ),
          for (final e in rooms)
            Card(
              child: ListTile(
                leading: const Icon(Icons.wifi),
                title: Text(e.value),
                subtitle: Text(e.key),
                trailing: const Icon(Icons.chevron_right),
                onTap: busy ? null : () => connect(e.key),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: ipCtl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: '房主IP',
                hintText: '例如 192.168.1.5',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : () => connect(ipCtl.text),
            child: Text(busy ? '连接中…' : '连接'),
          ),
          if (err != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(err!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    );
  }
}
