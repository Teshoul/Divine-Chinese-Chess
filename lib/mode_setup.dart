import 'dart:math';
import 'package:flutter/material.dart';
import 'ai_glue.dart';
import 'ai_ui.dart';
import 'engine.dart';
import 'enter_fx.dart';
import 'game_page.dart';
import 'lobby.dart';
import 'settings.dart';
import 'strings.dart';
import 'ui.dart';

class ModeSetupPage extends StatefulWidget {
  final int kind; // 0 普通对局  1 自由模式
  const ModeSetupPage({super.key, required this.kind});
  @override
  State<ModeSetupPage> createState() => _ModeSetupPageState();
}

class _ModeSetupPageState extends State<ModeSetupPage> {
  final GlobalKey<SlideAwayState> _away = GlobalKey<SlideAwayState>();
  bool mate = true;
  bool strict = false;
  bool aiOn = false;
  int aiLevel = 2;
  int aiSide = 0;
  bool _starting = false;

  Future<void> _start(bool free) async {
    if (_starting) return;
    _starting = true;
    AiPlan? plan;
    if (!free && aiOn) {
      final human = aiSide == 2
          ? (Random().nextBool() ? Side.red : Side.black)
          : (aiSide == 0 ? Side.red : Side.black);
      plan = AiPlan(aiLevel, human);
    }
    await _away.currentState?.run();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      gameEnterRoute(GamePage(free: free, mate: mate, strictInit: strict, ai: plan)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final free = widget.kind == 1;
    return SlideAway(
      key: _away,
      child: Scaffold(
        appBar: AppBar(title: Text(tr(free ? '自由模式' : '普通对局'))),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: styled(cs.surfaceContainerHigh, r: app.cardR),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(free ? Icons.swap_horiz : Icons.grid_on, size: 44, color: app.primary),
                  const SizedBox(height: 10),
                  Text(
                    tr(free
                        ? '同一台设备轮流走棋。\n默认不校验走法，想怎么走都行。'
                        : '标准象棋规则。\n被将军后依然可以自由走子，吃掉将/帅获胜。'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  if (free)
                    Center(
                      child: LitToggle(
                        wide: true,
                        icon: Icons.rule,
                        label: tr('规则校验'),
                        value: strict,
                        onChanged: (v) => setState(() => strict = v),
                      ),
                    ),
                  if (free) const SizedBox(height: 10),
                  Center(
                    child: LitToggle(
                      wide: true,
                      icon: Icons.flag,
                      label: tr('自动判绝杀'),
                      value: mate,
                      enabled: !free || strict,
                      hint: tr('需要开启规则校验后才可开启'),
                      onChanged: (v) => setState(() => mate = v),
                    ),
                  ),
                  if (!free) const SizedBox(height: 18),
                  if (!free)
                    AiSection(
                      on: aiOn,
                      level: aiLevel,
                      side: aiSide,
                      blind: false,
                      onChanged: (on, lv, sd) => setState(() {
                        aiOn = on;
                        aiLevel = lv;
                        aiSide = sd;
                      }),
                    ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: () => _start(free),
                    child: Text(tr('开始对局'), style: const TextStyle(fontSize: 17)),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, fadeRoute(const LobbyPage())),
                    icon: const Icon(Icons.wifi),
                    label: Text(tr('局域网联机')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
