import 'character_profile.dart';
import 'month_output.dart';
import 'monthly_plan.dart';
import 'monthly_state.dart';
import 'random_event.dart';

/// 全局游戏状态（可被 Hive 序列化，narrative 等大文本落在 SQLite）。
class GameState {
  CharacterProfile profile;
  int year;
  int month;
  MonthlyState currentState;
  MonthlyPlan pendingPlan; // 当前待调整/待确认的计划
  MonthlyPlan? nextPlanDraft; // 已生成的「下月计划草案」
  List<Choice> pendingChoices; // 本月选择题
  MonthOutput? lastOutput;
  RandomEvent? pendingEvent; // 本月已判定的随机事件
  int monthsSinceLastEvent; // 内部计数器，不输出到界面
  List<int> recentVisionScores;
  String lastChoiceText; // 上月末用户选择，用于下月叙事的因果承接
  bool choicesResolved; // 本月选择题是否已提交
  bool paused;
  bool started;

  GameState({
    required this.profile,
    required this.year,
    required this.month,
    required this.currentState,
    MonthlyPlan? pendingPlan,
    this.nextPlanDraft,
    List<Choice>? pendingChoices,
    this.lastOutput,
    this.pendingEvent,
    this.monthsSinceLastEvent = 0,
    List<int>? recentVisionScores,
    this.lastChoiceText = '',
    this.choicesResolved = false,
    this.paused = false,
    this.started = false,
  })  : pendingPlan = pendingPlan ?? MonthlyPlan(),
        pendingChoices = pendingChoices ?? <Choice>[],
        recentVisionScores = recentVisionScores ?? <int>[];

  String get yearMonth => 'Y${year}M$month';

  String get displayMonth => '$year年$month月';

  GameState copy() => GameState(
        profile: profile,
        year: year,
        month: month,
        currentState: currentState,
        pendingPlan: pendingPlan,
        nextPlanDraft: nextPlanDraft,
        pendingChoices: pendingChoices,
        lastOutput: lastOutput,
        pendingEvent: pendingEvent,
        monthsSinceLastEvent: monthsSinceLastEvent,
        recentVisionScores: recentVisionScores,
        lastChoiceText: lastChoiceText,
        choicesResolved: choicesResolved,
        paused: paused,
        started: started,
      );

  Map<String, dynamic> toJson() => {
        'profile': profile.toJson(),
        'year': year,
        'month': month,
        'currentState': currentState.toJson(),
        'pendingPlan': pendingPlan.toJson(),
        'nextPlanDraft': nextPlanDraft?.toJson(),
        'pendingChoices': pendingChoices.map((e) => e.toJson()).toList(),
        'pendingEvent': pendingEvent?.toJson(),
        'lastOutput': lastOutput?.toJson(),
        'monthsSinceLastEvent': monthsSinceLastEvent,
        'recentVisionScores': recentVisionScores,
        'lastChoiceText': lastChoiceText,
        'choicesResolved': choicesResolved,
        'paused': paused,
        'started': started,
      };

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
        profile: CharacterProfile.fromJson(
            Map<String, dynamic>.from(json['profile'] as Map)),
        year: (json['year'] as num?)?.toInt() ?? 0,
        month: (json['month'] as num?)?.toInt() ?? 0,
        currentState: MonthlyState.fromJson(
            Map<String, dynamic>.from(json['currentState'] as Map)),
        pendingPlan: MonthlyPlan.fromJson(
            Map<String, dynamic>.from(json['pendingPlan'] as Map? ?? {})),
        nextPlanDraft: json['nextPlanDraft'] == null
            ? null
            : MonthlyPlan.fromJson(
                Map<String, dynamic>.from(json['nextPlanDraft'] as Map)),
        pendingChoices: (json['pendingChoices'] as List<dynamic>? ?? [])
            .map((e) => Choice.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        pendingEvent: json['pendingEvent'] == null
            ? null
            : RandomEvent.fromJson(
                Map<String, dynamic>.from(json['pendingEvent'] as Map)),
        lastOutput: json['lastOutput'] == null
            ? null
            : MonthOutput.fromJson(
                Map<String, dynamic>.from(json['lastOutput'] as Map)),
        monthsSinceLastEvent:
            (json['monthsSinceLastEvent'] as num?)?.toInt() ?? 0,
        recentVisionScores: (json['recentVisionScores'] as List<dynamic>? ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
        lastChoiceText: json['lastChoiceText'] as String? ?? '',
        choicesResolved: json['choicesResolved'] as bool? ?? false,
        paused: json['paused'] as bool? ?? false,
        started: json['started'] as bool? ?? false,
      );
}