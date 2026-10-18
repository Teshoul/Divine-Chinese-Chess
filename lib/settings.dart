import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Preset {
  final String id, name, hidText;
  final Color seed, boardBg, boardLine, red, black, faceRed, faceBlack, hid, hidInk;
  final bool glow;
  final List<Color> bgL, bgD, tiles;
  const Preset({
    required this.id,
    required this.name,
    required this.hidText,
    required this.seed,
    required this.boardBg,
    required this.boardLine,
    required this.red,
    required this.black,
    required this.faceRed,
    required this.faceBlack,
    required this.hid,
    required this.hidInk,
    required this.glow,
    required this.bgL,
    required this.bgD,
    required this.tiles,
  });
}

const List<Preset> kPresets = [
  Preset(
    id: 'mono',
    name: '黑白',
    hidText: '暗',
    seed: Color(0xFF616161),
    boardBg: Color(0xFFE6E6E6),
    boardLine: Color(0xFF222222),
    red: Color(0xFF111111),
    black: Color(0xFFF2F2F2),
    faceRed: Color(0xFFFFFFFF),
    faceBlack: Color(0xFF1E1E1E),
    hid: Color(0xFF9E9E9E),
    hidInk: Color(0xFF3A3A3A),
    glow: false,
    bgL: [Color(0xFFFFFFFF), Color(0xFFDADADA)],
    bgD: [Color(0xFF202020), Color(0xFF050505)],
    tiles: [Color(0xFF212121), Color(0xFF424242), Color(0xFF616161), Color(0xFF757575)],
  ),
  Preset(
    id: 'guofeng',
    name: '古风',
    hidText: '暗',
    seed: Color(0xFFB23A2E),
    boardBg: Color(0xFFE9CB93),
    boardLine: Color(0xFF5B3A1E),
    red: Color(0xFFC62828),
    black: Color(0xFF212121),
    faceRed: Color(0xFFF6E3B4),
    faceBlack: Color(0xFFF6E3B4),
    hid: Color(0xFFC9A66B),
    hidInk: Color(0xFF6D4C41),
    glow: false,
    bgL: [Color(0xFFF7EBD3), Color(0xFFE8D3A8)],
    bgD: [Color(0xFF2A1F17), Color(0xFF140E0A)],
    tiles: [Color(0xFFB23A2E), Color(0xFF4E6B52), Color(0xFF6D4C41), Color(0xFFC08A2B)],
  ),
  Preset(
    id: 'starry',
    name: '星空',
    hidText: '星',
    seed: Color(0xFF5E35B1),
    boardBg: Color(0xFF1B2145),
    boardLine: Color(0xFF8FA4FF),
    red: Color(0xFFFF7A90),
    black: Color(0xFF9FD3FF),
    faceRed: Color(0xFF2A3166),
    faceBlack: Color(0xFF22295A),
    hid: Color(0xFF3B4290),
    hidInk: Color(0xFFB7C0FF),
    glow: true,
    bgL: [Color(0xFFE8E4FF), Color(0xFFC9D6FF)],
    bgD: [Color(0xFF0B0B2B), Color(0xFF1D1048)],
    tiles: [Color(0xFF5E35B1), Color(0xFF3949AB), Color(0xFF8E24AA), Color(0xFF1E88E5)],
  ),
  Preset(
    id: 'tech',
    name: '科技',
    hidText: '密',
    seed: Color(0xFF00ACC1),
    boardBg: Color(0xFF0F1B22),
    boardLine: Color(0xFF00E5FF),
    red: Color(0xFFFF4081),
    black: Color(0xFF18FFFF),
    faceRed: Color(0xFF152A33),
    faceBlack: Color(0xFF102229),
    hid: Color(0xFF1E3A46),
    hidInk: Color(0xFF4DD0E1),
    glow: true,
    bgL: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
    bgD: [Color(0xFF050B0F), Color(0xFF0A1A22)],
    tiles: [Color(0xFF00ACC1), Color(0xFF00897B), Color(0xFF1565C0), Color(0xFF6200EA)],
  ),
  Preset(
    id: 'furry',
    name: '福瑞',
    hidText: '爪',
    seed: Color(0xFFFF8A65),
    boardBg: Color(0xFFFFE9CC),
    boardLine: Color(0xFF8D5524),
    red: Color(0xFFE64A19),
    black: Color(0xFF5D4037),
    faceRed: Color(0xFFFFF3E0),
    faceBlack: Color(0xFFFFF3E0),
    hid: Color(0xFFFFB74D),
    hidInk: Color(0xFF8D5524),
    glow: false,
    bgL: [Color(0xFFFFF3E0), Color(0xFFFFD9B8)],
    bgD: [Color(0xFF2B1B14), Color(0xFF3B2418)],
    tiles: [Color(0xFFFF8A65), Color(0xFFFFB74D), Color(0xFFF06292), Color(0xFF7E57C2)],
  ),
];

double _d(dynamic v, double def) => v is num ? v.toDouble() : def;
int _i(dynamic v, int def, int hi) {
  final x = v is num ? v.toInt() : def;
  return x < 0 ? 0 : (x > hi ? hi : x);
}

class ImgLayer {
  String? path;
  double scale, dx, dy, rot, skewX, skewY, opacity, blur;
  ImgLayer({
    this.path,
    this.scale = 1,
    this.dx = 0,
    this.dy = 0,
    this.rot = 0,
    this.skewX = 0,
    this.skewY = 0,
    this.opacity = 1,
    this.blur = 0,
  });

