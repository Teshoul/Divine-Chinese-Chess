import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'avatar_model.dart';
import 'avatar_view.dart';
import 'fly.dart';
import 'img_util.dart';
import 'settings.dart';
import 'strings.dart';
import 'ui.dart';

/// 头像库里每个头像格子的 key（飞行动画要找到它的落点）
final Map<String, GlobalKey> avatarTileKeys = <String, GlobalKey>{};
GlobalKey avatarTileKey(String p) => avatarTileKeys.putIfAbsent(p, () => GlobalKey());

/// 正在飞向头像库的那张头像；飞到之前，它在头像库里的格子是隐藏的
final ValueNotifier<String?> avatarInFlight = ValueNotifier<String?>(null);

/// 头像库上传成功后把图片路径放进来，主页收到就会打开编辑页
final ValueNotifier<String?> avatarEditRequest = ValueNotifier<String?>(null);

const List<int> _kPalette = [
  0xFFFFFFFF, 0xFF000000, 0xFFE53935, 0xFFFB8C00, 0xFFFDD835, 0xFF43A047,
  0xFF00ACC1, 0xFF1E88E5, 0xFF8E24AA, 0xFFEC407A, 0xFF8D6E63, 0xFF90A4AE,
];

double _wrap180(double r) {
  while (r > 180) {
    r -= 360;
  }
  while (r < -180) {
    r += 360;
  }
  return r;
}

/// 应用内头像编辑页：裁剪 / 调色 / 涂鸦 / 图形 / 贴纸 / 文字，全部实时预览，动图照常播放
class AvatarEditorPage extends StatefulWidget {
  final String path;
  final VoidCallback onCancel;
  final void Function(String path, AvatarEdit edit, Rect from) onDone;
  const AvatarEditorPage({
    super.key,
    required this.path,
    required this.onCancel,
    required this.onDone,
  });

  @override
  State<AvatarEditorPage> createState() => _AvatarEditorPageState();
}

class _AvatarEditorPageState extends State<AvatarEditorPage> {
  AvatarEdit edit = AvatarEdit();
  final List<String> _undo = <String>[];
  int tool = 0; // 0 裁剪 1 调色 2 涂鸦 3 图形 4 贴纸 5 文字
  int? sel;
  int penColor = 0xFFFF5252;
  double penW = 0.03;
  int shapeColor = 0xFFFFFFFF;
  double _cover = 1;
  final GlobalKey _frameKey = GlobalKey();
  final GlobalKey _boundaryKey = GlobalKey();
  final Set<String> _tmp = <String>{};
  final List<String> _stickers = <String>[];
  bool _busy = false;
  bool _confirmed = false;
  AvatarStroke? _cur;
  int _ptrs = 0;
  double _z0 = 1, _r0 = 0;

  static const List<IconData> _toolIcons = [
    Icons.crop_rotate,
    Icons.tune,
    Icons.brush,
    Icons.category,
    Icons.emoji_emotions,
    Icons.text_fields,
  ];
  static const List<String> _toolNames = ['裁剪', '调色', '涂鸦', '图形', '贴纸', '文字'];

  @override
  void initState() {
    super.initState();
    imageNaturalSize(widget.path).then((sz) {
      if (!mounted || sz == null || sz.width <= 0 || sz.height <= 0) return;
      final ar = sz.width / sz.height;
      final cover = max(ar, 1 / ar).clamp(1.0, 8.0).toDouble();
      setState(() {
        _cover = cover;
        edit.zoom = cover;
      });
    });
  }

  @override
  void dispose() {
    if (!_confirmed) {
      for (final t in _tmp) {
        try {
          File(t).deleteSync();
        } catch (_) {}
      }
    }
    super.dispose();
  }

  // ───────────── 撤销 ─────────────

  void _push() {
    _undo.add(jsonEncode(edit.toJson()));
    if (_undo.length > 60) _undo.removeAt(0);
  }

  void _doUndo() {
    if (_undo.isEmpty) return;
    final j = jsonDecode(_undo.removeLast());
    setState(() {
      edit = AvatarEdit.fromJson(Map<String, dynamic>.from(j as Map));
      sel = null;
    });
  }

