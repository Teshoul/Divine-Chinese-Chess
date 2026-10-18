import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'games.dart';
import 'match_info.dart';
import 'net.dart';
import 'peer.dart';
import 'settings.dart';
import 'strings.dart';
import 'ui.dart';

class LobbyPage extends StatelessWidget {
  const LobbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = app.preset.tiles;
    return Scaffold(
      appBar: AppBar(title: Text(tr('局域网对战'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PressCard(
            color: t[0],
            icon: Icons.add_home,
            title: tr('创建房间'),
            sub: tr('选择游戏与先后手，等待对方加入'),
            onTap: () => Navigator.push(context, fadeRoute(const HostPage())),
          ),
          const SizedBox(height: 14),
          PressCard(
            color: t[3],
            icon: Icons.login,
            title: tr('加入房间'),
            sub: tr('搜索同一WiFi下的房间，或手动输入IP'),
            onTap: () => Navigator.push(context, fadeRoute(const JoinPage())),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(tr('提示：两台手机要连同一个WiFi，或者一台开热点、另一台连上它。')),
          ),
        ],
      ),
    );
  }
}

Widget _head(String zh) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(tr(zh), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    );

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
      final h = RoomHost(app.name);
      await h.start(_onClient);
      host = h;
      if (mounted) {
        setState(() {
          ips = ipList;
          waiting = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => err = trf('创建失败：{e}', {'e': '$e'}));
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
    final hostFirst = order == 0 ? true : (order == 1 ? false : Random().nextBool());
    final p = params ?? game.defaultParams();
    link.send({
      'type': 'start',
      'game': game.id,
      'params': p,
      'seed': seed,
      'hostFirst': hostFirst,
    });
    buildHello().then(link.send);
    Navigator.pushReplacement(
      context,
      fadeRoute(game.buildOnline(MatchInfo(
        link: link,
        isHost: true,
        first: hostFirst,
        seed: seed,
        params: p,
      ))),
    );
  }

  @override
  void dispose() {
    if (!handed) host?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('创建房间'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: waiting
            ? [
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: styled(cs.surfaceContainerHigh, r: app.cardR),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(trf('等待对方加入「{g}」…', {'g': tr(game.name)}),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 12),
                      Text(
                          trf('你的IP：{x}', {'x': ips.isEmpty ? tr('未知') : ips.join(' / ')}),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      Text(tr('对方搜不到时，可让对方手动输入这个IP'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () {
                    host?.stop();
                    host = null;
                    setState(() => waiting = false);
                  },
                  child: Text(tr('取消')),
                ),
              ]
            : [
                _head('选择游戏'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in onlineGames)
                      LitToggle(
                        wide: true,
                        icon: g.icon,
                        label: tr(g.name),
                        value: g.id == game.id,
                        onChanged: (_) => setState(() {
                          game = g;
                          params = null;
                        }),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 8),
                  child: Text(tr(game.desc), style: TextStyle(color: cs.onSurfaceVariant)),
                ),
                if (game.setup != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.tune),
                    label: Text(tr(params == null ? '设置规则（当前默认）' : '规则已自定义，点击修改')),
                    onPressed: () async {
                      final r = await game.setup!(context);
                      if (r != null && mounted) setState(() => params = r);
                    },
                  ),
                _head('你的先后手'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < 3; i++)
                      LitToggle(
                        wide: true,
                        label: tr(const ['先手', '后手', '随机'][i]),
                        value: order == i,
                        onChanged: (_) => setState(() => order = i),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(tr('象棋类游戏中，先手执红。'),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: create,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(tr('创建房间'), style: const TextStyle(fontSize: 17)),
                  ),
                ),
                if (err != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(err!, style: TextStyle(color: cs.error)),
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
      buildHello().then(link.send);
      link.handler = (msg) {
        if (msg['type'] == 'start' && !handed) {
          final g = findGame((msg['game'] ?? '') as String);
          if (g == null) {
            link.close();
            if (mounted) {
              setState(() {
                busy = false;
                err = tr('找不到房主选的游戏，请两边都更新到最新版');
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
              params: p,
            ))),
          );
        } else if (msg['type'] == 'closed') {
          if (mounted) {
            setState(() {
              busy = false;
              err = tr('房主已断开');
            });
          }
        }
      };
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = tr('连接失败，请确认在同一WiFi且IP正确');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rooms = finder.rooms.entries.toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('加入房间'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr('附近的房间'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (rooms.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(tr('正在搜索同一WiFi下的房间…\n搜不到的话，可以在下面手动输入房主的IP。'),
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          for (final e in rooms)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PressBox(
                color: cs.surfaceContainerHigh,
                padding: const EdgeInsets.all(14),
                onTap: busy ? null : () => connect(e.key),
                child: Row(
                  children: [
                    Icon(Icons.wifi, color: app.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.value,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          Text(e.key, style: TextStyle(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: ipCtl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: tr('房主IP'),
              hintText: tr('例如 192.168.1.5'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : () => connect(ipCtl.text),
            child: Text(busy ? tr('连接中…') : tr('连接')),
          ),
          if (err != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(err!, style: TextStyle(color: cs.error)),
            ),
        ],
      ),
    );
  }
}
