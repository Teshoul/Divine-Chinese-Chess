import 'package:flutter/material.dart';
import 'game_page.dart';
import 'lobby.dart';
import 'settings.dart';
import 'ui.dart';

class ModeSetupPage extends StatefulWidget {
  final int kind; // 0 普通对局  1 自由模式
  const ModeSetupPage({super.key, required this.kind});
  @override
  State<ModeSetupPage> createState() => _ModeSetupPageState();
}

class _ModeSetupPageState extends State<ModeSetupPage> {
  bool mate = true;
  bool strict = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final free = widget.kind == 1;
    final title = free ? '自由模式' : '普通对局';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
                  free ? '同一台设备轮流走棋。\n默认不校验走法，想怎么走都行。' : '标准象棋规则。\n被将军后依然可以自由走子，吃掉将/帅获胜。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                if (free)
                  Center(
                    child: LitToggle(
                      wide: true,
                      icon: Icons.rule,
                      label: '规则校验',
                      value: strict,
                      onChanged: (v) => setState(() => strict = v),
                    ),
                  ),
                if (free) const SizedBox(height: 10),
                if (!free || strict)
                  Center(
                    child: LitToggle(
                      wide: true,
                      icon: Icons.flag,
                      label: '自动判绝杀',
                      value: mate,
                      onChanged: (v) => setState(() => mate = v),
                    ),
                  ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    fadeRoute(GamePage(free: free, mate: mate, strictInit: strict)),
                  ),
                  child: const Text('开始对局', style: TextStyle(fontSize: 17)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, fadeRoute(const LobbyPage())),
                  icon: const Icon(Icons.wifi),
                  label: const Text('局域网联机'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
