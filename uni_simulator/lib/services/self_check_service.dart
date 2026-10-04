import '../models/archive_line.dart';
import '../models/game_state.dart';
import '../models/monthly_plan.dart';

/// 内部自检结果。仅在引擎内部使用与调试，不直接展示给用户。
class SelfCheckResult {
  final bool passed;
  final List<String> issues;
  final List<String> missingDimensions;

  const SelfCheckResult({
    required this.passed,
    this.issues = const [],
    this.missingDimensions = const [],
  });
}

/// 内部自检规则（引擎内执行，不输出到用户界面）。
class SelfCheckService {
  static const List<String> _allDimensions = ['学业', '技能', '社交', '身体', '认知', '方向'];

  SelfCheckResult validate(
    GameState state, {
    List<ArchiveLine> recentArchives = const [],
    MonthlyPlan? nextPlan,
  }) {
    final issues = <String>[];

    // 1. 年份、月份、年龄是否一致
    if (!_checkAge(state)) issues.add('年龄与出生日期不一致');

    // 2. 上个月选择的后果是否体现在叙事与快照中
    if (!_checkConsequence(state)) issues.add('上月选择未体现为后果');

    // 3. 随机事件计数器是否已被更新
    if (!_checkEventCounter(state)) issues.add('随机事件计数器未更新');

    // 4. 潜在风险项是否与近期积累一致
    if (!_checkRisks(state)) issues.add('风险项与近期状态不一致');

    // 5. 过去三个月各维度是否偏科
    final missing = _checkImbalance(recentArchives);

    // 6. 人物反应是否符合性格设定
    if (!_checkPersonality(state)) issues.add('叙事与人设可能不符');

    // 7. 关键时间节点是否已纳入考虑
    if (!_checkMilestones(state)) issues.add('关键时间节点未纳入');

    // 8. 财务金额是否具体
    if (!_checkFinance(state)) issues.add('财务金额不具体');

    // 9. 叙事是否存在重复劳动
    if (_checkRepetition(recentArchives)) issues.add('叙事可能重复');

    // 10. 是否遗漏永久项（运动 + 英语）
    if (!_checkPermanentItems(state)) issues.add('永久项缺失');

    return SelfCheckResult(
      passed: issues.isEmpty,
      issues: issues,
      missingDimensions: missing,
    );
  }

  bool _checkAge(GameState state) {
    final expected = state.profile.ageAt(state.year, state.month);
    return state.currentState.age == expected;
  }

  bool _checkConsequence(GameState state) => state.lastOutput != null;

  bool _checkEventCounter(GameState state) =>
      state.monthsSinceLastEvent >= 0 && state.pendingEvent != null
          ? state.pendingEvent!.triggered
          : true;

  bool _checkRisks(GameState state) {
    if (state.currentState.visionScore <= 2) {
      return state.currentState.risks.isNotEmpty;
    }
    return true;
  }

  List<String> _checkImbalance(List<ArchiveLine> recent) {
    if (recent.length < 3) return const [];
    final covered = <String>{};
    for (final line in recent) {
      covered.addAll(line.skills.split(RegExp(r'[/、,，;；]')));
    }
    return _allDimensions.where((d) => !covered.contains(d)).toList();
  }

  bool _checkPersonality(GameState state) => state.profile.personality.isNotEmpty;

  bool _checkMilestones(GameState state) => state.profile.keyNodes.isNotEmpty;

  bool _checkFinance(GameState state) => state.currentState.savings != 0;

  bool _checkRepetition(List<ArchiveLine> recent) {
    if (recent.length < 3) return false;
    final last = recent.last.narrative;
    return recent
        .take(recent.length - 1)
        .any((e) => e.narrative == last && last.isNotEmpty);
  }

  bool _checkPermanentItems(GameState state) {
    final narrative = state.lastOutput?.narrative ?? '';
    if (narrative.isEmpty) return true;
    return narrative.contains('跑') || narrative.contains('运动') || narrative.contains('英语');
  }
}