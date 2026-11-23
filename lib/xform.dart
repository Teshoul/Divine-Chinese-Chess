import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 背景图 / 头像底图共用的“图片变换”：
/// 整体缩放、单独拉宽 / 拉高、旋转、倾斜、位移，以及四个角各自的透视变形（类似画世界 Pro 的自由变形）。
double _fd(dynamic v, double d) => (v is num && v.isFinite) ? v.toDouble() : d;
double _r4(double v) => (v * 10000).round() / 10000;

class Xf {
  double scale; // 整体缩放
  double sx, sy; // 单独的宽 / 高倍数（拉长拉宽）
  double rot; // 旋转角度
  double skewX, skewY; // 倾斜
  double dx, dy; // 位移，占整个画面宽 / 高的比例
  bool flipX;
  double ar; // 图片宽高比（宽 / 高），0 = 还不知道
  final List<double> p; // 四个角的偏移 TL TR BR BL 的 x,y，占图片宽 / 高的比例

  Xf({
    this.scale = 1,
    this.sx = 1,
    this.sy = 1,
    this.rot = 0,
    this.skewX = 0,
    this.skewY = 0,
    this.dx = 0,
    this.dy = 0,
    this.flipX = false,
    this.ar = 0,
    List<double>? p,
  }) : p = p ?? List<double>.filled(8, 0);

  bool get hasPersp => p.any((v) => v.abs() > 1e-4);

  void resetPersp() {
    for (var i = 0; i < 8; i++) {
      p[i] = 0;
    }
  }

  /// 重置变形（拉伸 / 倾斜 / 透视），不动位置和缩放
  void resetWarp() {
    sx = 1;
    sy = 1;
    skewX = 0;
    skewY = 0;
    resetPersp();
  }

  void resetAll() {
    scale = 1;
    dx = 0;
    dy = 0;
    rot = 0;
    flipX = false;
    resetWarp();
  }

  /// 写进 JSON（和旧版背景图字段兼容：scale dx dy rot sx(=倾斜X) sy(=倾斜Y)）
  void writeBg(Map<String, dynamic> m) {
    m['scale'] = _r4(scale);
    m['dx'] = _r4(dx);
    m['dy'] = _r4(dy);
    m['rot'] = _r4(rot);
    m['sx'] = _r4(skewX);
    m['sy'] = _r4(skewY);
    m['stx'] = _r4(sx);
    m['sty'] = _r4(sy);
    m['pp'] = [for (final v in p) _r4(v)];
    m['ar'] = _r4(ar);
  }

  void readBg(Map<String, dynamic> j) {
    scale = _fd(j['scale'], 1);
    dx = _fd(j['dx'], 0);
    dy = _fd(j['dy'], 0);
    rot = _fd(j['rot'], 0);
    skewX = _fd(j['sx'], 0);
    skewY = _fd(j['sy'], 0);
    sx = _fd(j['stx'], 1);
    sy = _fd(j['sty'], 1);
    ar = _fd(j['ar'], 0);
    final pp = j['pp'];
    for (var i = 0; i < 8; i++) {
      p[i] = (pp is List && i < pp.length) ? _fd(pp[i], 0) : 0;
    }
  }
}

/// 图片按“完整显示”放进 box 后占的矩形
Rect xfContainRect(Size box, double ar) {
  if (ar <= 0) return Offset.zero & box;
  var w = box.width, h = box.width / ar;
  if (h > box.height) {
    h = box.height;
    w = h * ar;
  }
  return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
}

List<Offset> _corners(Rect r) => [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];

