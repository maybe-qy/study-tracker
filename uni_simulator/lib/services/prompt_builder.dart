import '../models/archive_line.dart';
import '../models/character_profile.dart';
import '../models/game_state.dart';
import '../models/monthly_plan.dart';
import '../models/random_event.dart';

/// 构建 LLM 提示词。严格对应提示词模板的输出格式。
class PromptBuilder {
  /// 根据入学时间推断所处阶段。
  static String phaseOf(CharacterProfile profile, int year, int month) {
    final enroll = profile.enrollmentDate;
    final grad = profile.graduationDate;
    final current = DateTime(year, month);
    if (current.isBefore(DateTime(enroll.year, enroll.month))) return '入学前';
    if (!current.isBefore(DateTime(grad.year, grad.month))) return '毕业后';

    final monthsSinceEnroll =
        (year - enroll.year) * 12 + (month - enroll.month);
    if (monthsSinceEnroll < 12) return '大一';
    if (monthsSinceEnroll < 24) return '大二';
    if (monthsSinceEnroll < 36) return '大三';
    return '大四';
  }

  static const String systemPrompt = '''
你是一个大学人生模拟器引擎。你不预言、不评判，只呈现客观叙事和结果。
你只输出结构化文本，不输出任何解释性前言或结语。
所有内部检查与计数逻辑都不出现在输出中。
绝不生成违法、自残、伤害他人等有害行为的具体描述；若选择滑向此类倾向，只呈现客观负面后果，并自然引导向建设性方向。
''';

  /// 生成某个月份的完整推演提示词。
  static String buildMonthPrompt({
    required GameState state,
    required MonthlyPlan plan,
    required List<ArchiveLine> recentArchives,
    RandomEvent? event,
    String? userChoice,
    int targetLength = 1500,
  }) {
    final profile = state.profile;
    final year = state.year;
    final month = state.month;
    final age = profile.ageAt(year, month);
    final phase = phaseOf(profile, year, month);
    final snapshot = state.currentState;

    final buffer = StringBuffer();
    buffer.writeln('基于以下状态，生成一段约 $targetLength 字的叙事（${(targetLength * 0.6).round()}–${(targetLength * 1.2).round()} 字，务必不要超长，超出部分会被截断）。');
    buffer.writeln();
    buffer.writeln('【当前状态】');
    buffer.writeln('- 时间：$year年$month月');
    buffer.writeln('- 年龄：$age岁');
    buffer.writeln('- 阶段：$phase');
    buffer.writeln('- 所在地：${snapshot.location.isEmpty ? profile.university : snapshot.location}');
    buffer.writeln('- 身份：${snapshot.identity.isEmpty ? profile.careerStatus : snapshot.identity}');
    buffer.writeln('- 积蓄：${snapshot.savings}');
    buffer.writeln('- 核心技能：${snapshot.skills.join('、')}');
    buffer.writeln('- 长期愿景：${profile.longTermVision}');
    buffer.writeln('- 核心性格：${profile.personality.join('、')}');
    buffer.writeln('- 优势：${profile.strengths.join('、')}');
    buffer.writeln('- 困境：${profile.weaknesses.join('、')}');
    buffer.writeln('- 底线/禁区：${profile.forbiddenZone}');
    buffer.writeln('- 永久项：${profile.permanentItems.map((e) => '$e（不可省略）').join(' + ')}');
    if (profile.keyNodes.isNotEmpty) {
      buffer.writeln('- 关键时间节点：${profile.keyNodes.map((e) => '${e.label}${e.date != null ? '(${e.date})' : ''}').join('；')}');
    }
    buffer.writeln();
    buffer.writeln('【本月计划】');
    for (final item in plan.items) {
      buffer.writeln('- ${item.label}. ${item.name}（权重 ${item.weight}%）${item.dimension.isNotEmpty ? '〔${item.dimension}〕' : ''}');
    }
    buffer.writeln('（永久项：${profile.permanentItems.join(' + ')}。运动锚点固定占 20%，英语线贯穿全程——这两项是额外的底线要求，不占用上方 4 项的 100% 权重分配；叙事中必须真实出现其执行细节，不可省略）');
    buffer.writeln();
    if (userChoice != null && userChoice.isNotEmpty) {
      buffer.writeln('【上月做出的选择】');
      buffer.writeln(userChoice);
      buffer.writeln('本月叙事必须体现这一选择带来的直接后果。');
      buffer.writeln();
    }
    if (event != null) {
      buffer.writeln('【本月随机事件】');
      buffer.writeln('- 类型：${event.type}');
      buffer.writeln('- ${event.title}：${event.description}');
      buffer.writeln('请把该事件自然引入本月叙事，不要生硬堆砌。');
      buffer.writeln();
    }
    buffer.writeln('【历史 ARCHIVE】');
    if (recentArchives.isEmpty) {
      buffer.writeln('（这是推演的第一个月，暂无历史）');
    } else {
      for (final a in recentArchives) {
        buffer.writeln(a.toCommentLine());
      }
    }
    buffer.writeln();
    buffer.writeln('【要求】');
    buffer.writeln('1. 叙事结构：具体行动（时间/地点/行为）→ 短期结果（新技能/新人际/新困境/新洞见）→ 内心感受。');
    buffer.writeln('2. 不评判选择，细节越具体越好。');
    buffer.writeln('3. 对话要自然，符合人物性格。');
    buffer.writeln('4. 数据要具体（金额、百分比、时间），不写模糊表述；记不清的如实说「记不清了」，不要编造。');
    buffer.writeln('5. 每段经历要有可追溯的结果。');
    buffer.writeln('6. 永久项「运动」与「英语」必须出现，不可省略。');
    buffer.writeln('7. 必须遵循下方的输出格式，四个二级标题缺一不可。');
    buffer.writeln('8. 篇幅要克制：叙事控制在 ${(targetLength * 1.2).round()} 字以内，保证「状态快照 / 下月计划草案 / 选择题」三个部分能完整输出，绝不能因为写太长而被截断。');
    buffer.writeln();
    buffer.write(_outputFormat(year, month, age, profile));
    return buffer.toString();
  }

