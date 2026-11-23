import 'dart:math';
import 'package:flutter/material.dart';

/// 头像编辑数据：不改动原图文件，所有裁剪 / 调色 / 涂鸦 / 贴纸都以数据形式保存，
/// 显示时实时叠加，所以 GIF / WebP 动图依旧会正常播放。

double _f(dynamic v, double d) => (v is num && v.isFinite) ? v.toDouble() : d;
double _r4(double v) => (v * 10000).round() / 10000;

class AvatarStroke {
  int color;
  double w; // 笔宽，占头像边长的比例
  final List<Offset> pts; // 坐标也是占头像边长的比例（0~1）
  AvatarStroke(this.color, this.w, [List<Offset>? p]) : pts = p ?? <Offset>[];

  Map<String, dynamic> toJson() => {
        'c': color,
        'w': _r4(w),
        'p': [
          for (final o in pts) [_r4(o.dx), _r4(o.dy)]
        ],
      };

  static AvatarStroke fromJson(Map<String, dynamic> j) {
    final pts = <Offset>[];
    final p = j['p'];
    if (p is List) {
      for (final e in p) {
        if (e is List && e.length >= 2) pts.add(Offset(_f(e[0], 0), _f(e[1], 0)));
      }
    }
    return AvatarStroke(
      j['c'] is num ? (j['c'] as num).toInt() : 0xFFFFFFFF,
      _f(j['w'], 0.03),
      pts,
    );
  }
}

/// 放在头像上的东西：预设图形 / 贴纸（用户自己的图片）/ 文字
class AvatarItem {
  String kind; // shape | sticker | text
  String id; // 图形编号 / 贴纸文件路径 / 文字内容
  double x, y; // 中心位置，占头像边长的比例
  double scale; // 1 = 头像边长的 26%
  double rot; // 角度
  int color;
  bool flip;
  AvatarItem({
    required this.kind,
    required this.id,
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 1,
    this.rot = 0,
    this.color = 0xFFFFFFFF,
    this.flip = false,
  });

  Map<String, dynamic> toJson() => {
        'k': kind,
        'i': id,
        'x': _r4(x),
        'y': _r4(y),
        's': _r4(scale),
        'r': _r4(rot),
        'c': color,
        'f': flip,
      };

  static AvatarItem fromJson(Map<String, dynamic> j) => AvatarItem(
        kind: j['k'] is String ? j['k'] as String : 'shape',
        id: j['i'] is String ? j['i'] as String : 'circle',
        x: _f(j['x'], 0.5),
        y: _f(j['y'], 0.5),
        scale: _f(j['s'], 1),
        rot: _f(j['r'], 0),
        color: j['c'] is num ? (j['c'] as num).toInt() : 0xFFFFFFFF,
        flip: j['f'] == true,
      );
}

const List<String> kAvatarFilters = ['原图', '黑白', '复古', '暖色', '冷色', '鲜艳', '褪色'];

class AvatarEdit {
  // 裁剪：图片放进正方形框里的位置
  double zoom; // 相对“完整显示整张图”的倍数
  double ox, oy; // 平移，占头像边长的比例
  double rot; // 旋转角度
  bool flipX;
  // 调色
  double sat; // 饱和度 0~2
  double bri; // 亮度 -0.5~0.5
  double con; // 对比度 0.5~1.5
  double hue; // 色相 -180~180
  int filter; // 滤镜编号
  final List<AvatarStroke> strokes;
  final List<AvatarItem> items;
  String? snap; // 编辑完成时拍下的静态图（联机时发给对手用）

  AvatarEdit({
    this.zoom = 1,
    this.ox = 0,
    this.oy = 0,
    this.rot = 0,
    this.flipX = false,
    this.sat = 1,
    this.bri = 0,
    this.con = 1,
    this.hue = 0,
    this.filter = 0,
    List<AvatarStroke>? strokes,
    List<AvatarItem>? items,
    this.snap,
  })  : strokes = strokes ?? <AvatarStroke>[],
        items = items ?? <AvatarItem>[];

  Map<String, dynamic> toJson() => {
        'z': _r4(zoom),
        'ox': _r4(ox),
        'oy': _r4(oy),
        'r': _r4(rot),
        'fx': flipX,
        'sat': _r4(sat),
        'bri': _r4(bri),
        'con': _r4(con),
        'hue': _r4(hue),
        'flt': filter,
        'st': [for (final s in strokes) s.toJson()],
        'it': [for (final i in items) i.toJson()],
        'snap': snap,
      };