/// 4 个源点 → 4 个目标点的透视矩阵
Matrix4 homography(List<Offset> src, List<Offset> dst) {
  // 8 个未知数 a b c d e f g h
  final m = List<List<double>>.generate(8, (_) => List<double>.filled(9, 0));
  for (var i = 0; i < 4; i++) {
    final x = src[i].dx, y = src[i].dy, u = dst[i].dx, v = dst[i].dy;
    m[i * 2] = [x, y, 1, 0, 0, 0, -x * u, -y * u, u];
    m[i * 2 + 1] = [0, 0, 0, x, y, 1, -x * v, -y * v, v];
  }
  for (var c = 0; c < 8; c++) {
    var piv = c;
    for (var r = c + 1; r < 8; r++) {
      if (m[r][c].abs() > m[piv][c].abs()) piv = r;
    }
    if (m[piv][c].abs() < 1e-9) return Matrix4.identity();
    final t = m[c];
    m[c] = m[piv];
    m[piv] = t;
    for (var r = 0; r < 8; r++) {
      if (r == c) continue;
      final f = m[r][c] / m[c][c];
      if (f == 0) continue;
      for (var k = c; k < 9; k++) {
        m[r][k] -= f * m[c][k];
      }
    }
  }
  final h = List<double>.generate(8, (i) => m[i][8] / m[i][i]);
  return Matrix4(
    h[0], h[3], 0, h[6], //
    h[1], h[4], 0, h[7], //
    0, 0, 1, 0, //
    h[2], h[5], 0, 1,
  );
}

Matrix4 _persp(Rect r, List<double> p) {
  final src = _corners(r);
  final dst = [
    for (var i = 0; i < 4; i++) src[i] + Offset(p[i * 2] * r.width, p[i * 2 + 1] * r.height),
  ];
  return homography(src, dst);
}

/// 仿射部分（缩放 / 拉伸 / 旋转 / 倾斜 / 位移），不含四角透视
Matrix4 xfAffine(Xf x, Size box) {
  final cx = box.width / 2, cy = box.height / 2;
  final co = cos(x.rot * pi / 180), si = sin(x.rot * pi / 180);
  final a11 = x.scale * (co - si * x.skewY);
  final a12 = x.scale * (co * x.skewX - si);
  final a21 = x.scale * (si + co * x.skewY);
  final a22 = x.scale * (si * x.skewX + co);
  final base = Matrix4(
      a11, a21, 0, 0, a12, a22, 0, 0, 0, 0, 1, 0, x.dx * box.width, x.dy * box.height, 0, 1);
  final m = Matrix4.translationValues(cx, cy, 0)
    ..multiply(base)
    ..multiply(Matrix4.diagonal3Values((x.flipX ? -1.0 : 1.0) * x.sx, x.sy, 1.0))
    ..multiply(Matrix4.translationValues(-cx, -cy, 0));
  return m;
}

/// 完整变换（含透视），直接交给 Transform(transform: …) 使用，坐标原点是 box 左上角
Matrix4 xfMatrix(Xf x, Size box) {
  final m = xfAffine(x, box);
  if (x.hasPersp) m.multiply(_persp(xfContainRect(box, x.ar), x.p));
  return m;
}

/// 图片四个角变换后的位置（TL TR BR BL），高亮框和手柄就画在这上面
List<Offset> xfQuad(Xf x, Size box) {
  final m = xfMatrix(x, box);
  return [
    for (final c in _corners(xfContainRect(box, x.ar))) MatrixUtils.transformPoint(m, c),
  ];
}

// ───────────── 手柄：命中 / 拖动 ─────────────

const int kHRot = 8;

class XfDrag {
  int h = -1;
  bool get active => h >= 0;
  late Xf _x0;
  late Matrix4 _inv0;
  late Offset _center0;
  late Offset _start;
  late Rect _r;

  List<Offset> _handlePts(List<Offset> q, bool warp) {
    final out = List<Offset>.filled(9, Offset.zero);
    for (var i = 0; i < 4; i++) {
      out[i] = q[i];
      out[4 + i] = (q[i] + q[(i + 1) % 4]) / 2;
    }
    final c = (q[0] + q[1] + q[2] + q[3]) / 4;
    final tm = out[4];
    final dir = tm - c;
    final len = dir.distance;
    out[kHRot] = len < 1 ? tm + const Offset(0, -34) : tm + dir / len * 34;
    return out;
  }

