import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'games.dart';
import 'match_info.dart';
import 'net.dart';
import 'ui.dart';

class LobbyPage extends StatelessWidget {
  const LobbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('局域网对战')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PressCard(
            color: const Color(0xFF00897B),
            icon: Icons.add_home,
            title: '创建房间',
            sub: '选择游戏与先后手，等待对方加入',
            onTap: () => Navigator.push(context, fadeRoute(const HostPage())),
          ),
          const SizedBox(height: 14),
          PressCard(
            color: const Color(0xFF3949AB),
            icon: Icons.login,
            title: '加入房间',
            sub: '搜索同一WiFi下的房间，或手动输入IP',
            onTap: () => Navigator.push(context, fadeRoute(const JoinPage())),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
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
  GameDef game = onlineGames.first;
  Map<String, dynamic>? params;
  int order = 2;
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
    final hostFirst =
        order == 0 ? true : (order == 1 ? false : Random().nextBool());
    final p = params ?? game.defaultParams();
    link.send({
      'type': 'start',
      'game': game.id,
      'params': p,
      'seed': seed,
      'hostFirst': hostFirst,
    });
    Navigator.pushReplacement(
        context,
        fadeRoute(game.buildOnline(MatchInfo(
            link: link,
            isHost: true,
            first: hostFirst,
            seed: seed,
            params: p))));
  }

  @override
  void dispose() {
    if (!handed) host?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
    return Scaffold(
      appBar: AppBar(title: const Text('创建房间')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: waiting
            ? [
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 20),
                Center(
                    child: Text('等待对方加入「${game.name}」…',
                        style: const TextStyle(fontSize: 18))),
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
                const Text('选择游戏', style: head),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in onlineGames)
                      ChoiceChip(
                        avatar: Icon(g.icon, size: 18),
                        label: Text(g.name),
                        selected: g.id == game.id,
                        onSelected: (_) => setState(() {
                          game = g;
                          params = null;
                        }),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(game.desc),
                ),
                if (game.setup != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.tune),
                    label: Text(params == null ? '设置规则（当前默认）' : '规则已自定义，点击修改'),
                    onPressed: () async {
                      final r = await game.setup!(context);
                      if (r != null && mounted) setState(() => params = r);
                    },
                  ),
                const SizedBox(height: 20),
                const Text('你的先后手', style: head),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('先手')),
                    ButtonSegment(value: 1, label: Text('后手')),
                    ButtonSegment(value: 2, label: Text('随机')),
                  ],
                  selected: {order},
                  onSelectionChanged: (s) => setState(() => order = s.first),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('象棋类游戏中，先手执红。'),
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
      link.handler = (msg) {
        if (msg['type'] == 'start' && !handed) {
          final g = findGame((msg['game'] ?? '') as String);
          if (g == null) {
            link.close();
            if (mounted) {
              setState(() {
                busy = false;
                err = '找不到房主选的游戏，请两边都更新到最新版';
              });
            }
            return;
          }
          handed = true;
          link.handler = null;
          if (!mounted) {
            link.close();
            return;
          }
          final p = Map<String, dynamic>.from(msg['params'] as Map);
          final hostFirst = msg['hostFirst'] as bool;
          Navigator.pushReplacement(
              context,
              fadeRoute(g.buildOnline(MatchInfo(
                  link: link,
                  isHost: false,
                  first: !hostFirst,
                  seed: msg['seed'] as int,
                  params: p))));
        } else if (msg['type'] == 'closed') {
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
