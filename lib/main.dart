import 'dart:math';
import 'package:flutter/material.dart';
import 'game_page.dart';
import 'blind_page.dart';
import 'blind_setup.dart';
import 'lobby.dart';

void main() => runApp(const ChessApp());

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '象棋',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(String title, String sub, IconData icon, VoidCallback onTap) {
      return Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          leading: Icon(icon, size: 32),
          title: Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          subtitle: Text(sub),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
    }

    void open(bool free) => Navigator.push(
        context, MaterialPageRoute(builder: (_) => GamePage(free: free)));

    return Scaffold(
      appBar: AppBar(title: const Text('象棋')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          item('普通对局', '标准规则，自动判断将军与胜负', Icons.grid_on,
              () => open(false)),
          item('自由模式', '同一台设备轮流走，可关闭规则校验', Icons.swap_horiz,
              () => open(true)),
          item('盲棋', '暗子翻棋，开局明暗可自定义', Icons.visibility_off, () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => BlindSetupPage(
                          buttonText: '开始游戏',
                          onConfirm: (ctx, cfg) {
                            Navigator.pushReplacement(
                                ctx,
                                MaterialPageRoute(
                                    builder: (_) => BlindPage(
                                        cfg: cfg,
                                        seed: Random().nextInt(1 << 30))));
                          },
                        )));
          }),
          item('局域网对战', '同一WiFi下，标准或盲棋', Icons.wifi, () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LobbyPage()));
          }),
        ],
      ),
    );
  }
}
