import 'monthly_plan.dart';
import 'monthly_state.dart';
import 'random_event.dart';

/// 一次 LLM 生成的完整产出（对应提示词的统一输出格式）。
class MonthOutput {
  final String narrative; // ## 叙事
  final MonthlyState snapshot; // ## 状态快照
  final String archiveLine; // ARCHIVE 行原文
  final MonthlyPlan nextPlan; // ## 下月计划草案
  final List<Choice> choices; // ## 选择题
  final String rawText; // 原始返回，便于排错与回看

  MonthOutput({
    required this.narrative,
    required this.snapshot,
    required this.archiveLine,
    required this.nextPlan,
    required this.choices,
    this.rawText = '',
  });

  Map<String, dynamic> toJson() => {
        'narrative': narrative,
        'snapshot': snapshot.toJson(),
        'archiveLine': archiveLine,
        'nextPlan': nextPlan.toJson(),
        'choices': choices.map((e) => e.toJson()).toList(),
        'rawText': rawText,
      };

  factory MonthOutput.fromJson(Map<String, dynamic> json) => MonthOutput(
        narrative: json['narrative'] as String? ?? '',
        snapshot: MonthlyState.fromJson(
            Map<String, dynamic>.from(json['snapshot'] as Map? ?? {})),
        archiveLine: json['archiveLine'] as String? ?? '',
        nextPlan: MonthlyPlan.fromJson(
            Map<String, dynamic>.from(json['nextPlan'] as Map? ?? {})),
        choices: (json['choices'] as List<dynamic>? ?? [])
            .map((e) => Choice.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        rawText: json['rawText'] as String? ?? '',
      );

  MonthOutput copyWith({
    String? narrative,
    MonthlyState? snapshot,
    String? archiveLine,
    MonthlyPlan? nextPlan,
    List<Choice>? choices,
    String? rawText,
  }) =>
      MonthOutput(
        narrative: narrative ?? this.narrative,
        snapshot: snapshot ?? this.snapshot,
        archiveLine: archiveLine ?? this.archiveLine,
        nextPlan: nextPlan ?? this.nextPlan,
        choices: choices ?? this.choices,
        rawText: rawText ?? this.rawText,
      );
}