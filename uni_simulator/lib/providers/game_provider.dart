import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/character_profile.dart';
import '../models/game_state.dart';
import '../models/monthly_plan.dart';
import '../models/monthly_state.dart';
import '../models/random_event.dart';
import '../models/llm_settings.dart';
import '../services/archive_service.dart';
import '../services/event_service.dart';
import '../services/llm_service.dart';
import '../services/narrative_service.dart';
import '../services/prompt_builder.dart';
import 'service_providers.dart';

const Object _unset = Object();

/// 游戏界面状态。包含可空 game、忙碌标记与提示信息。
class GameUiState {
  final GameState? game;
  final bool busy;
  final String? status;
  final String? error;
  final String? recalibrationPrompt;

  const GameUiState({
    this.game,
    this.busy = false,
    this.status,
    this.error,
    this.recalibrationPrompt,
  });

  GameUiState copyWith({
    GameState? game,
    bool? busy,
    Object? status = _unset,
    Object? error = _unset,
    Object? recalibrationPrompt = _unset,
  }) =>
      GameUiState(
        game: game ?? this.game,
        busy: busy ?? this.busy,
        status: identical(status, _unset) ? this.status : status as String?,
        error: identical(error, _unset) ? this.error : error as String?,
        recalibrationPrompt: identical(recalibrationPrompt, _unset)
            ? this.recalibrationPrompt
            : recalibrationPrompt as String?,
      );
}

final gameProvider =
    NotifierProvider<GameNotifier, GameUiState>(GameNotifier.new);

class GameNotifier extends Notifier<GameUiState> {
  @override
  GameUiState build() {
    final saved = ref.read(gameStorageProvider).load();
    return GameUiState(game: saved);
  }

  LlmSettings get _llm => ref.read(llmSettingsProvider);
  NarrativeService get _narrative => ref.read(narrativeServiceProvider);
  ArchiveService get _archive => ref.read(archiveServiceProvider);

  void _set(GameUiState next) => state = next;

  Future<void> _persist() async {
    final game = state.game;
    if (game != null) {
      await ref.read(gameStorageProvider).save(game);
    }
  }

  // ---------------------------------------------------------------- 开新局

  /// 建立新档案并生成首月计划草案。
  Future<void> newGame(CharacterProfile profile) async {
    final year = profile.enrollmentDate.year;
    final month = profile.enrollmentDate.month;
    final engine = EventEngine();

    final game = GameState(
      profile: profile,
      year: year,
      month: month,
      currentState: MonthlyState(
        year: year,
        month: month,
        age: profile.ageAt(year, month),
        location: profile.university,
        identity: profile.careerStatus,
        savings: 0,
        relationship: '单身',
        health: '良好',
        skills: profile.strengths.take(3).toList(),
        visionScore: 3,
        visionNote: '尚未开始验证',
      ),
      started: true,
    );
    game.pendingEvent =
        engine.maybeGenerate(PromptBuilder.phaseOf(profile, year, month));
    game.monthsSinceLastEvent = engine.monthsSinceLast;

    _set(GameUiState(game: game));
    await _persist();
    await refreshInitialPlan();
  }

  /// 重新生成首月计划草案。
  Future<void> refreshInitialPlan() async {
    final game = state.game;
    if (game == null) return;
    _set(state.copyWith(
        busy: true, status: '正在生成计划草案…', error: null));
    try {
      final plan = await _narrative.generateInitialPlan(
        settings: _llm,
        state: game,
      );
      game.pendingPlan = plan;
      _set(state.copyWith(game: game, busy: false, status: null));
      await _persist();
    } catch (e) {
      _set(state.copyWith(
          busy: false, status: null, error: _errorText(e)));
    }
  }

  // ---------------------------------------------------------------- 计划

  void updatePlan(MonthlyPlan plan) {
    final game = state.game;
    if (game == null) return;
    game.pendingPlan = plan;
    _set(state.copyWith(game: game));
  }

  // ---------------------------------------------------------------- 确认并推演

  Future<void> confirmPlan(MonthlyPlan plan) async {
    final game = state.game;
    if (game == null || state.busy) return;
    game.pendingPlan = plan;

    _set(state.copyWith(
      busy: true,
      status: '正在推演本月…（长文生成通常需要 30–120 秒）',
      error: null,
    ));

    try {
      final archives = await _archive.all();
      final recent = archives.length > 3
          ? archives.sublist(archives.length - 3)
          : archives;

      final output = await _narrative.generateMonth(
        settings: _llm,
        state: game,
        plan: plan,
        recentArchives: recent,
        event: (game.pendingEvent?.triggered ?? false) ? game.pendingEvent : null,
        userChoice: game.lastChoiceText.isEmpty ? null : game.lastChoiceText,
      );

      // 内部自检：结果仅写入调试日志，不进入用户界面。
      final check = ref
          .read(selfCheckServiceProvider)
          .validate(game, recentArchives: recent, nextPlan: output.nextPlan);
      if (!check.passed) {
        debugPrint('[SelfCheck] ${check.issues.join('；')}');
      }
      if (check.missingDimensions.isNotEmpty) {
        debugPrint('[SelfCheck] 偏科维度：${check.missingDimensions.join('、')}');
      }

      final line = NarrativeParser.buildArchiveLine(
        comment: output.archiveLine.isNotEmpty
            ? output.archiveLine
            : output.snapshot.archiveLine,
        snapshot: output.snapshot,
        narrative: output.narrative,
        rawOutput: output.rawText,
        lastEventMonth: (game.pendingEvent?.triggered ?? false)
            ? 'Y${output.snapshot.year}M${output.snapshot.month}'
            : '',
      );
      await _archive.insert(line);
      ref.invalidate(archivesProvider);

      game.currentState = output.snapshot;
      game.lastOutput = output;
      game.pendingChoices = output.choices;
      game.nextPlanDraft = output.nextPlan;
      game.choicesResolved = false;
      game.recentVisionScores.add(output.snapshot.visionScore);
      if (game.recentVisionScores.length > 12) {
        game.recentVisionScores.removeAt(0);
      }

      String? prompt = state.recalibrationPrompt;
      if (ref
          .read(visionRecalibrationServiceProvider)
          .shouldRecalibrate(game.recentVisionScores)) {
        prompt = ref
            .read(visionRecalibrationServiceProvider)
            .generateDialogue(game.profile);
      }

      _set(state.copyWith(
        game: game,
        busy: false,
        status: null,
        recalibrationPrompt: prompt,
      ));
      await _persist();
    } catch (e) {
      _set(state.copyWith(busy: false, status: null, error: _errorText(e)));
    }
  }

