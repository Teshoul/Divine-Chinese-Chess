import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'settings.dart';
import 'strings.dart';

class Festival {
  final String id, name, emoji;
  final List<String> rain, burst;
  final Color top, bottom, accent;
  final int tap; // 0 烟花  1 表情爆开  2 上浮  3 涟漪
  final bool moon, lanterns;
  const Festival(this.id, this.name, this.emoji, this.rain, this.burst, this.top, this.bottom,
      this.accent, this.tap,
      {this.moon = false, this.lanterns = false});
}

const List<Festival> kFestivals = [
  Festival('spring', '春节', '🧨', ['🧧', '🏮', '✨', '🎆'], ['🧧', '🎊', '✨'], Color(0xFFFFCDD2),
      Color(0xFFFFE082), Color(0xFFE53935), 0,
      lanterns: true),
  Festival('lantern', '元宵节', '🏮', ['🏮', '🥮', '✨'], ['🏮', '✨'], Color(0xFFFFCC80),
      Color(0xFFFF8A65), Color(0xFFFF7043), 2,
      lanterns: true),
  Festival('dragon', '端午节', '🐉', ['🍃', '🌿', '🎋'], ['🐉', '🍃'], Color(0xFFC8E6C9),
      Color(0xFF80CBC4), Color(0xFF2E7D32), 3),
  Festival('newyear', '元旦', '🎉', ['❄️', '🎉', '✨'], ['🎉', '✨'], Color(0xFFBBDEFB),
      Color(0xFFE1BEE7), Color(0xFF3949AB), 0),
  Festival('national', '国庆节', '🇨🇳', ['⭐', '🎆', '✨'], ['⭐', '🎆'], Color(0xFFFF8A80),
      Color(0xFFFFE57F), Color(0xFFD50000), 0),
  Festival('qixi', '七夕节', '💞', ['💖', '🌹', '✨', '🐦'], ['💖', '🌹'], Color(0xFFF8BBD0),
      Color(0xFFCE93D8), Color(0xFFE91E63), 1),
  Festival('midautumn', '中秋节', '🌕', ['🥮', '🌕', '🐇', '✨'], ['🥮', '🌕', '🐇'],
      Color(0xFFFFF3C4), Color(0xFFFFCC80), Color(0xFFFFA000), 2,
      moon: true),
  Festival('halloween', '万圣节', '🎃', ['🎃', '🦇', '👻', '🕸️'], ['🎃', '👻', '🦇'],
      Color(0xFFFFCC80), Color(0xFFB39DDB), Color(0xFFEF6C00), 1),
  Festival('mother', '母亲节', '💐', ['🌸', '💐', '❤️'], ['💐', '❤️', '🌸'], Color(0xFFFFCDD2),
      Color(0xFFF8BBD0), Color(0xFFEC407A), 1),
  Festival('father', '父亲节', '👔', ['👔', '⭐', '✨'], ['👔', '⭐'], Color(0xFFB3E5FC),
      Color(0xFF90CAF9), Color(0xFF1976D2), 1),
  Festival('earth', '世界地球日', '🌍', ['🍀', '🌍', '💧', '🌱'], ['🌱', '🍀'], Color(0xFFB2EBF2),
      Color(0xFFA5D6A7), Color(0xFF2E7D32), 3),
  Festival('labor', '劳动节', '💪', ['🔧', '⚙️', '🌹'], ['💪', '🔧', '⚙️'], Color(0xFFFFCCBC),
      Color(0xFFFFE082), Color(0xFFD84315), 1),
  Festival('april', '愚人节', '🤡', ['🤡', '🃏', '🎭'], ['🤪', '🃏', '🤡'], Color(0xFFE1BEE7),
      Color(0xFFB2EBF2), Color(0xFF8E24AA), 1),
];

Festival? festivalById(String id) {
  for (final f in kFestivals) {
    if (f.id == id) return f;
  }
  return null;
}

