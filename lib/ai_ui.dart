import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'settings.dart';

// ───────────── 文字（中 / 英 / 日 / 俄）─────────────

const Map<String, List<String>> _tx = {
  'AI 对战': ['AI Battle', 'AI対戦', 'Игра с ИИ'],
  '已开启': ['ON', 'オン', 'Вкл'],
  '未开启': ['OFF', 'オフ', 'Выкл'],
  '选择难度': ['Difficulty', '難易度', 'Сложность'],
  '新手': ['Rookie', '入門', 'Новичок'],
  '普通': ['Normal', '普通', 'Обычный'],
  '中等': ['Medium', '中級', 'Средний'],
  '困难': ['Hard', '上級', 'Сложный'],
  '地狱': ['Hell', '地獄', 'Ад'],
  '随手乱走，经常送子，适合刚学会规则': [
    'Plays almost at random and hangs pieces. Great for learning the rules.',
    'ほぼ適当に指し、よく駒を取られます。ルールを覚えたての方に。',
    'Ходит почти случайно и часто подставляет фигуры. Для изучения правил.'
  ],
  '能看到一两步，偶尔失误': [
    'Sees a move or two ahead and still slips sometimes.',
    '一〜二手先が読めますが、たまにミスします。',
    'Видит на один-два хода вперёд, иногда ошибается.'
  ],
  '会算三步，懂得保护棋子，偶有疏漏': [
    'Calculates three moves, protects its pieces, rarely slips.',
    '三手先を読み、駒を守れます。まれにミス。',
    'Считает на три хода, защищает фигуры, редко ошибается.'
  ],
  '深度搜索，每步约思考 3 秒，几乎不犯低级错误': [
    'Deep search, about 3 s per move, almost no simple blunders.',
    '深い探索で1手約3秒。初歩的なミスはほぼありません。',
    'Глубокий поиск, ~3 с на ход, почти без грубых ошибок.'
  ],
  '手机上能做到的最强棋力：迭代加深、置换表、开局库，每步思考约 8 秒': [
    'The strongest this phone can manage: iterative deepening, transposition table, opening book, ~8 s per move.',
    'スマホで出せる最強の棋力：反復深化・置換表・定跡、1手約8秒。',
    'Максимум, что тянет телефон: итеративное углубление, таблица, дебютная книга, ~8 с на ход.'
  ],
  '看不见暗子，乱翻乱走': [
    'Cannot see hidden pieces and flips at random.',
    '伏せ駒が見えず、適当に開いて指します。',
    'Не видит скрытые фигуры, ходит наугад.'
  ],
  '会猜暗子，偶尔失误': [
    'Guesses hidden pieces, slips now and then.',
    '伏せ駒を推測しますが、たまにミスします。',
    'Угадывает скрытые фигуры, иногда ошибается.'
  ],
  '会多次假设暗子身份再选最好的一步': [
    'Tries several guesses for the hidden pieces and picks the best move.',
    '伏せ駒の正体を何度も仮定し、最善手を選びます。',
    'Перебирает догадки о скрытых фигурах и выбирает лучший ход.'
  ],
  '大量假设暗子身份并深入搜索，每步约 3 秒': [
    'Many guesses plus deeper search, about 3 s per move.',
    '多数の仮定と深い探索で1手約3秒。',
    'Много догадок и глубокий поиск, ~3 с на ход.'
  ],
  '地狱：AI 能直接看穿所有暗子（开挂），每步思考约 8 秒': [
    'Hell: the AI sees through every hidden piece (cheats), ~8 s per move.',
    '地獄：AIは全ての伏せ駒を見抜きます（チート）。1手約8秒。',
    'Ад: ИИ видит все скрытые фигуры (читерит), ~8 с на ход.'
  ],
  '你执': ['You play', 'あなたの色', 'Вы играете'],
  '执红（先手）': ['Red (first)', '赤（先手）', 'Красные (первый ход)'],
  '执黑（后手）': ['Black (second)', '黒（後手）', 'Чёрные (второй ход)'],
  '随机': ['Random', 'ランダム', 'Случайно'],
  'AI 思考中': ['AI is thinking', 'AI思考中', 'ИИ думает'],
  '对战 AI': ['vs AI', 'AI戦', 'против ИИ'],
};

String tx(String zh) {
  final l = app.lang;
  if (l == 0) return zh;
  final v = _tx[zh];
  return v == null ? zh : v[l - 1];
}