  /// 按下时尝试抓住手柄，抓到返回 true
  bool begin(Xf x, Size box, Offset pos, bool warp, {double reach = 24}) {
    final q = xfQuad(x, box);
    final pts = _handlePts(q, warp);
    var best = -1;
    var bd = reach;
    // 旋转手柄 > 角 > 边中点
    final order = warp ? [0, 1, 2, 3] : [kHRot, 0, 1, 2, 3, 4, 5, 6, 7];
    for (final i in order) {
      final d = (pts[i] - pos).distance;
      if (d <= bd) {
        bd = d;
        best = i;
        if (i == kHRot) break;
      }
    }
    if (best < 0) return false;
    h = best;
    _x0 = Xf(
      scale: x.scale,
      sx: x.sx,
      sy: x.sy,
      rot: x.rot,
      skewX: x.skewX,
      skewY: x.skewY,
      dx: x.dx,
      dy: x.dy,
      flipX: x.flipX,
      ar: x.ar,
      p: List<double>.from(x.p),
    );
    final aff = xfAffine(x, box);
    _inv0 = Matrix4.copy(aff);
    if (_inv0.invert() == 0) {
      h = -1;
      return false;
    }
    _center0 = MatrixUtils.transformPoint(aff, Offset(box.width / 2, box.height / 2));
    _start = pos;
    _r = xfContainRect(box, x.ar);
    return true;
  }

  void update(Xf x, Size box, Offset pos, bool warp) {
    if (h < 0) return;
    if (warp && h < 4) {
      final lp = MatrixUtils.transformPoint(_inv0, pos);
      final src = _corners(_r)[h];
      x.p[h * 2] = ((lp.dx - src.dx) / _r.width).clamp(-3.0, 3.0).toDouble();
      x.p[h * 2 + 1] = ((lp.dy - src.dy) / _r.height).clamp(-3.0, 3.0).toDouble();
    } else if (h == kHRot) {
      final a0 = atan2(_start.dy - _center0.dy, _start.dx - _center0.dx);
      final a1 = atan2(pos.dy - _center0.dy, pos.dx - _center0.dx);
      var r = _x0.rot + (a1 - a0) * 180 / pi;
      while (r > 180) {
        r -= 360;
      }
      while (r < -180) {
        r += 360;
      }
      x.rot = r;
    } else if (h < 4) {
      final d0 = max((_start - _center0).distance, 1.0);
      final d1 = (pos - _center0).distance;
      x.scale = (_x0.scale * d1 / d0).clamp(0.05, 20.0).toDouble();
    } else {
      // 边中点：只拉宽或只拉高
      final lp = MatrixUtils.transformPoint(_inv0, pos);
      final cx = _r.center.dx, cy = _r.center.dy;
      if (h == 4 || h == 6) {
        final base = max((_r.height / 2), 1.0);
        x.sy = (_x0.sy * ((lp.dy - cy).abs() / base)).clamp(0.05, 20.0).toDouble();
      } else {
        final base = max((_r.width / 2), 1.0);
        x.sx = (_x0.sx * ((lp.dx - cx).abs() / base)).clamp(0.05, 20.0).toDouble();
      }
    }
  }

  void end() => h = -1;

  /// 画高亮框用的手柄位置（和 begin 里一致）
  List<Offset> pointsFor(Xf x, Size box, bool warp) => _handlePts(xfQuad(x, box), warp);
}

/// 图片的高亮框 + 手柄 + 变形网格
class XfPainter extends CustomPainter {
  final Xf x;
  final bool warp;
  final int grabbed;
  final XfDrag helper;
  XfPainter(this.x, this.warp, this.grabbed, this.helper);

