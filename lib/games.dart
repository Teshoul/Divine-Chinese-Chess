import 'package:flutter/material.dart';
import 'blind.dart';
import 'blind_page.dart';
import 'blind_setup.dart';
import 'game_page.dart';
import 'match_info.dart';
import 'strings.dart';
import 'ui.dart';

class GameDef {
  final String id;
  final String name;
  final String desc;
  final IconData icon;
  final Map<String, dynamic> Function() defaultParams;
  final Future<Map<String, dynamic>?> Function(BuildContext)? setup;
  final Widget Function(MatchInfo) buildOnline;
  const GameDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.icon,
    required this.defaultParams,
    required this.buildOnline,
    this.setup,
  });
}

Future<Map<String, dynamic>?> _chessSetup(BuildContext context) {
  var mate = true;
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(tr('标准对局设置')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LitToggle(
              wide: true,
              icon: Icons.flag,
              label: tr('自动判绝杀'),
              value: mate,
              onChanged: (v) => setS(() => mate = v),
            ),
            const SizedBox(height: 10),
            Text(tr('关闭后，只有吃掉对方的将/帅才算获胜'), style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('取消'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, <String, dynamic>{'mate': mate}),
            child: Text(tr('确定')),
          ),
        ],
      ),
    ),
  );
}

Future<Map<String, dynamic>?> _blindSetup(BuildContext context) async {
  final cfg = await Navigator.push<BlindConfig>(
    context,
    MaterialPageRoute(
      builder: (_) => AppBackdrop(
        child: BlindSetupPage(
          buttonText: tr('确定'),
          onConfirm: (ctx, c) => Navigator.pop(ctx, c),
        ),
      ),
    ),
  );
  if (cfg == null) return null;
  return <String, dynamic>{'cfg': cfg.toJson()};
}

final List<GameDef> onlineGames = [
  GameDef(
    id: 'chess',
    name: '标准对局',
    desc: '标准象棋规则，可选自动判绝杀',
    icon: Icons.grid_on,
    defaultParams: () => <String, dynamic>{'mate': true},
    setup: _chessSetup,
    buildOnline: (m) => GamePage(free: false, match: m),
  ),
  GameDef(
    id: 'free',
    name: '自由模式',
    desc: '不校验走法，轮流各走一步',
    icon: Icons.swap_horiz,
    defaultParams: () => <String, dynamic>{},
    buildOnline: (m) => GamePage(free: true, match: m),
  ),
  GameDef(
    id: 'blind',
    name: '盲棋',
    desc: '暗子翻棋，开局明暗可自定义',
    icon: Icons.visibility_off,
    defaultParams: () => <String, dynamic>{'cfg': BlindConfig.kingsOnly().toJson()},
    setup: _blindSetup,
    buildOnline: (m) => BlindPage(
      cfg: BlindConfig.fromJson(Map<String, dynamic>.from(m.params['cfg'] as Map)),
      seed: m.seed,
      match: m,
    ),
  ),
];

GameDef? findGame(String id) {
  for (final g in onlineGames) {
    if (g.id == id) return g;
  }
  return null;
}
