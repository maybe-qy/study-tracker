import 'package:hive_flutter/hive_flutter.dart';

import '../models/llm_settings.dart';

/// 设置存储（Hive KV）。API Key 由用户在设置页填写。
class SettingsService {
  static const String boxName = 'settings';
  static const String _llmKey = 'llm';

  Box get _box => Hive.box(boxName);

  static Future<void> init() async {
    await Hive.openBox(boxName);
  }

  LlmSettings loadLlm() {
    final raw = _box.get(_llmKey);
    if (raw is Map) {
      return LlmSettings.fromJson(Map<String, dynamic>.from(raw));
    }
    return LlmSettings();
  }

  Future<void> saveLlm(LlmSettings settings) async {
    await _box.put(_llmKey, settings.toJson());
  }
}