  // ---------------------------------------------------------------- 选择并进入下一月

  Future<void> choose(Choice choice) async {
    final game = state.game;
    if (game == null) return;

    game.lastChoiceText =
        '${choice.label}. ${choice.description}${choice.dimension.isEmpty ? '' : '〔${choice.dimension}〕'}';
    game.choicesResolved = true;

    var year = game.year;
    var month = game.month + 1;
    if (month > 12) {
      month = 1;
      year++;
    }
    game.year = year;
    game.month = month;

    // 进入新月份：清空上月的推演产出，避免重启后旧正文挂在新月份下。
    // 上月正文已存入 SQLite，可在「存档」中回看。
    game.lastOutput = null;
    game.pendingChoices = <Choice>[];

    final prev = game.currentState;
    game.currentState = MonthlyState(
      year: year,
      month: month,
      age: game.profile.ageAt(year, month),
      location: prev.location,
      identity: prev.identity,
      savings: prev.savings,
      relationship: prev.relationship,
      health: prev.health,
      skills: List<String>.from(prev.skills),
      visionScore: prev.visionScore,
      visionNote: prev.visionNote,
      risks: List<String>.from(prev.risks),
    );

    final engine = EventEngine()..restore(game.monthsSinceLastEvent);
    game.pendingEvent =
        engine.maybeGenerate(PromptBuilder.phaseOf(game.profile, year, month));
    game.monthsSinceLastEvent = engine.monthsSinceLast;

    if ((game.nextPlanDraft?.items.isNotEmpty ?? false)) {
      game.pendingPlan = game.nextPlanDraft!;
    }

    _set(state.copyWith(game: game, error: null));
    await _persist();
  }

  // ---------------------------------------------------------------- 命令

  /// /restart 重新开始
  Future<void> restart() async {
    await ref.read(gameStorageProvider).clear();
    await _archive.deleteAll();
    _set(const GameUiState());
  }

  /// /pause 暂停推演
  Future<void> togglePause() async {
    final game = state.game;
    if (game == null) return;
    game.paused = !game.paused;
    _set(state.copyWith(game: game));
    await _persist();
  }

  /// /jump [年月] 跳到指定月份重新推演（截断其后存档）
  Future<void> jumpTo(int year, int month) async {
    final game = state.game;
    if (game == null) return;
    await _archive.deleteFrom(year, month);
    game.year = year;
    game.month = month;
    game.currentState = MonthlyState(
      year: year,
      month: month,
      age: game.profile.ageAt(year, month),
      location: game.currentState.location,
      identity: game.currentState.identity,
      savings: game.currentState.savings,
      relationship: game.currentState.relationship,
      health: game.currentState.health,
      skills: List<String>.from(game.currentState.skills),
      visionScore: game.currentState.visionScore,
      risks: List<String>.from(game.currentState.risks),
    );
    game.lastOutput = null;
    game.pendingChoices = <Choice>[];
    game.nextPlanDraft = null;
    game.lastChoiceText = '';
    game.choicesResolved = false;
    _set(state.copyWith(game: game, error: null));
    await _persist();
    await refreshInitialPlan();
  }

  /// /edit 修改人物字段
  Future<void> updateProfile(CharacterProfile profile) async {
    final game = state.game;
    if (game == null) return;
    game.profile = profile;
    _set(state.copyWith(game: game));
    await _persist();
  }

  // ---------------------------------------------------------------- 愿景重校准

  Future<void> applyRecalibration(String newVision, String note) async {
    final game = state.game;
    if (game == null) return;
    game.profile.longTermVision = newVision.trim();
    // 说明（note）是引擎内部解释，不追加到画像字段，避免污染 strengths。
    // 重校准后重置近期分数，避免立即再次触发。
    game.recentVisionScores = <int>[];
    _set(state.copyWith(game: game, recalibrationPrompt: null));
    await _persist();
  }

  void dismissRecalibration() {
    _set(state.copyWith(recalibrationPrompt: null));
  }

  void clearError() {
    if (state.error != null) _set(state.copyWith(error: null));
  }

  // ---------------------------------------------------------------- 导出

  Future<String> exportMarkdown() => _archive.exportMarkdown();

  String _errorText(Object e) {
    if (e is LlmException) return e.message;
    return e.toString();
  }
}