import 'package:flutter/material.dart';

void main() => runApp(const ChessApp());

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '象棋',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('象棋 · 测试成功', style: TextStyle(fontSize: 28)),
        ),
      ),
    );
  }
}