  @override
  void paint(Canvas canvas, Size size) {
    final q = xfQuad(x, size);
    final pts = helper.pointsFor(x, size, warp);
    final line = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..isAntiAlias = true;
    final shadow = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..isAntiAlias = true;
    final path = Path()..addPolygon(q, true);
    canvas.drawPath(path, shadow);
    canvas.drawPath(path, line);

    if (warp) {
      // 变形网格：3×3，一眼看出透视的走向
      final g = Paint()
        ..color = const Color(0xFFFFB300).withOpacity(0.8)
        ..strokeWidth = 1.0;
      for (var i = 1; i < 3; i++) {
        final t = i / 3;
        canvas.drawLine(Offset.lerp(q[0], q[1], t)!, Offset.lerp(q[3], q[2], t)!, g);
        canvas.drawLine(Offset.lerp(q[0], q[3], t)!, Offset.lerp(q[1], q[2], t)!, g);
      }
    } else {
      // 旋转手柄的连线
      canvas.drawLine(pts[4], pts[kHRot], line);
    }

    final fill = Paint()..color = Colors.white;
    final warpFill = Paint()..color = const Color(0xFFFFB300);
    for (var i = 0; i < 9; i++) {
      if (warp && i >= 4) continue;
      final on = i == grabbed;
      final c = pts[i];
      if (i == kHRot) {
        canvas.drawCircle(c, on ? 11 : 9, fill);
        canvas.drawCircle(c, on ? 11 : 9, line);
        canvas.drawArc(Rect.fromCircle(center: c, radius: 4), -2.4, 4.4, false, line);
      } else if (i < 4) {
        final r = on ? 10.0 : (warp ? 9.0 : 7.0);
        canvas.drawCircle(c, r + 1.5, shadow);
        canvas.drawCircle(c, r, warp ? warpFill : fill);
        canvas.drawCircle(c, r, line);
      } else {
        final r = Rect.fromCenter(center: c, width: on ? 14 : 11, height: on ? 14 : 11);
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), fill);
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), line);
      }
    }
  }

  @override
  bool shouldRepaint(covariant XfPainter old) => true;
}

// ───────────── 数值输入 ─────────────

/// 小数字输入框：滑块旁边可以直接打字输入精确数值
class NumBox extends StatefulWidget {
  final double value; // 显示值
  final double min, max;
  final int decimals;
  final String suffix;
  final ValueChanged<double> onChanged;
  final double width;
  const NumBox({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = -10000,
    this.max = 10000,
    this.decimals = 0,
    this.suffix = '',
    this.width = 78,
  });

  @override
  State<NumBox> createState() => _NumBoxState();
}

class _NumBoxState extends State<NumBox> {
  late final TextEditingController _c = TextEditingController(text: _fmt(widget.value));
  final FocusNode _f = FocusNode();

  String _fmt(double v) {
    final s = v.toStringAsFixed(widget.decimals);
    if (widget.decimals > 0 && s.contains('.')) {
      return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }

  @override
  void initState() {
    super.initState();
    _f.addListener(() {
      if (!_f.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant NumBox old) {
    super.didUpdateWidget(old);
    if (!_f.hasFocus) {
      final t = _fmt(widget.value);
      if (_c.text != t) _c.text = t;
    }
  }

  @override
  void dispose() {
    _f.dispose();
    _c.dispose();
    super.dispose();
  }

  void _commit() {
    final v = double.tryParse(_c.text.trim());
    if (v == null) {
      _c.text = _fmt(widget.value);
      return;
    }
    final x = v.clamp(widget.min, widget.max).toDouble();
    _c.text = _fmt(x);
    widget.onChanged(x);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: TextField(
        controller: _c,
        focusNode: _f,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        style: const TextStyle(fontSize: 13),
        onSubmitted: (_) => _commit(),
        decoration: InputDecoration(
          isDense: true,
          suffixText: widget.suffix.isEmpty ? null : widget.suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

/// 一行：名称 + 滑块 + 数值框。raw = 真实存储值，mul = 显示倍数（比如 100 表示显示成百分比）
class NumRow extends StatelessWidget {
  final String label;
  final double raw;
  final double sMin, sMax; // 滑块范围（真实值）
  final double nMin, nMax; // 手动输入范围（真实值）
  final double mul;
  final int decimals;
  final String suffix;
  final ValueChanged<double> onChanged;
  final VoidCallback? onStart;
  const NumRow({
    super.key,
    required this.label,
    required this.raw,
    required this.sMin,
    required this.sMax,
    required this.onChanged,
    this.nMin = -10000,
    this.nMax = 10000,
    this.mul = 1,
    this.decimals = 0,
    this.suffix = '',
    this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 62, child: Text(label, style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Slider(
            value: raw.clamp(sMin, sMax).toDouble(),
            min: sMin,
            max: sMax,
            onChangeStart: onStart == null ? null : (_) => onStart!(),
            onChanged: onChanged,
          ),
        ),
        NumBox(
          value: raw * mul,
          min: nMin * mul,
          max: nMax * mul,
          decimals: decimals,
          suffix: suffix,
          onChanged: (v) {
            onStart?.call();
            onChanged(v / mul);
          },
        ),
      ],
    );
  }
}