// 每年：[春节月,日, 端午月,日, 七夕月,日, 中秋月,日]
const Map<int, List<int>> _lunar = {
  2026: [2, 17, 6, 19, 8, 19, 9, 25],
  2027: [2, 6, 6, 9, 8, 8, 9, 15],
  2028: [1, 26, 5, 28, 8, 26, 10, 3],
  2029: [2, 13, 6, 16, 8, 16, 9, 22],
  2030: [2, 3, 6, 5, 8, 5, 9, 12],
  2031: [1, 23, 6, 24, 8, 25, 10, 1],
  2032: [2, 11, 6, 12, 8, 13, 9, 19],
  2033: [1, 31, 6, 1, 8, 2, 9, 8],
  2034: [2, 19, 6, 20, 8, 22, 9, 27],
  2035: [2, 8, 6, 10, 8, 11, 9, 16],
};

DateTime _u(int y, int m, int d) => DateTime.utc(y, m, d);

int _nthSunday(int year, int month, int n) {
  final wd = _u(year, month, 1).weekday; // 周一=1 … 周日=7
  final first = 1 + (7 - wd) % 7;
  return first + 7 * (n - 1);
}

Festival? detectFestival(DateTime now) {
  final y = now.year, m = now.month, d = now.day;
  final today = _u(y, m, d);
  bool same(int mm, int dd) => m == mm && d == dd;
  final l = _lunar[y];
  if (l != null) {
    if (same(l[2], l[3])) return festivalById('dragon');
    if (same(l[4], l[5])) return festivalById('qixi');
    if (same(l[6], l[7])) return festivalById('midautumn');
    final ds = today.difference(_u(y, l[0], l[1])).inDays;
    if (ds >= -1 && ds <= 6) return festivalById('spring');
    if (ds == 14) return festivalById('lantern');
  }
  if (same(4, 1)) return festivalById('april');
  if (same(4, 22)) return festivalById('earth');
  if (m == 5 && d >= 1 && d <= 3) return festivalById('labor');
  if (m == 5 && d == _nthSunday(y, 5, 2)) return festivalById('mother');
  if (m == 6 && d == _nthSunday(y, 6, 3)) return festivalById('father');
  if (m == 10 && d >= 1 && d <= 7) return festivalById('national');
  if (same(10, 31)) return festivalById('halloween');
  if (same(1, 1)) return festivalById('newyear');
  return null;
}

String todayKey() {
  final n = DateTime.now();
  return '${n.year}-${n.month}-${n.day}';
}

Festival? _cache;
String _ck = '';

Festival? activeFestival() {
  if (app.festPreview.isNotEmpty) return festivalById(app.festPreview);
  if (!app.festOn) return null;
  final k = todayKey();
  if (k != _ck) {
    _ck = k;
    _cache = detectFestival(DateTime.now());
  }
  return _cache;
}

// ───────────────────────── 愚人节恶作剧 ─────────────────────────

class PrankState extends ChangeNotifier {
  int stage = 0; // 0 左下  1 右上  2 右下  3 主菜单  4 设置页
  bool honest = false;
  final Map<String, DateTime> _gates = <String, DateTime>{};
  final Random _r = Random();

  bool get active => activeFestival()?.id == 'april' && app.prankOff != todayKey();

  void reset() {
    stage = 0;
    honest = false;
    _gates.clear();
    notifyListeners();
  }

  void setHonest() {
    honest = true;
    notifyListeners();
  }

