import 'dart:math';
import 'package:flutter/material.dart';
import 'game_page.dart';
import 'blind_page.dart';
import 'blind_setup.dart';
import 'board_draw.dart';
import 'lobby.dart';
import 'ui.dart';

void main() => runApp(const ChessApp());

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '象棋',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.dark),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _open(Widget page) => Navigator.push(context, fadeRoute(page));

  void _blind() {
    Navigator.push(
        context,
        fadeRoute(BlindSetupPage(
          buttonText: '开始游戏',
          onConfirm: (ctx, cfg) {
            Navigator.pushReplacement(
                ctx,
                fadeRoute(BlindPage(
                    cfg: cfg, seed: Random().nextInt(1 << 30))));
          },
        )));
  }

  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF6E3B4),
            border: Border.all(color: kRedC, width: 3),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: const Text('帅',
              style: TextStyle(
                  color: kRedC, fontSize: 32, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('象棋',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
            Text('单机 · 盲棋 · 局域网',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Reveal(parent: _c, index: 0, child: _header(context)),
            const SizedBox(height: 28),
            Reveal(
              parent: _c,
              index: 1,
              child: PressCard(
                color: const Color(0xFF00897B),
                icon: Icons.grid_on,
                title: '普通对局',
                sub: '标准规则，吃掉将/帅获胜',
                onTap: () => _open(const GamePage(free: false)),
              ),
            ),
            const SizedBox(height: 14),
            Reveal(
              parent: _c,
              index: 2,
              child: PressCard(
                color: const Color(0xFF3949AB),
                icon: Icons.swap_horiz,
                title: '自由模式',
                sub: '同一台设备轮流走，可关闭规则校验',
                onTap: () => _open(const GamePage(free: true)),
              ),
            ),
            const SizedBox(height: 14),
            Reveal(
              parent: _c,
              index: 3,
              child: PressCard(
                color: const Color(0xFF6D4C41),
                icon: Icons.visibility_off,
                title: '盲棋',
                sub: '暗子翻棋，开局明暗可自定义',
                onTap: _blind,
              ),
            ),
            const SizedBox(height: 14),
            Reveal(
              parent: _c,
              index: 4,
              child: PressCard(
                color: const Color(0xFFEF6C00),
                icon: Icons.wifi,
                title: '局域网对战',
                sub: '同一WiFi下，标准 / 自由 / 盲棋都能联机',
                onTap: () => _open(const LobbyPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
