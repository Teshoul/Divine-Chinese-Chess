import 'package:flutter/material.dart';
import 'blind.dart';
import 'blind_page.dart';
import 'blind_setup.dart';
import 'game_page.dart';
import 'match_info.dart';

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

Future<Map<String, dynamic>?> _blindSetup(BuildContext context) async {
  final cfg = await Navigator.push<BlindConfig>(
      context,
      MaterialPageRoute(
          builder: (_) => BlindSetupPage(
              buttonText: '确定',
              onConfirm: (ctx, c) => Navigator.pop(ctx, c))));
  if (cfg == null) return null;
  return <String, dynamic>{'cfg': cfg.toJson()};
}

final List<GameDef> onlineGames = [
  GameDef(
    id: 'chess',
    name: '标准对局',
    desc: '标准象棋规则，吃掉将/帅获胜',
    icon: Icons.grid_on,
    defaultParams: () => <String, dynamic>{},
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
    defaultParams: () =>
        <String, dynamic>{'cfg': BlindConfig.kingsOnly().toJson()},
    setup: _blindSetup,
    buildOnline: (m) => BlindPage(
      cfg: BlindConfig.fromJson(
          Map<String, dynamic>.from(m.params['cfg'] as Map)),
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