  // ───────────── 手势 ─────────────

  Offset _norm(Offset p, double m, double s) => Offset((p.dx - m) / s, (p.dy - m) / s);

  int? _hit(Offset p, double m, double s) {
    final q = _norm(p, m, s);
    for (var i = edit.items.length - 1; i >= 0; i--) {
      final it = edit.items[i];
      final sz = 0.26 * it.scale;
      final bw = it.kind == 'text' ? sz * 3 : sz;
      final d = q - Offset(it.x, it.y);
      final a = -it.rot * pi / 180;
      final lx = d.dx * cos(a) - d.dy * sin(a);
      final ly = d.dx * sin(a) + d.dy * cos(a);
      final pad = 12 / s;
      if (lx.abs() <= bw / 2 + pad && ly.abs() <= sz / 2 + pad) return i;
    }
    return null;
  }

  void _down(Offset p, double m, double s) {
    _ptrs++;
    if (_ptrs != 1) return;
    if (tool == 2) {
      _push();
      final st = AvatarStroke(penColor, penW, [_norm(p, m, s)]);
      setState(() {
        edit.strokes.add(st);
        _cur = st;
      });
    } else if (tool >= 3) {
      final i = _hit(p, m, s);
      if (i != sel) setState(() => sel = i);
    }
  }

  void _move(Offset p, double m, double s) {
    final st = _cur;
    if (tool == 2 && st != null && _ptrs == 1) {
      final o = _norm(p, m, s);
      if ((o - st.pts.last).distance * s > 1.5) setState(() => st.pts.add(o));
    }
  }

  void _up() {
    if (_ptrs > 0) _ptrs--;
    if (_ptrs == 0 && _cur != null) setState(() => _cur = null);
  }

  void _scaleStart(ScaleStartDetails d) {
    if (tool == 0) {
      if (_ptrs <= 1) _push();
      _z0 = edit.zoom;
      _r0 = edit.rot;
    } else if (tool >= 3 && sel != null && sel! < edit.items.length) {
      if (_ptrs <= 1) _push();
      final it = edit.items[sel!];
      _z0 = it.scale;
      _r0 = it.rot;
    }
  }

  void _scaleUpdate(ScaleUpdateDetails d, double s) {
    if (tool == 0) {
      setState(() {
        edit.ox += d.focalPointDelta.dx / s;
        edit.oy += d.focalPointDelta.dy / s;
        if (d.pointerCount >= 2) {
          edit.zoom = (_z0 * d.scale).clamp(0.2, 12.0).toDouble();
          edit.rot = _wrap180(_r0 + d.rotation * 180 / pi);
        }
      });
    } else if (tool >= 3 && sel != null && sel! < edit.items.length) {
      final it = edit.items[sel!];
      setState(() {
        it.x = (it.x + d.focalPointDelta.dx / s).clamp(-0.3, 1.3).toDouble();
        it.y = (it.y + d.focalPointDelta.dy / s).clamp(-0.3, 1.3).toDouble();
        if (d.pointerCount >= 2) {
          it.scale = (_z0 * d.scale).clamp(0.2, 6.0).toDouble();
          it.rot = _wrap180(_r0 + d.rotation * 180 / pi);
        }
      });
    }
  }

  // ───────────── 图形 / 贴纸 / 文字 ─────────────

  void _addItem(AvatarItem it) {
    _push();
    setState(() {
      edit.items.add(it);
      sel = edit.items.length - 1;
    });
  }

  AvatarItem? get _selItem =>
      (sel != null && sel! >= 0 && sel! < edit.items.length) ? edit.items[sel!] : null;

  void _delSel() {
    if (_selItem == null) return;
    _push();
    setState(() {
      edit.items.removeAt(sel!);
      sel = null;
    });
  }

  void _dupSel() {
    final it = _selItem;
    if (it == null) return;
    _push();
    setState(() {
      edit.items.add(AvatarItem(
        kind: it.kind,
        id: it.id,
        x: min(1.2, it.x + 0.06),
        y: min(1.2, it.y + 0.06),
        scale: it.scale,
        rot: it.rot,
        color: it.color,
        flip: it.flip,
      ));
      sel = edit.items.length - 1;
    });
  }