const List<String> kLevelNames = ['新手', '普通', '中等', '困难', '地狱'];

String aiLevelName(int level) => tx(kLevelNames[level.clamp(0, 4).toInt()]);

// ───────────── “AI 思考中…” ─────────────

class ThinkingLabel extends StatefulWidget {
  final Color color;
  const ThinkingLabel({super.key, required this.color});

  @override
  State<ThinkingLabel> createState() => _ThinkingLabelState();
}

class _ThinkingLabelState extends State<ThinkingLabel> {
  Timer? _t;
  int _n = 0;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 380), (_) {
      if (mounted) setState(() => _n = (_n + 1) % 4);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: widget.color),
        ),
        const SizedBox(width: 10),
        Text(
          '${tx('AI 思考中')}${'.' * _n}',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: widget.color),
        ),
      ],
    );
  }
}

// ───────────── 抖动特效（越难抖得越厉害）─────────────

class ShakeFx extends StatefulWidget {
  final int level;
  final bool active;
  final int pulse;
  final Widget child;
  const ShakeFx({
    super.key,
    required this.level,
    required this.active,
    required this.child,
    this.pulse = 0,
  });

  @override
  State<ShakeFx> createState() => _ShakeFxState();
}

class _ShakeFxState extends State<ShakeFx> with SingleTickerProviderStateMixin {
  static const List<double> _amp = [0, 0, 1.1, 2.0, 3.8];
  static const List<double> _freq = [0, 0, 9, 18, 34];
  static const List<double> _rot = [0, 0, 0, 0.012, 0.04];

  late final Ticker _tk = createTicker((_) => _t.value = _now());
  final ValueNotifier<double> _t = ValueNotifier<double>(0);
  final Stopwatch _sw = Stopwatch()..start();
  double _burstAt = -10;

  double _now() => _sw.elapsedMicroseconds / 1e6;
  bool get _run => widget.active && widget.level >= 2;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ShakeFx old) {
    super.didUpdateWidget(old);
    if (widget.pulse != old.pulse) _burstAt = _now();
    _sync();
  }

  void _sync() {
    if (_run) {
      if (!_tk.isActive) _tk.start();
    } else if (_tk.isActive) {
      _tk.stop();
      _t.value = 0;
    }
  }

  @override
  void dispose() {
    _tk.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _t,
      child: widget.child,
      builder: (context, t, child) {
        final lv = widget.level.clamp(0, 4).toInt();
        if (!_run || lv < 2) return child!;
        final k = 1.0 + 2.2 * max(0.0, 1 - (t - _burstAt) / 0.5);
        final amp = _amp[lv] * k;
        final f = _freq[lv] * 2 * pi;
        final dx = amp * (0.6 * sin(t * f) + 0.4 * sin(t * f * 1.93 + 1.3));
        final dy = amp * (0.5 * sin(t * f * 1.37 + 0.7) + 0.3 * sin(t * f * 2.41));
        final rot = _rot[lv] * k * sin(t * f * 1.17);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(dx, dy)
            ..rotateZ(rot),
          child: child,
        );
      },
    );
  }
}

// ───────────── 真实按键手感的按钮 ─────────────

