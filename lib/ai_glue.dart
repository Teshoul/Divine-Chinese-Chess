import 'dart:isolate';
import 'ai_blind.dart';
import 'ai_engine.dart';
import 'blind.dart';
import 'engine.dart';

/// 一局对 AI 的设置：难度 0~4，以及玩家执哪一方
class AiPlan {
  final int level;
  final Side human;
  const AiPlan(this.level, this.human);
  Side get ai => human.other;
}

int _pid(PType t, Side s) => (t.index + 1) | (s == Side.red ? 0 : 8);

Move _moveOfKey(int key) {
  final from = key ~/ 90;
  final to = key % 90;
  return Move(from ~/ 9, from % 9, to ~/ 9, to % 9);
}

/// 普通对局：在后台线程里算出 AI 的下一步，界面不会卡住
Future<Move?> aiStandardMove(Game g, int level) async {
  final board = List<int>.filled(90, 0);
  for (var r = 0; r < 10; r++) {
    for (var c = 0; c < 9; c++) {
      final p = g.b[r][c];
      if (p != null) board[r * 9 + c] = _pid(p.type, p.side);
    }
  }
  final hist = <int>[];
  for (final h in g.history) {
    if (h.swap) {
      hist.clear();
      break;
    }
    hist.add((h.move.fr * 9 + h.move.fc) * 90 + h.move.tr * 9 + h.move.tc);
  }
  final side = g.turn == Side.red ? 0 : 1;
  final seed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
  final key = await Isolate.run(() => xqAiPick(board, side, level, seed, hist));
  if (key < 0) return null;
  return _moveOfKey(key);
}

/// 盲棋：等级 0~3 看不见暗子；等级 4（地狱）直接读取所有暗子的真实身份
Future<Move?> aiBlindMove(BlindGame g, int level) async {
  final omni = level >= 4;
  final pc = List<int>.filled(90, 0);
  final hid = List<int>.filled(90, 0);
  final home = List<int>.filled(90, 0);
  final counts = List<int>.filled(16, 0);
  final lay = Game().b;
  for (var r = 0; r < 10; r++) {
    for (var c = 0; c < 9; c++) {
      final p = lay[r][c];
      if (p != null) counts[_pid(p.type, p.side)]++;
    }
  }
  for (var r = 0; r < 10; r++) {
    for (var c = 0; c < 9; c++) {
      final bp = g.b[r][c];
      if (bp == null) continue;
      final sq = r * 9 + c;
      if (bp.up) {
        pc[sq] = _pid(bp.type, bp.side);
        home[sq] = pc[sq];
        counts[pc[sq]]--;
      } else {
        hid[sq] = 1;
        home[sq] = _pid(bp.posType, bp.posSide);
        if (omni) pc[sq] = _pid(bp.type, bp.side);
      }
    }
  }
  for (final d in g.deadRed) {
    counts[_pid(d.type, d.side)]--;
  }
  for (final d in g.deadBlack) {
    counts[_pid(d.type, d.side)]--;
  }
  final pool = <int>[];
  for (var id = 1; id < 16; id++) {
    for (var k = 0; k < counts[id]; k++) {
      pool.add(id);
    }
  }
  final side = g.turn == Side.red ? 0 : 1;
  final seed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
  final kp = g.cfg.kingInPalace;
  final ae = g.cfg.advElephantLimit;
  final key = await Isolate.run(
      () => blindAiPick(pc, hid, home, pool, side, level, seed, kp, ae));
  if (key < 0) return null;
  return _moveOfKey(key);
}