  void say(BuildContext c, String msg) {
    final m = ScaffoldMessenger.maybeOf(c);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1500)));
  }

  /// 第一次点会被拦下，5 秒内再点一次才放行
  bool gate(BuildContext c, String key, String msg) {
    if (!active) return false;
    final now = DateTime.now();
    final t = _gates[key];
    if (t != null && now.difference(t).inSeconds < 5) {
      _gates.remove(key);
      return false;
    }
    _gates[key] = now;
    say(c, tr(msg));
    return true;
  }

  bool intercept(BuildContext c, String label) {
    if (!active) return false;
    if (label == tr('悔棋') && _r.nextDouble() < 0.6) {
      say(c, tr('悔棋？愚人节不予批准！'));
      return true;
    }
    if (label == tr('重开')) return gate(c, 'restart', '真的要重开吗？再点一次试试');
    return false;
  }

  void tapFlag(BuildContext c) {
    if (honest) {
      app.change(() => app.prankOff = todayKey());
      say(c, tr('哈哈，今天就不搞你这个杂鱼了ᯠ˶｡  ̫`｡˶ᯄ੭'));
      reset();
      return;
    }
    const lines = [
      '你好OvO',
      '想投降先追上我OwO',
      '拜拜～跑路了❍⩊❍',
      '要不去口令区说点什么？',
    ];
    if (stage < 4) {
      say(c, tr(lines[stage]));
      stage++;
    } else {
      say(c, tr('说“投降”啊，杂鱼ᯠ  _   ̫  _ ̥ ᯄ ੭'));
    }
    notifyListeners();
  }
}

final PrankState prank = PrankState();

class _FlagButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool honest;
  const _FlagButton({required this.onTap, required this.honest});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.94),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: const Text('🏳️', style: TextStyle(fontSize: 30, decoration: TextDecoration.none)),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(tr(honest ? '投降' : '举白旗'),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 全局悬浮的白旗（左下 → 右上 → 右下）
class PrankFlagOverlay extends StatelessWidget {
  const PrankFlagOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[prank, app]),
      builder: (context, _) {
        if (!prank.active || prank.stage > 2) return const SizedBox.shrink();
        final pad = MediaQuery.paddingOf(context);
        final st = prank.stage;
        final Widget flag = TweenAnimationBuilder<double>(
          key: ValueKey<int>(st),
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutBack,
          builder: (c, v, child) {
            final from = st == 1
                ? const Offset(130, -130)
                : (st == 2 ? const Offset(130, 130) : Offset.zero);
            return Transform.translate(offset: from * (1 - v), child: child);
          },
          child: _FlagButton(onTap: () => prank.tapFlag(context), honest: prank.honest),
        );
        return Positioned.fill(
          child: Stack(
            children: [
              if (st == 0) Positioned(left: 12, bottom: pad.bottom + 100, child: flag),
              if (st == 1) Positioned(right: 12, top: pad.top + 8, child: flag),
              if (st == 2) Positioned(right: 12, bottom: pad.bottom + 100, child: flag),
            ],
          ),
        );
      },
    );
  }
}

/// 白旗出现在主菜单（at: 'home'）或设置页（at: 'settings'）
class PrankFlagHost extends StatelessWidget {
  final String at;
  const PrankFlagHost({super.key, required this.at});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[prank, app]),
      builder: (context, _) {
        if (!prank.active) return const SizedBox.shrink();
        if (prank.stage != (at == 'home' ? 3 : 4)) return const SizedBox.shrink();
        return TweenAnimationBuilder<double>(
          key: ValueKey<int>(prank.stage),
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (c, v, child) => Transform.scale(scale: max(0.01, v), child: child),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _FlagButton(onTap: () => prank.tapFlag(context), honest: prank.honest),
          ),
        );
      },
    );
  }
}

// ───────────────────────── 节日特效层 ─────────────────────────

final GlobalKey<FestivalLayerState> festKey = GlobalKey<FestivalLayerState>();

class _P {
  final int kind; // 0 飘落  1 火花  2 火箭  3 表情爆开  4 上浮  5 涟漪
  double x, y, vx, vy, age, life, size, rot, spin, sx, sy, tx, ty, sway;
  String ch;
  Color color;
  _P(this.kind,
      {this.x = 0,
      this.y = 0,
      this.vx = 0,
      this.vy = 0,
      this.age = 0,
      this.life = 1,
      this.size = 20,
      this.rot = 0,
      this.spin = 0,
      this.sx = 0,
      this.sy = 0,
      this.tx = 0,
      this.ty = 0,
      this.sway = 0,
      this.ch = '',
      this.color = Colors.white});
}