  void _frontSel() {
    final it = _selItem;
    if (it == null) return;
    _push();
    setState(() {
      edit.items.removeAt(sel!);
      edit.items.add(it);
      sel = edit.items.length - 1;
    });
  }

  void _flipSel() {
    final it = _selItem;
    if (it == null) return;
    _push();
    setState(() => it.flip = !it.flip);
  }

  Future<void> _addSticker() async {
    final p = await pickImageChoose(context);
    if (p == null || !mounted) return;
    _tmp.add(p);
    _stickers.add(p);
    _addItem(AvatarItem(kind: 'sticker', id: p, scale: 1.5));
  }

  Future<String?> _askText(String init) {
    final c = TextEditingController(text: init);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('输入文字')),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 12,
          decoration: const InputDecoration(isDense: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('取消'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim().replaceAll('\n', ' ')),
            child: Text(tr('确定')),
          ),
        ],
      ),
    );
  }

  Future<void> _addText() async {
    final v = await _askText('');
    if (v == null || v.isEmpty || !mounted) return;
    _addItem(AvatarItem(kind: 'text', id: v, scale: 2.2, color: shapeColor));
  }

  Future<void> _editText() async {
    final it = _selItem;
    if (it == null || it.kind != 'text') return;
    final v = await _askText(it.id);
    if (v == null || v.isEmpty || !mounted) return;
    _push();
    setState(() => it.id = v);
  }

  // ───────────── 确定 ─────────────

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      sel = null;
    });
    await WidgetsBinding.instance.endOfFrame;
    String? snapPath;
    try {
      final ro = _boundaryKey.currentContext?.findRenderObject();
      if (ro is RenderRepaintBoundary) {
        final ratio = (256 / max(ro.size.width, 1.0)).clamp(0.5, 4.0).toDouble();
        final img = await ro.toImage(pixelRatio: ratio);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        img.dispose();
        if (data != null) {
          final dir = await getApplicationDocumentsDirectory();
          final f = File('${dir.path}/avsnap_${DateTime.now().millisecondsSinceEpoch}.png');
          await f.writeAsBytes(
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
              flush: true);
          snapPath = f.path;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    edit.snap = snapPath;
    final from = globalRectOf(_frameKey) ?? const Rect.fromLTWH(60, 200, 220, 220);
    final used = <String>{
      for (final i in edit.items)
        if (i.kind == 'sticker') i.id
    };
    for (final t in _tmp) {
      if (!used.contains(t)) {
        try {
          File(t).deleteSync();
        } catch (_) {}
      }
    }
    _tmp.clear();
    _confirmed = true;
    widget.onDone(widget.path, edit, from);
  }

  // ───────────── 界面小件 ─────────────

  Widget _sl(String label, double v, double lo, double hi, void Function(double) set) {
    return Row(
      children: [
        SizedBox(width: 58, child: Text(tr(label), style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Slider(
            value: v.clamp(lo, hi).toDouble(),
            min: lo,
            max: hi,
            onChangeStart: (_) => _push(),
            onChanged: (x) => setState(() => set(x)),
          ),
        ),
      ],
    );
  }

  Widget _colors(int cur, void Function(int) set) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in _kPalette)
          GestureDetector(
            onTap: () => set(c),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: cur == c ? app.primary : cs.outline.withOpacity(0.6),
                  width: cur == c ? 3 : 1,
                ),
              ),
            ),
          ),
        GestureDetector(
          onTap: () async {
            final v = await pickColorDialog(context, Color(cur));
            if (v != null && v != -1) set(v);
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(colors: [
                Color(0xFFFF5252),
                Color(0xFFFFEB3B),
                Color(0xFF69F0AE),
                Color(0xFF40C4FF),
                Color(0xFFE040FB),
                Color(0xFFFF5252),
              ]),
              border: Border.all(color: cs.outline.withOpacity(0.6)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _btn(IconData icon, String label, VoidCallback? onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 36),
      ),
      icon: Icon(icon, size: 18),
      label: Text(tr(label), style: const TextStyle(fontSize: 13)),
    );
  }

  Widget _hint(String s) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(tr(s), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
    );
  }

  Widget _title(String s) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(tr(s), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );

  Widget _toolChip(int i) {
    final on = tool == i;
    final cs = Theme.of(context).colorScheme;
    final fg = on
        ? (app.primary.computeLuminance() > 0.5 ? Colors.black87 : Colors.white)
        : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() {
          tool = i;
          if (i < 3) sel = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? app.primary : cs.onSurface.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? Colors.white54 : cs.outline.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_toolIcons[i], size: 18, color: fg),
              const SizedBox(width: 6),
              Text(tr(_toolNames[i]),
                  style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────── 各工具的面板 ─────────────

  Widget _panelCrop() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hint('单指拖动图片，双指缩放 / 旋转；框外的部分会半透明显示出来'),
        _sl('缩放', edit.zoom, 0.2, 8, (v) => edit.zoom = v),
        _sl('旋转', edit.rot, -180, 180, (v) => edit.rot = v),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _btn(Icons.fit_screen, '显示整图', () {
              _push();
              setState(() {
                edit.zoom = 1;
                edit.ox = 0;
                edit.oy = 0;
              });
            }),
            _btn(Icons.crop_free, '填满画面', () {
              _push();
              setState(() {
                edit.zoom = _cover;
                edit.ox = 0;
                edit.oy = 0;
              });
            }),
            _btn(Icons.flip, '水平翻转', () {
              _push();
              setState(() => edit.flipX = !edit.flipX);
            }),
            _btn(Icons.rotate_90_degrees_cw, '右转 90°', () {
              _push();
              setState(() => edit.rot = _wrap180(edit.rot + 90));
            }),
            _btn(Icons.restart_alt, '重置', () {
              _push();
              setState(() {
                edit.zoom = _cover;
                edit.ox = 0;
                edit.oy = 0;
                edit.rot = 0;
                edit.flipX = false;
              });
            }),
          ],
        ),
      ],
    );
  }

  Widget _panelAdjust() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sl('饱和度', edit.sat, 0, 2, (v) => edit.sat = v),
        _sl('亮度', edit.bri, -0.5, 0.5, (v) => edit.bri = v),
        _sl('对比度', edit.con, 0.5, 1.5, (v) => edit.con = v),
        _sl('色相', edit.hue, -180, 180, (v) => edit.hue = v),
        _title('滤镜'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < kAvatarFilters.length; i++)
              GestureDetector(
                onTap: () {
                  _push();
                  setState(() => edit.filter = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: edit.filter == i ? app.primary.withOpacity(0.4) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: edit.filter == i ? app.primary : cs.outline.withOpacity(0.6),
                      width: edit.filter == i ? 2 : 1,
                    ),
                  ),
                  child: Text(tr(kAvatarFilters[i]), style: const TextStyle(fontSize: 13)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _btn(Icons.restart_alt, '重置调色', () {
          _push();
          setState(() {
            edit.sat = 1;
            edit.bri = 0;
            edit.con = 1;
            edit.hue = 0;
            edit.filter = 0;
          });
        }),
      ],
    );
  }

  Widget _panelDraw() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hint('在头像上直接用手指涂画'),
        _colors(penColor, (c) => setState(() => penColor = c)),
        const SizedBox(height: 4),
        _sl('笔粗', penW, 0.008, 0.09, (v) => penW = v),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _btn(Icons.undo, '撤销一笔', edit.strokes.isEmpty
                ? null
                : () {
                    _push();
                    setState(() => edit.strokes.removeLast());
                  }),
            _btn(Icons.delete_sweep, '清空涂鸦', edit.strokes.isEmpty
                ? null
                : () {
                    _push();
                    setState(() => edit.strokes.clear());
                  }),
          ],
        ),
      ],
    );
  }

  Widget _itemControls() {
    final it = _selItem;
    if (it == null) {
      return _hint('点一下放在头像上的东西可以选中；拖动移动，双指缩放 / 旋转');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('已选中'),
        _sl('大小', it.scale, 0.2, 6, (v) => it.scale = v),
        _sl('旋转', it.rot, -180, 180, (v) => it.rot = v),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _btn(Icons.flip, '翻转', _flipSel),
            _btn(Icons.flip_to_front, '置顶', _frontSel),
            _btn(Icons.copy, '复制', _dupSel),
            _btn(Icons.delete_outline, '删除', _delSel),
            if (it.kind == 'text') _btn(Icons.edit, '改文字', _editText),
          ],
        ),
      ],
    );
  }

  void _setItemColor(int c) {
    setState(() {
      shapeColor = c;
      final it = _selItem;
      if (it != null && it.kind != 'sticker') it.color = c;
    });
  }

  Widget _panelShapes() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _colors(shapeColor, _setItemColor),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in kShapeIds)
              GestureDetector(
                onTap: () => _addItem(AvatarItem(kind: 'shape', id: id, color: shapeColor)),
                child: Container(
                  width: 46,
                  height: 46,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: shapeColor == 0xFFFFFFFF || shapeColor == 0xFFFDD835
                        ? Colors.black54
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outline.withOpacity(0.4)),
                  ),
                  child: CustomPaint(painter: ShapePainter(id, Color(shapeColor))),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        _itemControls(),
      ],
    );
  }

  Widget _panelSticker() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hint('贴纸就是你自己上传的图片（支持 PNG / GIF / SVG 等）'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _addSticker,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(0, 38)),
              icon: const Icon(Icons.add_photo_alternate, size: 18),
              label: Text(tr('上传贴纸')),
            ),
            for (final p in _stickers)
              GestureDetector(
                onTap: () => _addItem(AvatarItem(kind: 'sticker', id: p, scale: 1.5)),
                child: Container(
                  width: 46,
                  height: 46,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outline.withOpacity(0.4)),
                  ),
                  child: imageFileWidget(p, fit: BoxFit.contain, cacheWidth: 120),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        _itemControls(),
      ],
    );
  }

  Widget _panelText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _colors(shapeColor, _setItemColor),
        const SizedBox(height: 10),
        _btn(Icons.title, '添加文字', _addText),
        const SizedBox(height: 4),
        _itemControls(),
      ],
    );
  }

  Widget _panel() {
    switch (tool) {
      case 0:
        return _panelCrop();
      case 1:
        return _panelAdjust();
      case 2:
        return _panelDraw();
      case 3:
        return _panelShapes();
      case 4:
        return _panelSticker();
      default:
        return _panelText();
    }
  }

  Widget _canvas(double pa, double s) {
    final cs = Theme.of(context).colorScheme;
    final m = (pa - s) / 2;
    return SizedBox(
      width: pa,
      height: pa,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _down(e.localPosition, m, s),
          onPointerMove: (e) => _move(e.localPosition, m, s),
          onPointerUp: (e) => _up(),
          onPointerCancel: (e) => _up(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _scaleStart,
            onScaleUpdate: (d) => _scaleUpdate(d, s),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: ColoredBox(color: cs.surfaceContainerHighest)),
                SizedBox(
                  key: _frameKey,
                  width: s,
                  height: s,
                  child: AvatarView(
                    path: widget.path,
                    edit: edit,
                    showOutside: tool == 0,
                    boundaryKey: _boundaryKey,
                    selected: tool >= 3 ? sel : null,
                    radiusFrac: 0.2,
                  ),
                ),
                IgnorePointer(
                  child: SizedBox(
                    width: s,
                    height: s,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(s * 0.2),
                        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      final w = cons.maxWidth;
      final h = cons.maxHeight;
      final pa = max(160.0, min(w - 24, (h - 52 - 8 - 8 - 44) * 0.55));
      final s = pa * 0.8;
      return Column(
        children: [
          // 这一行的左边留给左上角的返回按钮，它始终不动
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(62, 0, 10, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(tr('编辑头像'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    onPressed: _undo.isEmpty ? null : _doUndo,
                    tooltip: tr('撤销'),
                    icon: const Icon(Icons.undo),
                  ),
                  const SizedBox(width: 2),
                  FilledButton(
                    onPressed: _busy ? null : _confirm,
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        minimumSize: const Size(0, 40)),
                    child: Text(tr('确定上传')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _canvas(pa, s),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [for (var i = 0; i < _toolNames.length; i++) _toolChip(i)],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: _panel(),
            ),
          ),
        ],
      );
    });
  }
}
