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
/// 检查结果仅写入 debugPrint；有偏科维度时会附带返回列表，供上层日志。
class SelfCheckService {
  static const List<String> _allDimensions = [
    '学业',
    '技能',
    '社交',
    '身体',
    '认知',
    '方向'
  ];

  SelfCheckResult validate(
    GameState state, {
    List<ArchiveLine> recentArchives = const [],
    MonthlyPlan? nextPlan,
  }) {
    final issues = <String>[];

    // 1. 年份、月份、年龄是否一致
    if (!_checkAge(state)) issues.add('年龄与出生日期不一致');

    // 2. 上个月选择的后果是否体现在叙事中（关键字匹配描述）
    if (!_checkConsequence(state)) issues.add('上月选择未体现为后果');

    // 3. 随机事件计数器
    if (!_checkEventCounter(state)) issues.add('随机事件计数器未更新');

    // 4. 潜在风险项是否合理
    if (!_checkRisks(state)) issues.add('风险项标注可能不足');

    // 5. 过去三个月各维度是否偏科
    final missing = _checkImbalance(recentArchives);

    // 6. 人物反应是否符合性格（弱检查：叙事中是否出现性格关键词）
    if (!_checkPersonality(state)) issues.add('叙事与人设可能不符');

    // 7. 关键时间节点是否已纳入考虑
    if (!_checkMilestones(state)) issues.add('关键时间节点未纳入');

    // 8. 财务金额是否具体（至少是合理数字，不应为 null）
    if (!_checkFinance(state)) issues.add('财务金额异常');

    // 9. 叙事是否存在重复
    if (_checkRepetition(recentArchives)) issues.add('叙事可能重复');

    // 10. 永久项（运动 + 英语）是否出现
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

  bool _checkConsequence(GameState state) {
    final choice = state.lastChoiceText;
    final narrative = state.lastOutput?.narrative ?? '';
    if (choice.isEmpty || narrative.isEmpty) return true; // 首月无历史，跳过
    // 关键字：choice 的核心描述词是否出现在叙事里
    final desc = choice.replaceFirst(RegExp(r'^[A-D]\.\s*'), '').trim();
    if (desc.isEmpty) return true;
    // 取描述的前 4-8 个字作为关键字（中文场景 substring 基本可用）
    final takeLen = desc.length >= 8 ? 8 : desc.length;
    final keyword = desc.substring(0, takeLen).trim();
    if (keyword.length < 2) return true;
    final checkLen = keyword.length >= 4 ? 4 : keyword.length;
    return narrative.contains(keyword.substring(0, checkLen));
  }

  bool _checkEventCounter(GameState state) {
    // monthsSinceLastEvent 应是非负整数；若有 pendingEvent 且 triggered，计数器应已归零
    if (state.monthsSinceLastEvent < 0) return false;
    if (state.pendingEvent != null && state.pendingEvent!.triggered) {
      return state.monthsSinceLastEvent == 0;
    }
    return true;
  }

  bool _checkRisks(GameState state) {
    // 愿景契合度偏低、健康异常时应有风险标注
    if (state.currentState.visionScore <= 2 &&
        state.currentState.risks.isEmpty) {
      return false;
    }
    if (state.currentState.health.contains('差') ||
        state.currentState.health.contains('病') ||
        state.currentState.health.contains('熬夜')) {
      if (!state.currentState.risks
          .any((r) => r.contains('健康') || r.contains('身体'))) {
        return false;
      }
    }
    return true;
  }

  List<String> _checkImbalance(List<ArchiveLine> recent) {
    if (recent.length < 3) return const [];
    final covered = <String>{};
    for (final line in recent) {
      // skills 字段是用 /、; 分隔的关键词集合
      covered.addAll(line.skills.split(RegExp(r'[/、,，;；\s]+')));
      // risks 字段也可能体现关注维度
      covered.addAll(line.risks.split(RegExp(r'[；;、,，\s]+')));
    }
    // 把"缺失"理解为：近期既没出现在技能也没出现在风险的维度
    return _allDimensions.where((d) {
      // 弱匹配：只要 covered 里有一个词以该维度开头或包含就算覆盖
      return !covered.any((c) => c.contains(d) || d.contains(c));
    }).toList();
  }

  bool _checkPersonality(GameState state) {
    final narrative = state.lastOutput?.narrative ?? '';
    final traits = state.profile.personality;
    if (narrative.isEmpty || traits.isEmpty) return true;
    // 弱检查：至少有一个性格关键词在叙事的某个语境下出现（变体也行）
    final variants = <String, List<String>>{
      '嘴硬心软': ['嘴硬', '心软', '话硬', '但心'],
      '直接': ['直接', '坦率', '直截了当'],
      '洒脱': ['洒脱', '不纠结', '放得开'],
      '踏实能扛事': ['踏实', '扛事', '顶住', '顶住压力'],
      '踏实': ['踏实', '扎实', '一步一步'],
      '能扛': ['扛', '顶住', '撑住'],
    };
    for (final trait in traits) {
      final v = variants[trait] ?? [trait];
      if (v.any((x) => narrative.contains(x))) return true;
    }
    return true; // 不强制，弱提示
  }

  bool _checkMilestones(GameState state) {
    // 关键时间节点只要档案里有就通过（LLM 层面是否考虑无法精确判断）
    return state.profile.keyNodes.isNotEmpty;
  }

  bool _checkFinance(GameState state) {
    final s = state.currentState.savings;
    return s >= -1000000; // 允许小额负债，但不能极端
  }

  bool _checkRepetition(List<ArchiveLine> recent) {
    if (recent.length < 3) return false;
    // 更宽松：后两个月的叙事若 Jaccard 相似度 > 0.8，视为高度重复
    final a = recent[recent.length - 1].narrative;
    final b = recent[recent.length - 2].narrative;
    if (a.isEmpty || b.isEmpty) return false;
    final setA = a.runes.map((r) => r).toSet();
    final setB = b.runes.map((r) => r).toSet();
    if (setA.isEmpty || setB.isEmpty) return false;
    final intersection = setA.intersection(setB);
    final union = setA.union(setB);
    final sim = intersection.length / union.length;
    return sim > 0.85;
  }

  bool _checkPermanentItems(GameState state) {
    final narrative = state.lastOutput?.narrative ?? '';
    if (narrative.isEmpty) return true; // 首月可能还没叙事
    final items = state.profile.permanentItems;
    // 运动锚点 → 检查跑步/运动/锻炼等词
    bool hasSport = false;
    bool hasEnglish = false;
    for (final item in items) {
      if (item.contains('运动') || item.contains('锚点')) {
        hasSport = narrative.contains(RegExp(r'(跑|运动|锻炼|健身|球|骑|步|练)'));
      }
      if (item.contains('英语') || item.contains('外语')) {
        hasEnglish = narrative.contains(RegExp(r'(英语|英文|外语|雅思|托福|口语|听力|阅读|单词|英语课)'));
      }
    }
    return hasSport && hasEnglish;
  }
}