  void resetTransform() {
    scale = 1;
    dx = 0;
    dy = 0;
    rot = 0;
    skewX = 0;
    skewY = 0;
    opacity = 1;
    blur = 0;
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'scale': scale,
        'dx': dx,
        'dy': dy,
        'rot': rot,
        'sx': skewX,
        'sy': skewY,
        'op': opacity,
        'blur': blur,
      };

  static ImgLayer fromJson(Map<String, dynamic> j) => ImgLayer(
        path: j['path'] as String?,
        scale: _d(j['scale'], 1),
        dx: _d(j['dx'], 0),
        dy: _d(j['dy'], 0),
        rot: _d(j['rot'], 0),
        skewX: _d(j['sx'], 0),
        skewY: _d(j['sy'], 0),
        opacity: _d(j['op'], 1),
        blur: _d(j['blur'], 0),
      );
}

class AppSettings extends ChangeNotifier {
  String presetId = 'guofeng';
  int themeMode = 0; // 0 跟随系统 1 浅色 2 深色
  int uiStyle = 3; // 0 圆润 1 方正 2 简洁 3 立体
  int toggleShape = 0; // 0 圆角 1 方角
  final Map<String, int> custom = {};
  final Map<String, ImgLayer> layers = {
    'global': ImgLayer(),
    'home': ImgLayer(),
    'game': ImgLayer(),
  };

  String name = '棋手';
  String uid = '10001';
  String bio = '';
  String birthday = '';
  String? avatar;
  int borderColor = 0xFF26A69A;
  int wins = 0, losses = 0, launches = 0;

  Brightness sysB = Brightness.light;
  SharedPreferences? _sp;
  Timer? _timer;

  Preset get preset {
    for (final p in kPresets) {
      if (p.id == presetId) return p;
    }
    return kPresets.first;
  }

  bool get isDark =>
      themeMode == 2 || (themeMode == 0 && sysB == Brightness.dark);

  Color ov(String k, Color d) {
    final v = custom[k];
    return v == null ? d : Color(v);
  }

  Color get primary => ov('primary', preset.seed);
  Color get boardBg => ov('boardBg', preset.boardBg);
  Color get boardLine => ov('boardLine', preset.boardLine);
  Color get red => ov('red', preset.red);
  Color get black => ov('black', preset.black);
  Color get faceRed => preset.faceRed;
  Color get faceBlack => preset.faceBlack;
  bool get glow => preset.glow;
  Color get bgTop => ov('bgTop', isDark ? preset.bgD[0] : preset.bgL[0]);
  Color get bgBottom => ov('bgBottom', isDark ? preset.bgD[1] : preset.bgL[1]);

  double get cardR => const [26.0, 6.0, 14.0, 12.0][uiStyle];
  double get btnR => const [30.0, 6.0, 12.0, 12.0][uiStyle];

  Future<void> load() async {
    _sp = await SharedPreferences.getInstance();
    final s = _sp!.getString('app_v1');
    if (s != null) {
      try {
        _read(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {}
    }
    launches++;
    _write();
  }

  void _read(Map<String, dynamic> j) {
    presetId = (j['preset'] ?? presetId) as String;
    themeMode = _i(j['mode'], themeMode, 2);
    uiStyle = _i(j['style'], uiStyle, 3);
    toggleShape = _i(j['shape'], toggleShape, 1);
    custom.clear();
    final cm = j['custom'];
    if (cm is Map) {
      cm.forEach((k, v) {
        if (v is num) custom[k.toString()] = v.toInt();
      });
    }
    final ly = j['layers'];
    if (ly is Map) {
      ly.forEach((k, v) {
        if (v is Map) {
          layers[k.toString()] = ImgLayer.fromJson(Map<String, dynamic>.from(v));
        }
      });
    }
    name = (j['name'] ?? name) as String;
    uid = (j['uid'] ?? uid) as String;
    bio = (j['bio'] ?? bio) as String;
    birthday = (j['birthday'] ?? birthday) as String;
    avatar = j['avatar'] as String?;
    borderColor = j['border'] is num ? (j['border'] as num).toInt() : borderColor;
    wins = _i(j['wins'], wins, 99999999);
    losses = _i(j['losses'], losses, 99999999);
    launches = _i(j['launches'], launches, 99999999);
  }

  Map<String, dynamic> _json() => {
        'preset': presetId,
        'mode': themeMode,
        'style': uiStyle,
        'shape': toggleShape,
        'custom': custom,
        'layers': {for (final e in layers.entries) e.key: e.value.toJson()},
        'name': name,
        'uid': uid,
        'bio': bio,
        'birthday': birthday,
        'avatar': avatar,
        'border': borderColor,
        'wins': wins,
        'losses': losses,
        'launches': launches,
      };

  void _write() {
    _sp?.setString('app_v1', jsonEncode(_json()));
  }

  void _later() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), _write);
  }

  /// 修改后通知界面刷新并保存
  void change(VoidCallback f) {
    f();
    notifyListeners();
    _later();
  }

  /// 只保存，不刷新（用于输入框）
  void quiet(VoidCallback f) {
    f();
    _later();
  }
}

final AppSettings app = AppSettings();

Future<String?> pickImage() async {
  try {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final dot = x.path.lastIndexOf('.');
    final ext = (dot > 0 && x.path.length - dot <= 5) ? x.path.substring(dot) : '.jpg';
    final f = await File(x.path)
        .copy('${dir.path}/img_${DateTime.now().millisecondsSinceEpoch}$ext');
    return f.path;
  } catch (_) {
    return null;
  }
}