  static String _outputFormat(
      int year, int month, int age, CharacterProfile profile) {
    return '''
【输出格式】
## 叙事
[叙事内容，具体到时间、地点、金额、对话]

## 状态快照
【$year年$month月·$age岁 状态快照】
[所在地] | [身份] | 积蓄 [具体金额]
[感情状态] | [健康状况] | [核心技能，用/分隔]
长期愿景契合度：[1-5]星（[一句话说明]）
潜在风险：[风险项；无则写「暂无」]

<!-- ARCHIVE: Y${year}M$month | [所在地] | [身份] | [积蓄数字] | [健康] | [技能] | [风险] | [1-5]星 | [上次随机事件月份或「无」] -->

## 下月计划草案
- A. [事项]（建议权重：XX%）——[说明]
- B. [事项]（建议权重：XX%）——[说明]
- C. [事项]（建议权重：XX%）——[说明]
- D. [事项]（建议权重：XX%）——[说明]
总权重：100%

## 选择题
- A. [行动描述] [维度标签]
- B. [行动描述] [维度标签]
- C. [行动描述] [维度标签]
- D. [行动描述] [维度标签]
''';
  }

  /// 首月：只需要一份计划草案。
  static String buildInitialPlanPrompt(GameState state) {
    final profile = state.profile;
    final phase = phaseOf(profile, state.year, state.month);
    return '''
这是大学模拟器推演的第一个月。请基于以下人物档案，给出$phase第一个月的执行计划草案（4 项，权重合计 100%）。

【人物】
- ${profile.name}，${state.year}年${state.month}月入学，阶段：$phase
- 学校/专业：${profile.university} · ${profile.major}
- 长期愿景：${profile.longTermVision}
- 性格：${profile.personality.join('、')}
- 优势：${profile.strengths.join('、')}
- 困境：${profile.weaknesses.join('、')}
- 永久项：${profile.permanentItems.join(' + ')}（运动锚点固定占 20%，不单独列出）

【要求】
结合「永久项 + 阶段关键任务」给出 4 项，覆盖学业/技能/社交/身体等不同维度，权重合理。
只输出下面的格式，不要任何多余文字：

## 下月计划草案
- A. [事项]（建议权重：XX%）——[说明]
- B. [事项]（建议权重：XX%）——[说明]
- C. [事项]（建议权重：XX%）——[说明]
- D. [事项]（建议权重：XX%）——[说明]
总权重：100%
''';
  }

  /// 愿景重校准：让 LLM 基于用户回答重写长期愿景。
  static String buildRecalibrationPrompt(
      CharacterProfile profile, String userAnswer) {
    return '''
人物 ${profile.name} 的长期愿景原为「${profile.longTermVision}」。
在连续数月愿景契合度偏低后，他/她给出了如下回答：

$userAnswer

请据此重写一句新的长期愿景（不超过 30 字，保留「方向感」而非「岗位名」的取舍由你判断），
并附一句 40 字以内的说明，说明它和原愿景的关系。
只输出：
新愿景：...
说明：...
''';
  }
}