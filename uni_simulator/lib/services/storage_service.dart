import 'package:hive_flutter/hive_flutter.dart';

import '../models/game_state.dart';

/// 游戏状态存储（Hive KV）。大文本（叙事）落在 SQLite。
class GameStorageService {
  static const String boxName = 'game';
  static const String _stateKey = 'current_state';

  Box get _box => Hive.box(boxName);

  static Future<void> init() async {
    await Hive.openBox(boxName);
  }

  GameState? load() {
    final raw = _box.get(_stateKey);
    if (raw is Map) {
      try {
        return GameState.fromJson(Map<String, dynamic>.from(raw));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> save(GameState state) async {
    await _box.put(_stateKey, state.toJson());
  }

  bool get hasSave => _box.containsKey(_stateKey);

  Future<void> clear() async {
    await _box.delete(_stateKey);
  }
}