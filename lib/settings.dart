import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'festival.dart';
import 'items.dart';

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

double _d(dynamic v, double def) => (v is num && v.isFinite) ? v.toDouble() : def;
int _i(dynamic v, int def, int hi) {
  final x = v is num ? v.toInt() : def;
  return x < 0 ? 0 : (x > hi ? hi : x);
}

String _s(dynamic v, String def) => v is String ? v : def;
bool _b(dynamic v, bool def) => v is bool ? v : def;
int _tsOf(Map<String, dynamic> m) => m['ts'] is num ? (m['ts'] as num).toInt() : 0;

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
        'scale': _d(scale, 1),
        'dx': _d(dx, 0),
        'dy': _d(dy, 0),
        'rot': _d(rot, 0),
        'sx': _d(skewX, 0),
        'sy': _d(skewY, 0),
        'op': _d(opacity, 1),
        'blur': _d(blur, 0),
      };

  static ImgLayer fromJson(Map<String, dynamic> j) => ImgLayer(
        path: j['path'] is String ? j['path'] as String : null,
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
  bool festOn = true;
  String festPreview = '';
  String prankOff = '';
  bool dev = false;
  bool tampered = false;
  String storageStatus = '读取中…';
  final ValueNotifier<int> avatarRev = ValueNotifier<int>(0);
  final Set<String> unlocked = <String>{};
  final Set<String> owned = <String>{};
  final List<String> eqBadges = <String>[];
  String? eqCorner;
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
  Timer? _timer;
  bool _observing = false;
  bool _pending = false;
  bool _loaded = false;
  final List<String> _dirs = <String>[];
  DateTime? _pausedAt;
  DateTime? _extAt;

  static const List<String> _stateNames = [
    'state_v3.json',
    'state_v3.bak',
    'state_v3.prev',
    'state_v2.json',
  ];

  List<Preset> get presets =>
      unlocked.contains('divine') ? <Preset>[...kPresets, kDivine] : kPresets;

  Preset get preset {
    if (presetId == 'divine' && unlocked.contains('divine')) return kDivine;
    for (final p in kPresets) {
      if (p.id == presetId) return p;
    }
    return kPresets[1];
  }

  bool get hasDivine => unlocked.contains('divine');
  bool get divine => presetId == 'divine' && hasDivine;
  bool owns(String id) => owned.contains(id);

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

  // ───────────── 存取（纯文件，不依赖任何插件）─────────────

  Future<void> load() async {
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    try {
      final d = await getApplicationDocumentsDirectory().timeout(const Duration(seconds: 3));
      _dirs.add(d.path);
    } catch (_) {}
    try {
      final d = await getApplicationSupportDirectory().timeout(const Duration(seconds: 3));
      if (!_dirs.contains(d.path)) _dirs.add(d.path);
    } catch (_) {}

    Map<String, dynamic>? best;
    var bestSrc = '';
    var found = 0;
    for (final dir in _dirs) {
      for (final n in _stateNames) {
        try {
          final f = File('$dir/$n');
          if (!f.existsSync()) continue;
          final x = jsonDecode(f.readAsStringSync());
          if (x is! Map) continue;
          final m = Map<String, dynamic>.from(x);
          found++;
          if (best == null || _tsOf(m) > _tsOf(best)) {
            best = m;
            bestSrc = n;
          }
        } catch (_) {}
      }
    }

    if (best != null) {
      try {
        _read(best);
        dev = best['dev'] == true;
        storageStatus = '已读取（$bestSrc，共 $found 份）';
      } catch (e) {
        storageStatus = '读取出错：$e';
      }
      for (final dir in _dirs) {
        try {
          final f = File('$dir/state_v3.json');
          if (f.existsSync()) f.copySync('$dir/state_v3.prev');
        } catch (_) {}
      }
    } else {
      storageStatus = _dirs.isEmpty ? '无法访问存储目录' : '没有找到旧数据（首次运行，或数据已被清除）';
    }
    if (dev) grantAll();
    _loaded = true;
    launches++;
    _write();
    notifyListeners();
  }

  void beginExternal() {
    _extAt = DateTime.now();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final p = _pausedAt;
      _pausedAt = null;
      final e = _extAt;
      if (e != null) {
        _extAt = null;
        if (DateTime.now().difference(e).inMinutes < 10) return;
      }
      if (_loaded && p != null && DateTime.now().difference(p).inSeconds >= 10) {
        launches++;
        flush();
        notifyListeners();
      }
    } else {
      _pausedAt ??= DateTime.now();
      flush();
    }
  }

  void _read(Map<String, dynamic> j) {
    presetId = _s(j['preset'], presetId);
    themeMode = _i(j['mode'], themeMode, 2);
    uiStyle = _i(j['style'], uiStyle, 3);
    toggleShape = _i(j['shape'], toggleShape, 1);
    lang = _i(j['lang'], lang, 3);
    fxMode = _i(j['fx'], fxMode, 2);
    animLevel = _i(j['anim'], animLevel, 3);
    glass = _b(j['glass'], false);
    decor = _b(j['decor'], true);
    festOn = _b(j['fest'], true);
    prankOff = _s(j['prankOff'], '');
    unlocked.clear();
    final u = j['unlocked'];
    if (u is List) unlocked.addAll(u.whereType<String>());
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
    name = _s(j['name'], name);
    uid = _s(j['uid'], uid);
    bio = _s(j['bio'], bio);
    birthday = _s(j['birthday'], birthday);
    avatar = j['avatar'] is String ? j['avatar'] as String : null;
    borderColor = j['border'] is num ? (j['border'] as num).toInt() : borderColor;
    avatars.clear();
    final av = j['avatars'];
    if (av is List) avatars.addAll(av.whereType<String>());

    final ow = j['owned'];
    if (ow is List) {
      owned
        ..clear()
        ..addAll(ow.whereType<String>());
      eqBadges.clear();
      final eb = j['eqb'];
      if (eb is List) eqBadges.addAll(eb.whereType<String>());
      eqCorner = j['eqc'] is String ? j['eqc'] as String : null;
    } else if (unlocked.contains('divine')) {
      owned
        ..clear()
        ..addAll(const ['badge_divine', 'corner_star', 'avatar_star']);
      eqBadges
        ..clear()
        ..add('badge_divine');
      eqCorner = 'corner_star';
    }
    _cleanItems();

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

  void _cleanItems() {
    final seen = <String>{};
    eqBadges.removeWhere((e) => !owned.contains(e) || !seen.add(e));
    if (eqCorner != null && !owned.contains(eqCorner)) eqCorner = null;
  }

  Map<String, dynamic> _json() => {
        'ts': DateTime.now().millisecondsSinceEpoch,
        'preset': presetId,
        'mode': themeMode,
        'style': uiStyle,
        'shape': toggleShape,
        'lang': lang,
        'fx': fxMode,
        'anim': animLevel,
        'glass': glass,
        'decor': decor,
        'fest': festOn,
        'prankOff': prankOff,
        'dev': dev,
        'unlocked': unlocked.toList(),
        'owned': owned.toList(),
        'eqb': eqBadges,
        'eqc': eqCorner,
        'custom': custom,
        'layers': {for (final e in layers.entries) e.key: e.value.toJson()},
        'name': name,
        'uid': uid,
        'bio': bio,
        'birthday': birthday,
        'avatar': avatar,
        'avatars': avatars,
        'border': borderColor,
        'wins': wins,
        'losses': losses,
        'launches': launches,
        'ssig': signText('$wins|$losses|$launches'),
      };

  /// 同步写入：写完才返回；先写临时文件再改名，避免写一半被杀掉
  void _write() {
    if (!_loaded) return;
    String s;
    try {
      s = jsonEncode(_json());
    } catch (e) {
      storageStatus = '保存失败（编码）：$e';
      return;
    }
    for (final dir in _dirs) {
      try {
        final tmp = File('$dir/state_v3.tmp');
        tmp.writeAsStringSync(s, flush: true);
        tmp.renameSync('$dir/state_v3.json');
        File('$dir/state_v3.bak').writeAsStringSync(s, flush: true);
      } catch (e) {
        storageStatus = '保存失败：$e';
      }
    }
  }

  void _later() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 200), _write);
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

  // ───────────── 道具 / 装扮 ─────────────

  void grantAll() {
    for (final it in kItems) {
      owned.add(it.id);
    }
    unlocked.add('divine');
  }

  void unlockDivine() {
    change(() {
      unlocked.add('divine');
      for (final id in const ['badge_divine', 'corner_star', 'avatar_star']) {
        owned.add(id);
      }
      if (!eqBadges.contains('badge_divine')) eqBadges.add('badge_divine');
      eqCorner ??= 'corner_star';
    });
    avatarRev.value++;
    flush();
  }

  void toggleBadge(String id) {
    touchAvatar(() {
      if (eqBadges.contains(id)) {
        eqBadges.remove(id);
      } else if (owned.contains(id)) {
        eqBadges.add(id);
      }
    });
  }

  void setCorner(String id) {
    touchAvatar(() {
      if (eqCorner == id) {
        eqCorner = null;
      } else if (owned.contains(id)) {
        eqCorner = id;
      }
    });
  }

  void enterDev() {
    final first = !owned.contains('badge_ts');
    change(() {
      dev = true;
      grantAll();
      if (first) {
        for (final id in const ['badge_ts', 'badge_dev', 'badge_admin']) {
          if (!eqBadges.contains(id)) eqBadges.add(id);
        }
        eqCorner = 'corner_ts';
      }
    });
    avatarRev.value++;
    flush();
  }

  void exitDev() {
    change(() {
      dev = false;
      festPreview = '';
    });
    flush();
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

  // ───────────── 备份 ─────────────

  Map<String, dynamic> exportMap() {
    final m = jsonDecode(jsonEncode(_json())) as Map<String, dynamic>;
    m.remove('dev');
    m.remove('ts');
    return m;
  }

  void importMap(Map<String, dynamic> m) {
    final keepDev = dev;
    _read(m);
    dev = keepDev;
    tampered = false;
    if (dev) grantAll();
    avatarRev.value++;
    notifyListeners();
    flush();
  }
}

final AppSettings app = AppSettings();

Future<String?> pickImage() async {
  try {
    app.beginExternal();
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final dot = x.path.lastIndexOf('.');
    final ext = (dot > 0 && x.path.length - dot <= 5) ? x.path.substring(dot) : '.jpg';
    final f = await File(x.path)
        .copy('${dir.path}/img_${DateTime.now().millisecondsSinceEpoch}$ext');
    // 删掉选图时系统留在缓存里的副本，避免占用翻倍
    if (x.path.contains('/cache/')) {
      try {
        await File(x.path).delete();
      } catch (_) {}
    }
    return f.path;
  } catch (_) {
    return null;
  }
}
