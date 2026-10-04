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