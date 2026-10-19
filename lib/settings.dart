import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'festival.dart';

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

/// 隐藏主题（输入口令解锁）
const Preset kDivine = Preset(
  id: 'divine',
  name: '神',
  hidText: '神',
  seed: Color(0xFFD4A017),
  boardBg: Color(0xFF4A0A0C),
  boardLine: Color(0xFFFFD54F),
  red: Color(0xFFFF6659),
  black: Color(0xFFFFD54F),
  faceRed: Color(0xFF2E0709),
  faceBlack: Color(0xFF2E0709),
  hid: Color(0xFF6B1214),
  hidInk: Color(0xFFFFD54F),
  glow: true,
  bgL: [Color(0xFFFFF1C9), Color(0xFFFFC76B)],
  bgD: [Color(0xFF2B0505), Color(0xFF0A0000)],
  tiles: [Color(0xFFD32F2F), Color(0xFFFFB300), Color(0xFFB71C1C), Color(0xFFFFCA28)],
);

double _d(dynamic v, double def) => v is num ? v.toDouble() : def;
int _i(dynamic v, int def, int hi) {
  final x = v is num ? v.toInt() : def;
  return x < 0 ? 0 : (x > hi ? hi : x);
}

/// 轻量校验码（防手滑改数据，不是真正的加密）
String signText(String s) {
  var h1 = 0x811C9DC5;
  var h2 = 0x1B873593;
  for (final u in utf8.encode('Teshoul-Divine-Chinese-Chess|$s')) {
    h1 = ((h1 ^ u) * 0x01000193) & 0xFFFFFFFF;
    h2 = (((h2 + u) * 0x85EBCA6B) ^ (h2 >> 13)) & 0xFFFFFFFF;
  }
  return h1.toRadixString(16).padLeft(8, '0') + h2.toRadixString(16).padLeft(8, '0');
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

class AppSettings extends ChangeNotifier with WidgetsBindingObserver {
  String presetId = 'guofeng';
  int themeMode = 0; // 0 跟随系统 1 浅色 2 深色
  int uiStyle = 3; // 0 圆润 1 方正 2 简洁 3 立体
  int toggleShape = 0; // 0 圆角 1 方角
  int lang = 0; // 0 中文 1 English 2 日本語 3 Русский
  int fxMode = 0; // 切换动画 0 圆形扩散 1 渐变 2 无
  int animLevel = 2; // 0 关闭 1 高效 2 舒适 3 液态Q弹
  bool glass = false;
  bool decor = true;
  final ValueNotifier<int> avatarRev = ValueNotifier<int>(0);
  final Set<String> unlocked = <String>{};
  bool tampered = false;
  bool festOn = true;
  String festPreview = '';
  String prankOff = '';
  final List<String> avatars = <String>[];
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
  bool _observing = false;
  bool _pending = false;

  List<Preset> get presets =>
      unlocked.contains('divine') ? <Preset>[...kPresets, kDivine] : kPresets;

  Preset get preset {
    if (presetId == 'divine' && unlocked.contains('divine')) return kDivine;
    for (final p in kPresets) {
      if (p.id == presetId) return p;
    }
    return kPresets[1];
  }

  bool get divine => presetId == 'divine' && unlocked.contains('divine');

  bool get hasDivine => unlocked.contains('divine');
  bool get isDark =>
      divine || themeMode == 2 || (themeMode == 0 && sysB == Brightness.dark);

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
  Color get bgTop => ov('bgTop', festBg(true) ?? (isDark ? preset.bgD[0] : preset.bgL[0]));
  Color get bgBottom =>
      ov('bgBottom', festBg(false) ?? (isDark ? preset.bgD[1] : preset.bgL[1]));

  double get cardR => const [26.0, 6.0, 14.0, 12.0][uiStyle];
  double get btnR => const [30.0, 6.0, 12.0, 12.0][uiStyle];
  Color? festBg(bool top) {
    if (divine) return null;
    final f = activeFestival();
    if (f == null) return null;
    final c = top ? f.top : f.bottom;
    return isDark ? Color.lerp(c, Colors.black, 0.6) : c;
  }

  Future<void> load() async {
    _sp = await SharedPreferences.getInstance();
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    final s = _sp!.getString('app_v1');
    if (s != null) {
      try {
        _read(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {}
    }
    launches++;
    _write();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) flush();
  }

  void _read(Map<String, dynamic> j) {
    presetId = (j['preset'] ?? presetId) as String;
    themeMode = _i(j['mode'], themeMode, 2);
    uiStyle = _i(j['style'], uiStyle, 3);
    toggleShape = _i(j['shape'], toggleShape, 1);
    lang = _i(j['lang'], lang, 3);
    fxMode = _i(j['fx'], fxMode, 2);
    animLevel = _i(j['anim'], animLevel, 3);
    glass = j['glass'] == true;
    decor = j['decor'] != false;
    festOn = j['fest'] != false;
    prankOff = (j['prankOff'] ?? '') as String;
    final av = j['avatars'];
    if (av is List) {
      avatars.clear();
      for (final e in av) {
        if (e is String) avatars.add(e);
      }
    }
    unlocked.clear();
    final u = j['unlocked'];
    if (u is List) {
      for (final e in u) {
        unlocked.add(e.toString());
      }
    }
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
    final w = _i(j['wins'], 0, 99999999);
    final l = _i(j['losses'], 0, 99999999);
    final la = _i(j['launches'], 0, 99999999);
    final sg = j['ssig'];
    if (sg is String && sg != signText('$w|$l|$la')) {
      tampered = true;
      wins = 0;
      losses = 0;
      launches = 0;
    } else {
      wins = w;
      losses = l;
      launches = la;
    }
  }

  Map<String, dynamic> _json() => {
        'preset': presetId,
        'mode': themeMode,
        'style': uiStyle,
        'shape': toggleShape,
        'lang': lang,
        'fx': fxMode,
        'anim': animLevel,
        'glass': glass,
        'decor': decor,
        'unlocked': unlocked.toList(),
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
        'ssig': signText('$wins|$losses|$launches'),
      };

  void _write() {
    _sp?.setString('app_v1', jsonEncode(_json()));
  }

  void _later() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), _write);
  }

  /// 立刻写入（切后台、记录战绩时用）
  void flush() {
    _timer?.cancel();
    _write();
  }

  /// 修改后通知界面刷新并保存（同一帧内多次修改只刷新一次）
  void change(VoidCallback f) {
    f();
    if (!_pending) {
      _pending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pending = false;
        notifyListeners();
      });
      WidgetsBinding.instance.scheduleFrame();
    }
    _later();
  }

  /// 只保存，不刷新（用于输入框）
  void quiet(VoidCallback f) {
    f();
    _later();
  }

  /// 只刷新头像，不重建整个界面
  void touchAvatar(VoidCallback f) {
    f();
    avatarRev.value++;
    _later();
  }

  /// 联机对战结束后记录胜负（只能由程序调用）
  void recordResult(bool win) {
    if (win) {
      wins++;
    } else {
      losses++;
    }
    flush();
  }

  String exportText() {
    final m = _json();
    m.remove('avatar');
    m.remove('layers');
    final body = base64Encode(utf8.encode(jsonEncode(m)));
    return 'XQ1:$body.${signText(body)}';
  }

  /// 成功返回 null；'sig' 校验失败；'bad' 格式不对
  String? importText(String raw) {
    final t = raw.trim();
    if (!t.startsWith('XQ1:')) return 'bad';
    final rest = t.substring(4);
    final dot = rest.lastIndexOf('.');
    if (dot <= 0) return 'bad';
    final body = rest.substring(0, dot);
    if (signText(body) != rest.substring(dot + 1)) return 'sig';
    try {
      final m = jsonDecode(utf8.decode(base64Decode(body))) as Map<String, dynamic>;
      final keepAvatar = avatar;
      _read(m);
      avatar = keepAvatar;
      tampered = false;
      avatarRev.value++;
      notifyListeners();
      flush();
      return null;
    } catch (_) {
      return 'bad';
    }
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