class ChunkyButton extends StatefulWidget {
  final Widget child;
  final bool selected;
  final VoidCallback onTap;
  final Color face;
  final Color faceOn;
  final Color glow;
  final double height;
  final double radius;
  final double depth;
  final int haptic; // 0 轻点 1 轻 2 中 3 重
  final bool pulse;
  const ChunkyButton({
    super.key,
    required this.child,
    required this.selected,
    required this.onTap,
    required this.face,
    required this.faceOn,
    required this.glow,
    this.height = 56,
    this.radius = 16,
    this.depth = 5,
    this.haptic = 0,
    this.pulse = false,
  });

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 280));
  late final AnimationController _sel = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: widget.selected ? 1 : 0);
  late final AnimationController _pop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 760), value: 1);
  late final AnimationController _ring = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650), value: 1);
  late final AnimationController _glow =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  Offset _ringAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    if (widget.pulse && widget.selected) _glow.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ChunkyButton old) {
    super.didUpdateWidget(old);
    if (widget.selected != old.selected) {
      if (widget.selected) {
        _sel.forward();
        _pop.forward(from: 0);
      } else {
        _sel.reverse();
      }
    }
    final wantGlow = widget.pulse && widget.selected;
    if (wantGlow && !_glow.isAnimating) {
      _glow.repeat(reverse: true);
    } else if (!wantGlow && _glow.isAnimating) {
      _glow.stop();
      _glow.value = 0;
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _sel.dispose();
    _pop.dispose();
    _ring.dispose();
    _glow.dispose();
    super.dispose();
  }

  void _tap() {
    switch (widget.haptic) {
      case 0:
        HapticFeedback.selectionClick();
        break;
      case 1:
        HapticFeedback.lightImpact();
        break;
      case 2:
        HapticFeedback.mediumImpact();
        break;
      default:
        HapticFeedback.heavyImpact();
        break;
    }
    _ring.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.radius);
    final depth = widget.depth;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        _ringAt = d.localPosition;
        _press.forward();
      },
      onTapUp: (_) => _press.reverse(),
      onTapCancel: () => _press.reverse(),
      onTap: _tap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_press, _sel, _pop, _ring, _glow]),
        builder: (context, _) {
          final pk = Curves.easeOut.transform(_press.value);
          final sk = _sel.value;
          final spring = Curves.elasticOut.transform(_pop.value);
          final scale = (1.0 + 0.055 * sk * spring) * (1.0 - 0.035 * pk);
          final faceDy = max(pk * 0.9, sk * 0.5) * depth;
          final face = Color.lerp(widget.face, widget.faceOn, sk)!;
          final slab = Color.lerp(face, Colors.black, 0.5)!;
          final glowAmt = widget.pulse ? 0.55 + 0.45 * _glow.value : 1.0;
          return Transform.scale(
            scale: scale,
            child: SizedBox(
              height: widget.height + depth,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: depth,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: slab,
                        borderRadius: r,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.28),
                              blurRadius: 6,
                              offset: const Offset(0, 3)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: faceDy,
                    height: widget.height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: r,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color.lerp(face, Colors.white, 0.14)!, face],
                        ),
                        border: Border.all(
                          color: Color.lerp(
                              Colors.white.withOpacity(0.22), widget.glow, sk)!,
                          width: 1.2 + 0.8 * sk,
                        ),
                        boxShadow: sk > 0.01
                            ? [
                                BoxShadow(
                                  color: widget.glow.withOpacity(0.5 * sk * glowAmt),
                                  blurRadius: 14 + 6 * sk,
                                  spreadRadius: 0.5,
                                ),
                              ]
                            : const [],
                      ),
                      child: ClipRRect(
                        borderRadius: r,
                        child: Stack(
                          children: [
                            Positioned.fill(child: Center(child: widget.child)),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _RingPainter(
                                      _ring.value, _ringAt, widget.glow),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double t;
  final Offset at;
  final Color color;
  _RingPainter(this.t, this.at, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final maxR = size.longestSide * 1.1;
    final r = maxR * Curves.easeOut.transform(t);
    canvas.drawCircle(at, r, Paint()..color = color.withOpacity((1 - t) * 0.20));
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color.withOpacity((1 - t) * 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.t != t || old.at != at;
}

// ───────────── AI 对战设置区 ─────────────

const List<IconData> _icons = [
  Icons.eco,
  Icons.sentiment_satisfied_alt,
  Icons.bolt,
  Icons.whatshot,
  Icons.local_fire_department,
];
const List<Color> _acc = [
  Color(0xFF66BB6A),
  Color(0xFF26A69A),
  Color(0xFFFFB300),
  Color(0xFFFF7043),
  Color(0xFFD50000),
];

Color _faceOnFor(int lv, ColorScheme cs) {
  if (lv == 4) return const Color(0xFF260404);
  if (lv == 3) return const Color(0xFF3A1712);
  return Color.lerp(cs.surfaceContainerHighest, _acc[lv], 0.55)!;
}

Color _inkFor(int lv, bool sel, ColorScheme cs) {
  if (!sel) return cs.onSurface;
  if (lv == 3) return const Color(0xFFFF8A80);
  if (lv == 4) return const Color(0xFFFF0000);
  return ThemeData.estimateBrightnessForColor(_faceOnFor(lv, cs)) == Brightness.dark
      ? Colors.white
      : Colors.black87;
}

String _desc(int level, bool blind) {
  const std = [
    '随手乱走，经常送子，适合刚学会规则',
    '能看到一两步，偶尔失误',
    '会算三步，懂得保护棋子，偶有疏漏',
    '深度搜索，每步约思考 3 秒，几乎不犯低级错误',
    '手机上能做到的最强棋力：迭代加深、置换表、开局库，每步思考约 8 秒',
  ];
  const bl = [
    '看不见暗子，乱翻乱走',
    '会猜暗子，偶尔失误',
    '会多次假设暗子身份再选最好的一步',
    '大量假设暗子身份并深入搜索，每步约 3 秒',
    '地狱：AI 能直接看穿所有暗子（开挂），每步思考约 8 秒',
  ];
  return tx((blind ? bl : std)[level]);
}

class AiSection extends StatefulWidget {
  final bool on;
  final int level;
  final int side; // 0 执红 1 执黑 2 随机
  final bool blind;
  final void Function(bool on, int level, int side) onChanged;
  const AiSection({
    super.key,
    required this.on,
    required this.level,
    required this.side,
    required this.blind,
    required this.onChanged,
  });

  @override
  State<AiSection> createState() => _AiSectionState();
}

class _AiSectionState extends State<AiSection> {
  int _pulse = 0;

  Widget _toggle(ColorScheme cs) {
    final on = widget.on;
    final faceOn = Color.lerp(cs.surfaceContainerHighest, app.primary, 0.6)!;
    final ink = on
        ? (ThemeData.estimateBrightnessForColor(faceOn) == Brightness.dark
            ? Colors.white
            : Colors.black87)
        : cs.onSurface;
    return ChunkyButton(
      selected: on,
      onTap: () => widget.onChanged(!on, widget.level, widget.side),
      face: cs.surfaceContainerHighest,
      faceOn: faceOn,
      glow: app.primary,
      height: 58,
      radius: 18,
      depth: 6,
      haptic: 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.smart_toy, size: 26, color: ink),
          const SizedBox(width: 10),
          Text(tx('AI 对战'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: ink.withOpacity(on ? 0.18 : 0.08),
            ),
            child: Text(tx(on ? '已开启' : '未开启'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ink)),
          ),
        ],
      ),
    );
  }

  Widget _levelBtn(int i, ColorScheme cs) {
    final sel = widget.level == i;
    final ink = _inkFor(i, sel, cs);
    return ChunkyButton(
      selected: sel,
      onTap: () {
        setState(() => _pulse++);
        widget.onChanged(true, i, widget.side);
      },
      face: cs.surfaceContainerHighest,
      faceOn: _faceOnFor(i, cs),
      glow: _acc[i],
      height: 66,
      radius: 14,
      depth: 5,
      haptic: i <= 1 ? 0 : (i == 2 ? 1 : (i == 3 ? 2 : 3)),
      pulse: i == 4,
      child: ShakeFx(
        level: i,
        active: sel,
        pulse: _pulse,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icons[i], size: 22, color: ink),
            const SizedBox(height: 3),
            Text(tx(kLevelNames[i]),
                maxLines: 1,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ink)),
          ],
        ),
      ),
    );
  }

  Widget _sideBtn(int i, ColorScheme cs) {
    final sel = widget.side == i;
    final faceOn = Color.lerp(cs.surfaceContainerHighest, app.primary, 0.55)!;
    final ink = sel
        ? (ThemeData.estimateBrightnessForColor(faceOn) == Brightness.dark
            ? Colors.white
            : Colors.black87)
        : cs.onSurface;
    const labels = ['执红（先手）', '执黑（后手）', '随机'];
    return ChunkyButton(
      selected: sel,
      onTap: () => widget.onChanged(true, widget.level, i),
      face: cs.surfaceContainerHighest,
      faceOn: faceOn,
      glow: app.primary,
      height: 44,
      radius: 12,
      depth: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(tx(labels[i]),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink)),
        ),
      ),
    );
  }

  Widget _options(ColorScheme cs) {
    final hell = widget.level == 4;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: hell ? const Color(0x14FF0000) : Colors.transparent,
        border: Border.all(
          color: hell ? const Color(0x66FF0000) : cs.outline.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tx('选择难度'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _levelBtn(i, cs),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              _desc(widget.level, widget.blind),
              key: ValueKey('${widget.level}${app.lang}${widget.blind}'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: hell ? const Color(0xFFFF5252) : cs.onSurfaceVariant,
                fontWeight: hell ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(tx('你执'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _sideBtn(i, cs),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toggle(cs),
        AnimatedSize(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: widget.on
              ? _options(cs)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