class FestivalLayer extends StatefulWidget {
  const FestivalLayer({super.key});
  @override
  State<FestivalLayer> createState() => FestivalLayerState();
}

class FestivalLayerState extends State<FestivalLayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<int> _rev = ValueNotifier<int>(0);
  final List<_P> _ps = <_P>[];
  final Random _r = Random();
  Duration _last = Duration.zero;
  Size _size = Size.zero;
  double _clock = 0;
  String _fid = '';
  bool _banner = false;
  Timer? _bt;

  @override
  void initState() {
    super.initState();
    app.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    app.removeListener(_sync);
    _bt?.cancel();
    _ticker.dispose();
    _rev.dispose();
    super.dispose();
  }

  void _sync() {
    final fe = activeFestival();
    final id = fe?.id ?? '';
    if (id == _fid) return;
    _fid = id;
    _ps.clear();
    _bt?.cancel();
    if (fe == null) {
      if (_ticker.isActive) _ticker.stop();
      if (mounted) setState(() => _banner = false);
      return;
    }
    _banner = true;
    _bt = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _banner = false);
    });
    _last = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
    if (mounted) setState(() {});
  }

  void _ensureRain(Festival fe, bool first) {
    var n = 0;
    for (final p in _ps) {
      if (p.kind == 0) n++;
    }
    while (n < 14) {
      _ps.add(_P(0,
          x: _r.nextDouble() * _size.width,
          y: first ? _r.nextDouble() * _size.height : -30,
          vy: 40 + _r.nextDouble() * 50,
          size: 18 + _r.nextDouble() * 10,
          spin: (_r.nextDouble() - 0.5) * 1.2,
          sway: _r.nextDouble() * 6,
          life: 1e9,
          ch: fe.rain[_r.nextInt(fe.rain.length)]));
      n++;
    }
  }

  void _tick(Duration el) {
    var dt = (el - _last).inMicroseconds / 1e6;
    _last = el;
    if (dt <= 0) return;
    if (dt > 0.05) dt = 0.033;
    _clock += dt;
    final fe = activeFestival();
    if (fe == null || _size.isEmpty) return;
    _ensureRain(fe, _ps.isEmpty);
    final w = _size.width, h = _size.height;
    for (final p in _ps) {
      p.age += dt;
      switch (p.kind) {
        case 0:
          p.y += p.vy * dt;
          p.x += sin(p.age * 1.6 + p.sway) * 18 * dt;
          p.rot += p.spin * dt;
          if (p.y > h + 40) {
            p.y = -30;
            p.x = _r.nextDouble() * w;
          }
          break;
        case 1:
          p.vy += 140 * dt;
          p.vx *= (1 - 0.9 * dt);
          p.x += p.vx * dt;
          p.y += p.vy * dt;
          break;
        case 2:
          final u = (p.age / p.life).clamp(0.0, 1.0).toDouble();
          final e = 1 - pow(1 - u, 2).toDouble();
          p.x = p.sx + (p.tx - p.sx) * e;
          p.y = p.sy + (p.ty - p.sy) * e;
          break;
        case 3:
          p.vy += 320 * dt;
          p.x += p.vx * dt;
          p.y += p.vy * dt;
          p.rot += p.spin * dt;
          break;
        case 4:
          p.y += p.vy * dt;
          p.x += sin(p.age * 2 + p.sway) * 22 * dt;
          break;
        default:
          break;
      }
    }
    final fresh = <_P>[];
    for (final p in _ps) {
      if (p.kind == 2 && p.age >= p.life) _explode(p, fe, fresh);
    }
    _ps.removeWhere((p) => p.kind != 0 && p.age >= p.life);
    _ps.addAll(fresh);
    _rev.value++;
  }

  void _explode(_P rk, Festival fe, List<_P> out) {
    final pal = <Color>[
      fe.accent,
      const Color(0xFFFFD54F),
      Colors.white,
      const Color(0xFFFF8A65),
      const Color(0xFF80DEEA),
    ];
    for (var i = 0; i < 42; i++) {
      final a = _r.nextDouble() * 2 * pi;
      final sp = 70 + _r.nextDouble() * 200;
      out.add(_P(1,
          x: rk.tx,
          y: rk.ty,
          vx: cos(a) * sp,
          vy: sin(a) * sp,
          life: 0.9 + _r.nextDouble() * 0.8,
          color: pal[_r.nextInt(pal.length)]));
    }
    out.add(_P(5, x: rk.tx, y: rk.ty, life: 0.5, color: fe.accent));
  }

  /// 在点击位置触发特效
  void tap(Offset p) {
    final fe = activeFestival();
    if (fe == null || _size.isEmpty || _ps.length > 420) return;
    switch (fe.tap) {
      case 0:
        final sx = _size.width / 2 + (p.dx - _size.width / 2) * 0.35 + (_r.nextDouble() - 0.5) * 40;
        _ps.add(_P(2, sx: sx, sy: _size.height + 10, tx: p.dx, ty: p.dy, x: sx, y: _size.height + 10, life: 0.6));
        break;
      case 1:
        for (var i = 0; i < 10; i++) {
          final a = _r.nextDouble() * 2 * pi;
          final sp = 140 + _r.nextDouble() * 180;
          _ps.add(_P(3,
              x: p.dx,
              y: p.dy,
              vx: cos(a) * sp,
              vy: sin(a) * sp - 120,
              spin: (_r.nextDouble() - 0.5) * 12,
              size: 24 + _r.nextDouble() * 12,
              life: 1.3 + _r.nextDouble() * 0.5,
              ch: fe.burst[_r.nextInt(fe.burst.length)]));
        }
        break;
      case 2:
        _float(p, fe);
        break;
      default:
        _ps.add(_P(5, x: p.dx, y: p.dy, life: 0.9, color: fe.accent));
        _ps.add(_P(5, x: p.dx, y: p.dy, age: -0.15, life: 1.0, color: fe.accent));
        _float(p, fe);
    }
  }

  void _float(Offset p, Festival fe) {
    for (var i = 0; i < 2; i++) {
      _ps.add(_P(4,
          x: p.dx + (_r.nextDouble() - 0.5) * 30,
          y: p.dy,
          vy: -(70 + _r.nextDouble() * 50),
          sway: _r.nextDouble() * 6,
          size: 30,
          life: 2.4,
          ch: fe.burst[_r.nextInt(fe.burst.length)]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fe = activeFestival();
    if (fe == null) return const SizedBox.shrink();
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: CustomPaint(painter: _FxPainter(this), size: Size.infinite)),
        Positioned(
          top: top + 10,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _banner ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            child: Center(
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: fe.accent.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                  ),
                  child: Text('${fe.emoji} ${trf('{f}快乐', {'f': tr(fe.name)})}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final Map<String, TextPainter> _tpCache = <String, TextPainter>{};

void _emoji(Canvas canvas, String ch, Offset c, double sz, double rot, double a) {
  final bucket = (sz / 4).round();
  final tp = _tpCache.putIfAbsent(
      '$ch@$bucket',
      () => TextPainter(
          text: TextSpan(text: ch, style: TextStyle(fontSize: bucket * 4.0)),
          textDirection: TextDirection.ltr)
        ..layout());
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(rot);
  final fade = a < 0.99;
  if (fade) {
    canvas.saveLayer(
        Rect.fromCenter(center: Offset.zero, width: tp.width + 12, height: tp.height + 12),
        Paint()..color = Colors.white.withOpacity(a.clamp(0.0, 1.0).toDouble()));
  }
  tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  if (fade) canvas.restore();
  canvas.restore();
}

void _lantern(Canvas c, Offset top, double t, double ph) {
  const gold = Color(0xFFFFC107);
  c.save();
  c.translate(top.dx, top.dy);
  c.rotate(sin(t * 1.3 + ph) * 0.12);
  const len = 46.0;
  c.drawLine(Offset.zero, const Offset(0, len), Paint()..color = gold..strokeWidth = 2);
  final body = Rect.fromCenter(center: const Offset(0, len + 26), width: 52, height: 44);
  c.drawOval(
      body,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xFFFF5252), Color(0xFFC62828)])
            .createShader(body));
  c.drawOval(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = gold);
  c.drawRect(Rect.fromCenter(center: const Offset(0, len + 3), width: 22, height: 6), Paint()..color = gold);
  c.drawRect(Rect.fromCenter(center: const Offset(0, len + 49), width: 22, height: 6), Paint()..color = gold);
  c.drawLine(const Offset(0, len + 52), const Offset(0, len + 78),
      Paint()
        ..color = gold
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round);
  c.restore();
}

void _moon(Canvas c, Size s) {
  final ctr = Offset(s.width * 0.8, s.height * 0.12);
  final r = s.width * 0.12;
  c.drawCircle(
      ctr,
      r * 2.2,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0x55FFF59D), Color(0x00FFF59D)])
            .createShader(Rect.fromCircle(center: ctr, radius: r * 2.2)));
  c.drawCircle(ctr, r, Paint()..color = const Color(0xFFFFF8E1));
  c.drawCircle(ctr + Offset(-r * 0.3, -r * 0.2), r * 0.22, Paint()..color = const Color(0x1F000000));
  c.drawCircle(ctr + Offset(r * 0.35, r * 0.3), r * 0.16, Paint()..color = const Color(0x1F000000));
}

