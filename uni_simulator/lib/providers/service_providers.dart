import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/archive_line.dart';
import '../models/llm_settings.dart';
import '../services/archive_service.dart';
import '../services/image_service.dart';
import '../services/llm_service.dart';
import '../services/narrative_service.dart';
import '../services/self_check_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../services/vision_recalibration_service.dart';

final settingsServiceProvider =
    Provider<SettingsService>((ref) => SettingsService());

final gameStorageProvider =
    Provider<GameStorageService>((ref) => GameStorageService());

final archiveServiceProvider =
    Provider<ArchiveService>((ref) => ArchiveService());

/// 存档列表（SQLite）。插入新存档后需 invalidate 以刷新时间线。
final archivesProvider = FutureProvider<List<ArchiveLine>>((ref) async {
  return ref.watch(archiveServiceProvider).all();
});

final llmServiceProvider = Provider<LlmService>((ref) => LlmService());

final narrativeServiceProvider = Provider<NarrativeService>(
    (ref) => NarrativeService(ref.watch(llmServiceProvider)));

final selfCheckServiceProvider =
    Provider<SelfCheckService>((ref) => SelfCheckService());

final visionRecalibrationServiceProvider =
    Provider<VisionRecalibrationService>((ref) => VisionRecalibrationService());

final imageServiceProvider = Provider<ImageService>((ref) => ImageService());

/// LLM 设置（含 API Key），由使用者在设置页填写。
final llmSettingsProvider =
    NotifierProvider<LlmSettingsNotifier, LlmSettings>(LlmSettingsNotifier.new);

class LlmSettingsNotifier extends Notifier<LlmSettings> {
  @override
  LlmSettings build() => ref.read(settingsServiceProvider).loadLlm();

  Future<void> update(LlmSettings settings) async {
    state = settings;
    await ref.read(settingsServiceProvider).saveLlm(settings);
  }

  Future<void> applyPreset(String provider) async {
    final preset = LlmSettings.presets[provider];
    if (preset == null) return;
    await update(state.copyWith(
      provider: provider,
      baseUrl: preset['baseUrl'] ?? state.baseUrl,
      model: preset['model'] ?? state.model,
    ));
  }
}