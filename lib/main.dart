import 'dart:math';
import 'package:flutter/material.dart';
import 'game_page.dart';
import 'blind_page.dart';
import 'blind_setup.dart';
import 'lobby.dart';
import 'mode_setup.dart';
import 'profile.dart';
import 'settings_page.dart';
import 'settings.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.load();
  runApp(const ChessApp());
}

ThemeData buildTheme(Brightness b) {
  final cs = ColorScheme.fromSeed(seedColor: app.primary, brightness: b);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(app.btnR));
  const pad = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    filledButtonTheme:
        FilledButtonThemeData(style: FilledButton.styleFrom(shape: shape, padding: pad)),
    outlinedButtonTheme:
        OutlinedButtonThemeData(style: OutlinedButton.styleFrom(shape: shape, padding: pad)),
    chipTheme: ChipThemeData(
      showCheckmark: false,
      shape: app.toggleShape == 0
          ? const StadiumBorder()
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      selectedColor: app.primary.withOpacity(0.4),
      backgroundColor: Colors.transparent,
      side: BorderSide(color: cs.outline.withOpacity(0.6)),
    ),
  );
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        return MaterialApp(
          title: '象棋',
          debugShowCheckedModeBanner: false,
          themeMode: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark][app.themeMode],
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          builder: (context, child) => AppBackdrop(child: child ?? const SizedBox()),
          home: const HomePage(),
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final GlobalKey _avatarKey = GlobalKey();
  int? hover;
  int? burst;
  int taps = 0;
  double spin = 0;

  static const _names = ['普通对局', '自由模式', '盲棋', '局域网对战'];
  static const _subs = ['标准规则\n自动判胜负', '同屏轮流走\n规则随意', '暗子翻棋\n开局自定义', '同一WiFi\n联机对战'];
  static const _icons = [Icons.grid_on, Icons.swap_horiz, Icons.visibility_off, Icons.wifi];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _open(int i) {
    if (burst != null) return;
    setState(() {
      burst = i;
      hover = null;
    });
    final Widget page;
    switch (i) {
      case 0:
        page = const ModeSetupPage(kind: 0);
        break;
      case 1:
        page = const ModeSetupPage(kind: 1);
        break;
      case 2:
        page = BlindSetupPage(
          buttonText: '开始游戏',
          onConfirm: (ctx, cfg) {
            Navigator.pushReplacement(
                ctx, fadeRoute(BlindPage(cfg: cfg, seed: Random().nextInt(1 << 30))));
          },
        );
        break;
      default:
        page = const LobbyPage();
    }
    Navigator.push(context, soulRoute(page)).then((_) {
      if (mounted) {
        setState(() {
          burst = null;
          hover = null;
        });
      }
    });
  }

  Widget _tile(int i, Rect r) {
    final color = app.preset.tiles[i];
    final active = burst == i;
    final s = active ? 1.14 : (hover == null ? 1.0 : (hover == i ? 1.1 : 0.9));
    final ink = inkOn(color);
    return Positioned.fromRect(
      rect: r,
      child: Reveal(
        parent: _c,
        index: i + 1,
        child: AnimatedScale(
          scale: s,
          duration: Duration(milliseconds: active ? 520 : 240),
          curve: active ? Curves.elasticOut : Curves.easeOutCubic,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: styled(color, r: app.cardR + 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_icons[i], size: 44, color: ink),
                const SizedBox(height: 10),
                Text(_names[i],
                    style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_subs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(color: inkSub(color), fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _grid() {
    return LayoutBuilder(builder: (context, cons) {
      final s = min(min(cons.maxWidth - 40, cons.maxHeight * 0.62), 480.0);
      const gap = 14.0;
      final tw = (s - gap) / 2;
      Rect rectOf(int i) =>
          Rect.fromLTWH((i % 2) * (tw + gap), (i ~/ 2) * (tw + gap), tw, tw);
      final front = burst ?? hover;
      final order = <int>[];
      for (var i = 0; i < 4; i++) {
        if (i != front) order.add(i);
      }
      if (front != null) order.add(front);
      int? hit(Offset p) {
        if (p.dx < 0 || p.dy < 0 || p.dx > s || p.dy > s) return null;
        return (p.dy < s / 2 ? 0 : 2) + (p.dx < s / 2 ? 0 : 1);
      }

      return SizedBox(
        width: s,
        height: s,
        child: MouseRegion(
          onExit: (_) => setState(() => hover = null),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => setState(() => hover = hit(e.localPosition)),
            onPointerMove: (e) => setState(() => hover = hit(e.localPosition)),
            onPointerHover: (e) => setState(() => hover = hit(e.localPosition)),
            onPointerUp: (e) {
              final i = hit(e.localPosition);
              setState(() => hover = null);
              if (i != null) _open(i);
            },
            onPointerCancel: (_) => setState(() => hover = null),
            child: Stack(
              clipBehavior: Clip.none,
              children: [for (final i in order) _tile(i, rectOf(i))],
            ),
          ),
        ),
      );
    });
  }

  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Reveal(
      parent: _c,
      index: 0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                taps++;
                spin += 1;
              });
              if (taps % 5 == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('老将出马，一个顶俩！')),
                );
              }
            },
            child: AnimatedRotation(
              turns: spin,
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: app.faceRed,
                  border: Border.all(color: app.red, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                  ],
                ),
                child: Text('帅',
                    style: TextStyle(
                        color: app.red, fontSize: 28, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('象棋', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              Text('单机 · 盲棋 · 局域网',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _settingsBtn(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, soulRoute(const SettingsPage())),
      child: Container(
        width: 58,
        height: 58,
        decoration: styled(app.primary, r: app.uiStyle == 1 ? 8 : 29),
        child: Icon(Icons.settings, color: inkOn(app.primary), size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> sec =
        ModalRoute.of(context)?.secondaryAnimation ?? const AlwaysStoppedAnimation<double>(0.0);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ImageSlot(slot: 'home'),
          AnimatedBuilder(
            animation: sec,
            builder: (context, child) {
              final v = Curves.easeIn.transform(sec.value);
              return Opacity(
                opacity: max(0.0, 1 - v * 0.92),
                child: Transform.scale(scale: 1 + 0.4 * v, child: child),
              );
            },
            child: SafeArea(
              child: Stack(
                children: [
                  Align(alignment: const Alignment(0, -0.82), child: _header(context)),
                  Center(child: _grid()),
                  Positioned(
                    left: 16,
                    top: 12,
                    child: GestureDetector(
                      key: _avatarKey,
                      onTap: () => openProfile(context, _avatarKey),
                      child: const AvatarBox(size: 52),
                    ),
                  ),
                  Positioned(right: 20, bottom: 20, child: _settingsBtn(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