  static AvatarEdit fromJson(Map<String, dynamic> j) {
    final st = <AvatarStroke>[];
    final it = <AvatarItem>[];
    final a = j['st'];
    if (a is List) {
      for (final e in a) {
        if (e is Map) st.add(AvatarStroke.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    final b = j['it'];
    if (b is List) {
      for (final e in b) {
        if (e is Map) it.add(AvatarItem.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return AvatarEdit(
      zoom: _f(j['z'], 1).clamp(0.05, 20.0).toDouble(),
      ox: _f(j['ox'], 0),
      oy: _f(j['oy'], 0),
      rot: _f(j['r'], 0),
      flipX: j['fx'] == true,
      sat: _f(j['sat'], 1),
      bri: _f(j['bri'], 0),
      con: _f(j['con'], 1),
      hue: _f(j['hue'], 0),
      filter: j['flt'] is num ? (j['flt'] as num).toInt().clamp(0, kAvatarFilters.length - 1).toInt() : 0,
      strokes: st,
      items: it,
      snap: j['snap'] is String ? j['snap'] as String : null,
    );
  }

  AvatarEdit clone() => AvatarEdit.fromJson(toJson());

  /// 随这张头像一起保存的附带文件（贴纸图片、静态快照）
  List<String> extraFiles() {
    final out = <String>[];
    for (final i in items) {
      if (i.kind == 'sticker') out.add(i.id);
    }
    final s = snap;
    if (s != null) out.add(s);
    return out;
  }

  /// 图片本身的变换：先平移，再旋转，最后缩放 / 翻转（都以框中心为基准）
  Matrix4 baseMatrix(double s) {
    return Matrix4.identity()
      ..translate(ox * s, oy * s, 0.0)
      ..rotateZ(rot * pi / 180)
      ..scale(flipX ? -zoom : zoom, zoom, 1.0);
  }

  bool get hasColorFx =>
      filter != 0 ||
      (sat - 1).abs() > 0.001 ||
      bri.abs() > 0.001 ||
      (con - 1).abs() > 0.001 ||
      hue.abs() > 0.001;

  ColorFilter? colorFilter() {
    if (!hasColorFx) return null;
    var m = _identity();
    if (hue.abs() > 0.001) m = _mul(_hueM(hue), m);
    if ((sat - 1).abs() > 0.001) m = _mul(_satM(sat), m);
    if ((con - 1).abs() > 0.001) m = _mul(_conM(con), m);
    if (bri.abs() > 0.001) m = _mul(_briM(bri), m);
    final f = _filterM(filter);
    if (f != null) m = _mul(f, m);
    return ColorFilter.matrix(m);
  }
}

// ───────────── 颜色矩阵（4 行 5 列，最后一行省略）─────────────

List<double> _identity() => <double>[
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0, //
      0, 0, 1, 0, 0, //
      0, 0, 0, 1, 0,
    ];

/// a 在 b 之后作用：result = a × b
List<double> _mul(List<double> a, List<double> b) {
  final o = List<double>.filled(20, 0);
  for (var i = 0; i < 4; i++) {
    for (var j = 0; j < 5; j++) {
      var v = 0.0;
      for (var k = 0; k < 4; k++) {
        v += a[i * 5 + k] * b[k * 5 + j];
      }
      if (j == 4) v += a[i * 5 + 4];
      o[i * 5 + j] = v;
    }
  }
  return o;
}

List<double> _satM(double s) => <double>[
      0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
      0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0, //
      0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0, //
      0, 0, 0, 1, 0,
    ];

List<double> _conM(double c) {
  final t = (0.5 - 0.5 * c) * 255;
  return <double>[
    c, 0, 0, 0, t, //
    0, c, 0, 0, t, //
    0, 0, c, 0, t, //
    0, 0, 0, 1, 0,
  ];
}

List<double> _briM(double b) {
  final t = b * 255;
  return <double>[
    1, 0, 0, 0, t, //
    0, 1, 0, 0, t, //
    0, 0, 1, 0, t, //
    0, 0, 0, 1, 0,
  ];
}

List<double> _hueM(double deg) {
  final a = deg * pi / 180;
  final c = cos(a), s = sin(a);
  return <double>[
    0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928, 0, 0, //
    0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283, 0, 0, //
    0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072, 0, 0, //
    0, 0, 0, 1, 0,
  ];
}

List<double>? _filterM(int i) {
  switch (i) {
    case 1: // 黑白
      return _satM(0);
    case 2: // 复古
      return <double>[
        0.393, 0.769, 0.189, 0, 0, //
        0.349, 0.686, 0.168, 0, 0, //
        0.272, 0.534, 0.131, 0, 0, //
        0, 0, 0, 1, 0,
      ];
    case 3: // 暖色
      return <double>[
        1.1, 0, 0, 0, 10, //
        0, 1.0, 0, 0, 0, //
        0, 0, 0.88, 0, -8, //
        0, 0, 0, 1, 0,
      ];
    case 4: // 冷色
      return <double>[
        0.9, 0, 0, 0, -8, //
        0, 1.0, 0, 0, 0, //
        0, 0, 1.12, 0, 10, //
        0, 0, 0, 1, 0,
      ];
    case 5: // 鲜艳
      return _mul(_conM(1.12), _satM(1.6));
    case 6: // 褪色
      return _mul(_briM(0.07), _conM(0.82));
  }
  return null;
}

// ───────────── 预设图形 ─────────────

const List<String> kShapeIds = [
  'heart', 'star', 'sparkle', 'circle', 'ring', 'square',
  'triangle', 'diamond', 'hexagon', 'arrow', 'bolt', 'cross',
  'moon', 'drop', 'cloud', 'bubble', 'crown', 'flower',
];

Path _starPath(Rect r, int n, double inner) {
  final c = r.center;
  final ro = min(r.width, r.height) / 2;
  final p = Path();
  for (var i = 0; i < n * 2; i++) {
    final rad = i.isEven ? ro : ro * inner;
    final a = -pi / 2 + i * pi / n;
    final pt = Offset(c.dx + rad * cos(a), c.dy + rad * sin(a));
    if (i == 0) {
      p.moveTo(pt.dx, pt.dy);
    } else {
      p.lineTo(pt.dx, pt.dy);
    }
  }
  p.close();
  return p;
}

Path avatarShapePath(String id, Rect r) {
  final w = r.width, h = r.height;
  double x(double v) => r.left + v * w;
  double y(double v) => r.top + v * h;
  final p = Path();
  Path poly(List<List<double>> pts) {
    p.moveTo(x(pts[0][0]), y(pts[0][1]));
    for (var i = 1; i < pts.length; i++) {
      p.lineTo(x(pts[i][0]), y(pts[i][1]));
    }
    p.close();
    return p;
  }

  switch (id) {
    case 'heart':
      p.moveTo(x(0.5), y(0.92));
      p.cubicTo(x(0.0), y(0.58), x(0.04), y(0.10), x(0.28), y(0.10));
      p.cubicTo(x(0.42), y(0.10), x(0.5), y(0.20), x(0.5), y(0.28));
      p.cubicTo(x(0.5), y(0.20), x(0.58), y(0.10), x(0.72), y(0.10));
      p.cubicTo(x(0.96), y(0.10), x(1.0), y(0.58), x(0.5), y(0.92));
      p.close();
      return p;
    case 'star':
      return _starPath(r, 5, 0.42);
    case 'sparkle':
      return _starPath(r, 4, 0.2);
    case 'ring':
      p.fillType = PathFillType.evenOdd;
      p.addOval(r);
      p.addOval(r.deflate(min(w, h) * 0.2));
      return p;
    case 'square':
      p.addRRect(RRect.fromRectAndRadius(r, Radius.circular(min(w, h) * 0.12)));
      return p;
    case 'triangle':
      return poly(const [
        [0.5, 0.05],
        [0.97, 0.92],
        [0.03, 0.92]
      ]);
    case 'diamond':
      return poly(const [
        [0.5, 0.0],
        [1.0, 0.5],
        [0.5, 1.0],
        [0.0, 0.5]
      ]);
    case 'hexagon':
      {
        final c = r.center;
        final ro = min(w, h) / 2;
        for (var i = 0; i < 6; i++) {
          final a = -pi / 2 + i * pi / 3;
          final pt = Offset(c.dx + ro * cos(a), c.dy + ro * sin(a));
          if (i == 0) {
            p.moveTo(pt.dx, pt.dy);
          } else {
            p.lineTo(pt.dx, pt.dy);
          }
        }
        p.close();
        return p;
      }
    case 'arrow':
      return poly(const [
        [0.0, 0.35],
        [0.55, 0.35],
        [0.55, 0.12],
        [1.0, 0.5],
        [0.55, 0.88],
        [0.55, 0.65],
        [0.0, 0.65]
      ]);
    case 'bolt':
      return poly(const [
        [0.60, 0.0],
        [0.15, 0.55],
        [0.45, 0.55],
        [0.35, 1.0],
        [0.85, 0.40],
        [0.55, 0.40],
        [0.75, 0.0]
      ]);
    case 'cross':
      return poly(const [
        [0.35, 0.0],
        [0.65, 0.0],
        [0.65, 0.35],
        [1.0, 0.35],
        [1.0, 0.65],
        [0.65, 0.65],
        [0.65, 1.0],
        [0.35, 1.0],
        [0.35, 0.65],
        [0.0, 0.65],
        [0.0, 0.35],
        [0.35, 0.35]
      ]);
    case 'moon':
      return Path.combine(
        PathOperation.difference,
        Path()..addOval(r),
        Path()..addOval(Rect.fromLTWH(x(0.3), y(-0.08), w * 0.85, h * 0.85)),
      );
    case 'drop':
      p.moveTo(x(0.5), y(0.02));
      p.cubicTo(x(0.62), y(0.25), x(0.92), y(0.45), x(0.92), y(0.66));
      p.cubicTo(x(0.92), y(0.86), x(0.74), y(0.98), x(0.5), y(0.98));
      p.cubicTo(x(0.26), y(0.98), x(0.08), y(0.86), x(0.08), y(0.66));
      p.cubicTo(x(0.08), y(0.45), x(0.38), y(0.25), x(0.5), y(0.02));
      p.close();
      return p;
    case 'cloud':
      p.addOval(Rect.fromLTWH(x(0.04), y(0.42), w * 0.36, h * 0.36));
      p.addOval(Rect.fromLTWH(x(0.22), y(0.18), w * 0.44, h * 0.46));
      p.addOval(Rect.fromLTWH(x(0.50), y(0.34), w * 0.44, h * 0.42));
      p.addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(x(0.14), y(0.52), w * 0.72, h * 0.30), Radius.circular(h * 0.15)));
      return p;
    case 'bubble':
      p.addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(x(0.0), y(0.06), w, h * 0.66), Radius.circular(h * 0.2)));
      p.moveTo(x(0.2), y(0.68));
      p.lineTo(x(0.52), y(0.68));
      p.lineTo(x(0.2), y(0.98));
      p.close();
      return p;
    case 'crown':
      return poly(const [
        [0.0, 0.85],
        [0.0, 0.25],
        [0.25, 0.5],
        [0.5, 0.1],
        [0.75, 0.5],
        [1.0, 0.25],
        [1.0, 0.85]
      ]);
    case 'flower':
      {
        final c = r.center;
        for (var i = 0; i < 6; i++) {
          final a = i * pi / 3;
          final pc = Offset(c.dx + w * 0.29 * cos(a), c.dy + h * 0.29 * sin(a));
          p.addOval(Rect.fromCenter(center: pc, width: w * 0.38, height: h * 0.38));
        }
        p.addOval(Rect.fromCenter(center: c, width: w * 0.36, height: h * 0.36));
        return p;
      }
    case 'circle':
    default:
      p.addOval(r);
      return p;
  }
}

class ShapePainter extends CustomPainter {
  final String id;
  final Color color;
  const ShapePainter(this.id, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final path = avatarShapePath(id, r.deflate(min(size.width, size.height) * 0.04));
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(covariant ShapePainter old) => old.id != id || old.color != color;
}

class StrokePainter extends CustomPainter {
  final List<AvatarStroke> strokes;
  const StrokePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height);
    for (final st in strokes) {
      if (st.pts.isEmpty) continue;
      final paint = Paint()
        ..color = Color(st.color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, st.w * s)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;
      if (st.pts.length == 1) {
        final o = st.pts.first;
        canvas.drawCircle(Offset(o.dx * s, o.dy * s), max(0.5, st.w * s / 2),
            Paint()..color = Color(st.color));
        continue;
      }
      final path = Path()..moveTo(st.pts.first.dx * s, st.pts.first.dy * s);
      for (var i = 1; i < st.pts.length - 1; i++) {
        final a = st.pts[i], b = st.pts[i + 1];
        path.quadraticBezierTo(a.dx * s, a.dy * s, (a.dx + b.dx) / 2 * s, (a.dy + b.dy) / 2 * s);
      }
      final l = st.pts.last;
      path.lineTo(l.dx * s, l.dy * s);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant StrokePainter old) => true;
}