class _FxPainter extends CustomPainter {
  final FestivalLayerState s;
  _FxPainter(this.s) : super(repaint: s._rev);

  @override
  void paint(Canvas canvas, Size size) {
    s._size = size;
    final fe = activeFestival();
    if (fe == null) return;
    if (fe.moon) _moon(canvas, size);
    if (fe.lanterns) {
      _lantern(canvas, Offset(size.width * 0.1, 0), s._clock, 0);
      _lantern(canvas, Offset(size.width * 0.9, 0), s._clock, 1.5);
    }
    for (final p in s._ps) {
      if (p.age < 0) continue;
      switch (p.kind) {
        case 0:
          _emoji(canvas, p.ch, Offset(p.x, p.y), p.size, p.rot, 0.6);
          break;
        case 1:
          final a = (1 - p.age / p.life).clamp(0.0, 1.0).toDouble();
          final paint = Paint()
            ..color = p.color.withOpacity(a)
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(p.x - p.vx * 0.04, p.y - p.vy * 0.04), Offset(p.x, p.y), paint);
          canvas.drawCircle(Offset(p.x, p.y), 1.6, Paint()..color = p.color.withOpacity(a));
          break;
        case 2:
          final dx = p.tx - p.sx, dy = p.ty - p.sy;
          final len = max(1.0, sqrt(dx * dx + dy * dy));
          final head = Offset(p.x, p.y);
          final tail = head - Offset(dx / len * 36, dy / len * 36);
          canvas.drawLine(
              tail,
              head,
              Paint()
                ..strokeWidth = 3
                ..strokeCap = StrokeCap.round
                ..shader = ui.Gradient.linear(tail, head, const [Color(0x00FFC107), Colors.white]));
          canvas.drawCircle(
              head,
              4,
              Paint()
                ..color = const Color(0xFFFFE082)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
          break;
        case 3:
          final u = p.age / p.life;
          _emoji(canvas, p.ch, Offset(p.x, p.y), p.size, p.rot, u > 0.7 ? 1 - (u - 0.7) / 0.3 : 1.0);
          break;
        case 4:
          final a = min(1.0, p.age / 0.25) * min(1.0, (p.life - p.age) / 0.6);
          _emoji(canvas, p.ch, Offset(p.x, p.y), p.size, 0, a);
          break;
        default:
          final u = (p.age / p.life).clamp(0.0, 1.0).toDouble();
          canvas.drawCircle(
              Offset(p.x, p.y),
              8 + 130 * Curves.easeOut.transform(u),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3 * (1 - u) + 1
                ..color = p.color.withOpacity(1 - u));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FxPainter old) => false;
}
