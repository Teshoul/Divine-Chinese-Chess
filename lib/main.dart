import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'blind_page.dart';
import 'blind_setup.dart';
import 'festival.dart';
import 'fx.dart';
import 'liquid.dart';
import 'lobby.dart';
import 'mode_setup.dart';
import 'music.dart';
import 'profile.dart';
import 'settings.dart';
import 'settings_page.dart';
import 'strings.dart';
import 'ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (FlutterErrorDetails d) => Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          color: const Color(0xFF3B0A0A),
          padding: const EdgeInsets.all(12),
          child: Text(
            '出错：${d.exceptionAsString()}',
            maxLines: 14,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, decoration: TextDecoration.none),
          ),
        ),
      );
  runApp(const ChessApp());
  app
      .load()
      .timeout(const Duration(seconds: 8))
      .then((_) => app.change(() {}))
      .catchError((_) {});
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
          title: '神的象棋',
          debugShowCheckedModeBanner: false,
          locale: Locale(const ['zh', 'en', 'ja', 'ru'][app.lang]),
          supportedLocales: const [Locale('zh'), Locale('en'), Locale('ja'), Locale('ru')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          themeMode: app.divine
              ? ThemeMode.dark
              : const [ThemeMode.system, ThemeMode.light, ThemeMode.dark][app.themeMode],
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          builder: (context, child) => Stack(
            fit: StackFit.expand,
            children: [
              Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) {
                  lastTap = e.position;
                  festKey.currentState?.tap(e.position);
                },
                child: RepaintBoundary(
                  key: rootKey,
                  child: AppBackdrop(child: child ?? const SizedBox()),
                ),
              ),
              Positioned.fill(child: IgnorePointer(child: FestivalLayer(key: festKey))),
              const PrankFlagOverlay(),
            ],
          ),
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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..forward();
  late final AnimationController _pc =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final Ticker _tick = createTicker(_onTick);
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  double cw = 0.5, rh = 0.5, vc = 0, vr = 0, tcw = 0.5, trh = 0.5;
  Duration _last = Duration.zero;
  int? hover;
  bool open = false;
  bool _opening = false;
  int taps = 0;
  double spin = 0;

  static const _names = ['普通对局', '自由模式', '盲棋', '局域网对战'];
  static const _subs = [
    '标准规则\n自动判胜负',
    '同屏轮流走\n规则随意',
    '暗子翻棋\n开局自定义',
    '同一WiFi\n联机对战'
  ];
  static const _icons = [Icons.grid_on, Icons.swap_horiz, Icons.visibility_off, Icons.wifi];
  static const double _gap = 8;

  @override
  void dispose() {
    _tick.dispose();
    _in.dispose();
    _pc.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _setTarget(int? i) {
    if (hover == i) return;
    hover = i;
    tcw = i == null ? 0.5 : (i % 2 == 0 ? 0.62 : 0.38);
    trh = i == null ? 0.5 : (i < 2 ? 0.62 : 0.38);
    if (app.animLevel == 0) {
      cw = tcw;
      rh = trh;
      vc = 0;
      vr = 0;
      _frame.value++;
      return;
    }
    if (!_tick.isActive) {
      _last = Duration.zero;
      _tick.start();
    }
  }

  void _onTick(Duration el) {
    var dt = (el - _last).inMicroseconds / 1e6;
    _last = el;
    if (dt <= 0) return;
    if (dt > 0.033) dt = 0.033;
    final lv = app.animLevel;
    final k = lv == 1 ? 520.0 : (lv == 2 ? 170.0 : 210.0);
    final z = lv == 3 ? 0.4 : 1.0;
    final c = 2 * z * sqrt(k);
    const n = 4;
    final h = dt / n;
    for (var i = 0; i < n; i++) {
      vc += (-k * (cw - tcw) - c * vc) * h;
      cw += vc * h;
      vr += (-k * (rh - trh) - c * vr) * h;
      rh += vr * h;
    }
    _frame.value++;
    if ((cw - tcw).abs() < 0.0004 &&
        (rh - trh).abs() < 0.0004 &&
        vc.abs() < 0.01 &&
        vr.abs() < 0.01) {
      cw = tcw;
      rh = trh;
      vc = 0;
      vr = 0;
      _tick.stop();
      _frame.value++;
    }
  }

  int? _hit(Offset p, double s) {
    if (p.dx < 0 || p.dy < 0 || p.dx > s || p.dy > s) return null;
    final w0 = (s - _gap) * cw.clamp(0.18, 0.82).toDouble();
    final h0 = (s - _gap) * rh.clamp(0.18, 0.82).toDouble();
    final col = p.dx <= w0 + _gap / 2 ? 0 : 1;
    final row = p.dy <= h0 + _gap / 2 ? 0 : 1;
    return row * 2 + col;
  }

  void _openMode(int i) {
    if (_opening) return;
    _opening = true;
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
          buttonText: tr('开始游戏'),
          onConfirm: (ctx, cfg) {
            Navigator.pushReplacement(
                ctx, fadeRoute(BlindPage(cfg: cfg, seed: Random().nextInt(1 << 30))));
          },
        );
        break;
      default:
        page = const LobbyPage();
    }
    Navigator.push(context, revealRoute(page)).then((_) {
      _opening = false;
      if (mounted) _setTarget(null);
    });
  }

  void _toggleProfile() {
    setState(() => open = !open);
    if (open) {
      _pc.forward();
    } else {
      _pc.reverse();
    }
  }

  BoxDecoration _glassDeco(Color c, double r) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(r),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white.withOpacity(0.38), c.withOpacity(0.55), c.withOpacity(0.35)],
        stops: const [0, 0.5, 1],
      ),
      border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.4),
      boxShadow: [
        BoxShadow(color: c.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8)),
        BoxShadow(
            color: Colors.white.withOpacity(0.12), blurRadius: 6, offset: const Offset(-2, -2)),
      ],
    );
  }

  Widget _tile(int i, Rect r) {
    final color = app.preset.tiles[i];
    final divine = app.divine;
    final ink = divine ? Colors.white : inkOn(color);
    final sub = divine ? Colors.white70 : inkSub(color);
    final rad = app.cardR + (app.glass ? 10 : 4);
    final shadows = divine ? const [Shadow(color: Color(0xAA000000), blurRadius: 6)] : null;
    // 愚人节：名字错位，点哪块还是进哪块
    final li = prank.active ? (i + 1) % 4 : i;
    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 130,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icons[i], size: 44, color: ink),
              const SizedBox(height: 10),
              Text(tr(_names[li]),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: ink, fontSize: 18, fontWeight: FontWeight.bold, shadows: shadows)),
              const SizedBox(height: 4),
              Text(tr(_subs[li]),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: sub, fontSize: 12, shadows: shadows)),
            ],
          ),
        ),
      ),
    );
    return Positioned.fromRect(
      rect: r,
      child: divine
          ? LiquidFill(radius: rad, phase: i * 3.1, child: content)
          : DecoratedBox(
              decoration: app.glass ? _glassDeco(color, rad) : styled(color, r: rad),
              child: content,
            ),
    );
  }

  Widget _grid(double s) {
    return SizedBox(
      width: s,
      height: s,
      child: MouseRegion(
        onExit: (_) {
          if (!_opening) _setTarget(null);
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _setTarget(_hit(e.localPosition, s)),
          onPointerMove: (e) => _setTarget(_hit(e.localPosition, s)),
          onPointerHover: (e) => _setTarget(_hit(e.localPosition, s)),
          onPointerUp: (e) {
            final i = _hit(e.localPosition, s);
            if (i != null) {
              _openMode(i);
            } else {
              _setTarget(null);
            }
          },
          onPointerCancel: (_) => _setTarget(null),
          child: ValueListenableBuilder<int>(
            valueListenable: _frame,
            builder: (context, _, __) {
              final w0 = (s - _gap) * cw.clamp(0.18, 0.82).toDouble();
              final w1 = (s - _gap) - w0;
              final h0 = (s - _gap) * rh.clamp(0.18, 0.82).toDouble();
              final h1 = (s - _gap) - h0;
              final rects = [
                Rect.fromLTWH(0, 0, w0, h0),
                Rect.fromLTWH(w0 + _gap, 0, w1, h0),
                Rect.fromLTWH(0, h0 + _gap, w0, h1),
                Rect.fromLTWH(w0 + _gap, h0 + _gap, w1, h1),
              ];
              return Stack(children: [for (var i = 0; i < 4; i++) _tile(i, rects[i])]);
            },
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        setState(() {
          taps++;
          spin += 1;
        });
        if (taps % 5 == 0) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(tr('老将出马，一个顶俩！'))));
        }
      },
      child: AnimatedRotation(
        turns: spin,
        duration: const Duration(milliseconds: 800),
        curve: Curves.elasticOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(prank.active ? '棋象' : tr('象棋'),
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
            Text(tr('单机 · 盲棋 · 局域网'),
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap, double phase) {
    if (app.divine) {
      return GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 58,
          height: 58,
          child: LiquidFill(
            radius: 29,
            phase: phase,
            child: Center(child: Icon(icon, color: Colors.white, size: 28)),
          ),
        ),
      );
    }
    return PressBox(
      color: app.primary,
      r: app.uiStyle == 1 ? 8 : 29,
      width: 58,
      height: 58,
      onTap: onTap,
      child: Icon(icon, color: inkOn(app.primary), size: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[app, prank]),
      builder: (context, _) {
        return PopScope(
          canPop: !open,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && open) _toggleProfile();
          },
          child: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                const ImageSlot(slot: 'home'),
                SafeArea(
                  child: Stack(
                    children: [
                      Align(
                        alignment: const Alignment(0, -0.78),
                        child: Reveal(parent: _in, index: 0, child: _header(context)),
                      ),
                      Center(
                        child: LayoutBuilder(builder: (context, cons) {
                          final s = min(min(cons.maxWidth - 40, cons.maxHeight * 0.62), 480.0);
                          return Reveal(parent: _in, index: 1, child: _grid(s));
                        }),
                      ),
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 100,
                        child: Center(child: PrankFlagHost(at: 'home')),
                      ),
                      Positioned(
                        left: 20,
                        bottom: 20,
                        child: AnimatedBuilder(
                          animation: MusicService.I,
                          builder: (context, _) => _roundBtn(
                            MusicService.I.playing ? Icons.graphic_eq : Icons.music_note,
                            () => Navigator.push(context, revealRoute(const MusicPage())),
                            2.0,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 20,
                        bottom: 20,
                        child: _roundBtn(
                          Icons.settings,
                          () {
                            if (prank.gate(context, 'settings', '设置坏了，再点一次试试')) return;
                            Navigator.push(context, revealRoute(const SettingsPage()));
                          },
                          0.0,
                        ),
                      ),
                    ],
                  ),
                ),
                ProfileLayer(anim: _pc, onToggle: _toggleProfile),
              ],
            ),
          ),
        );
      },
    );
  }
}
