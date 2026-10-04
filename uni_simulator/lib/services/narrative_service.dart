import '../models/archive_line.dart';
import '../models/game_state.dart';
import '../models/llm_settings.dart';
import '../models/month_output.dart';
import '../models/monthly_plan.dart';
import '../models/monthly_state.dart';
import '../models/random_event.dart';
import 'llm_service.dart';
import 'prompt_builder.dart';

/// 叙事生成与结构化解析。
class NarrativeService {
  final LlmService _llm;

  NarrativeService(this._llm);

  /// 生成某个月的完整推演（叙事 + 快照 + ARCHIVE + 下月计划草案 + 选择题）。
  Future<MonthOutput> generateMonth({
    required LlmSettings settings,
    required GameState state,
    required MonthlyPlan plan,
    required List<ArchiveLine> recentArchives,
    RandomEvent? event,
    String? userChoice,
    int targetLength = 1500,
  }) async {
    final prompt = PromptBuilder.buildMonthPrompt(
      state: state,
      plan: plan,
      recentArchives: recentArchives,
      event: event,
      userChoice: userChoice,
      targetLength: targetLength,
    );
    final raw = await _llm.chat(settings, [
      const ChatMessage(role: 'system', content: PromptBuilder.systemPrompt),
      ChatMessage(role: 'user', content: prompt),
    ]);
    return NarrativeParser.parse(
      raw,
      year: state.year,
      month: state.month,
      age: state.profile.ageAt(state.year, state.month),
      previous: state.currentState,
      plan: plan,
    );
  }

  /// 首月计划草案。
  Future<MonthlyPlan> generateInitialPlan({
    required LlmSettings settings,
    required GameState state,
  }) async {
    final raw = await _llm.chat(settings, [
      const ChatMessage(role: 'system', content: PromptBuilder.systemPrompt),
      ChatMessage(
          role: 'user', content: PromptBuilder.buildInitialPlanPrompt(state)),
    ]);
    final plan = NarrativeParser.parsePlan(raw);
    if (plan.items.isEmpty) {
      throw LlmException('未能解析出计划草案，请重试或检查模型输出格式。');
    }
    return plan;
  }

  /// 愿景重校准：返回 (新愿景, 说明)。
  Future<(String, String)> recalibrateVision({
    required LlmSettings settings,
    required GameState state,
    required String userAnswer,
  }) async {
    final raw = await _llm.chat(settings, [
      const ChatMessage(role: 'system', content: PromptBuilder.systemPrompt),
      ChatMessage(
        role: 'user',
        content: PromptBuilder.buildRecalibrationPrompt(
            state.profile, userAnswer),
      ),
    ]);
    final visionMatch =
        RegExp(r'新愿景\s*[:：]\s*(.+)').firstMatch(raw);
    final noteMatch = RegExp(r'说明\s*[:：]\s*(.+)').firstMatch(raw);
    final vision = (visionMatch?.group(1) ?? raw).trim().replaceAll('"', '');
    final note = (noteMatch?.group(1) ?? '').trim();
    return (vision, note);
  }
}

/// 把 LLM 的 Markdown 输出解析为结构化对象，并带有降级兜底。
class NarrativeParser {
  static final RegExp _headingRe = RegExp(r'^#{1,4}\s*(.+?)\s*$', multiLine: true);
  static final RegExp _archiveRe =
      RegExp(r'<!--\s*ARCHIVE\s*:(.*?)-->', dotAll: true);

  static Map<String, String> splitSections(String text) {
    final matches = _headingRe.allMatches(text).toList();
    final map = <String, String>{};
    for (var i = 0; i < matches.length; i++) {
      final title = matches[i].group(1)!.trim();
      final start = matches[i].end;
      final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
      map[title] = text.substring(start, end).trim();
    }
    return map;
  }

  static String _pickSection(Map<String, String> sections, List<String> keys) {
    for (final key in keys) {
      for (final title in sections.keys) {
        if (title.contains(key)) return sections[title]!;
      }
    }
    return '';
  }

  static MonthOutput parse(
    String raw, {
    required int year,
    required int month,
    required int age,
    required MonthlyState previous,
    required MonthlyPlan plan,
  }) {
    final sections = splitSections(raw);
    var narrative = _pickSection(sections, ['叙事', '正文']);
    if (narrative.isEmpty) {
      narrative = raw
          .replaceAll(_archiveRe, '')
          .replaceAll(_headingRe, '')
          .trim();
    }
    final snapshotText = _pickSection(sections, ['状态快照', '快照']);
    final planText = _pickSection(sections, ['下月计划', '计划草案', '计划']);
    final choiceText = _pickSection(sections, ['选择题', '选择']);

    final archiveComment = _archiveRe.firstMatch(raw)?.group(0) ?? '';
    final snapshot = _parseSnapshot(
      snapshotText,
      year: year,
      month: month,
      age: age,
      previous: previous,
      archiveLine: archiveComment,
    );
    var nextPlan = parsePlan(planText);
    if (nextPlan.items.isEmpty) {
      nextPlan = plan; // 兜底：沿用本月计划
    }
    var choices = parseChoices(choiceText);
    if (choices.isEmpty) choices = defaultChoices(nextPlan);

    return MonthOutput(
      narrative: narrative,
      snapshot: snapshot,
      archiveLine: archiveComment,
      nextPlan: nextPlan,
      choices: choices,
      rawText: raw,
    );
  }

  static MonthlyState _parseSnapshot(
    String text, {
    required int year,
    required int month,
    required int age,
    required MonthlyState previous,
    required String archiveLine,
  }) {
    final cleaned = text.replaceAll(_archiveRe, '').trim();
    final lines = cleaned
        .split('\n')
        .map((e) => e.trim().replaceAll(RegExp(r'^\s*[-*]\s*'), ''))
        .where((e) => e.isNotEmpty)
        .toList();

    var y = year, m = month, a = age;
    var location = previous.location;
    var identity = previous.identity;
    var savings = previous.savings;
    var relationship = previous.relationship;
    var health = previous.health;
    var skills = List<String>.from(previous.skills);
    var visionScore = previous.visionScore;
    var visionNote = previous.visionNote;
    var risks = <String>[];

    final headerRe = RegExp(r'(\d{4})\s*年\s*(\d{1,2})\s*月[·・\.]?\s*(\d{1,2})\s*岁');
    final header = headerRe.firstMatch(cleaned);
    if (header != null) {
      y = int.parse(header.group(1)!);
      m = int.parse(header.group(2)!);
      a = int.parse(header.group(3)!);
    }

    final pipeLines =
        lines.where((l) => l.contains('|') || l.contains('｜')).toList();
    if (pipeLines.isNotEmpty) {
      final parts = _splitPipe(pipeLines.first);
      if (parts.isNotEmpty && parts[0].isNotEmpty) location = parts[0];
      if (parts.length >= 2 && parts[1].isNotEmpty) identity = parts[1];
      final s = RegExp(r'积蓄\s*[:：]?\s*(-?\d+)').firstMatch(pipeLines.first);
      if (s != null) savings = int.parse(s.group(1)!);
    }
    if (pipeLines.length >= 2) {
      final parts = _splitPipe(pipeLines[1]);
      if (parts.isNotEmpty && parts[0].isNotEmpty) relationship = parts[0];
      if (parts.length >= 2 && parts[1].isNotEmpty) health = parts[1];
      if (parts.length >= 3 && parts[2].isNotEmpty) {
        skills = parts[2]
            .split(RegExp(r'[/、,，;；]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }

    for (final line in lines) {
      final vs = RegExp(r'长期愿景契合度\s*[:：]?\s*([1-5])').firstMatch(line);
      if (vs != null) {
        visionScore = int.parse(vs.group(1)!);
        final note = RegExp(r'[（(]([^）)]*)[)）]').firstMatch(line);
        if (note != null) visionNote = note.group(1)!.trim();
        continue;
      }
      final rk = RegExp(r'潜在风险\s*[:：]\s*(.+)').firstMatch(line);
      if (rk != null) {
        final value = rk.group(1)!.trim();
        if (value.isNotEmpty && value != '暂无' && value != '无' && value != '—') {
          risks = value
              .split(RegExp(r'[；;、,，]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
    }

    return MonthlyState(
      year: y,
      month: m,
      age: a,
      location: location,
      identity: identity,
      savings: savings,
      relationship: relationship,
      health: health,
      skills: skills,
      visionScore: visionScore.clamp(1, 5),
      visionNote: visionNote,
      risks: risks,
      archiveLine: archiveLine,
    );
  }

  static List<String> _splitPipe(String line) => line
      .split(RegExp(r'[|｜]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  static MonthlyPlan parsePlan(String text) {
    final items = <PlanItem>[];
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('总权重')) continue;
      final match =
          RegExp(r'^[-*]?\s*([A-Da-d])\s*[\.、．):：]\s*(.+)$').firstMatch(line);
      if (match == null) continue;
      final label = match.group(1)!.toUpperCase();
      var rest = match.group(2)!.trim();

      var weight = 0;
      final weightMatch = RegExp(
              r'[（(]\s*建议权重\s*[:：]?\s*(\d+)\s*%?\s*[)）]')
          .firstMatch(rest);
      if (weightMatch != null) {
        weight = int.parse(weightMatch.group(1)!);
        rest = rest.replaceRange(weightMatch.start, weightMatch.end, '').trim();
      }

      var reason = '';
      final reasonMatch = RegExp(r'[—\-–]{2,}\s*(.+)$').firstMatch(rest);
      if (reasonMatch != null) {
        reason = reasonMatch.group(1)!.trim();
        rest = rest.substring(0, reasonMatch.start).trim();
      }

      rest = rest.replaceAll(RegExp(r'^[：:]\s*'), '').trim();
      if (rest.endsWith('。')) rest = rest.substring(0, rest.length - 1);

      items.add(PlanItem(
        label: label,
        name: rest,
        weight: weight,
        reason: reason,
      ));
    }
    final plan = MonthlyPlan(items: items);
    if (items.isNotEmpty && plan.totalWeight != 100) {
      plan.renormalize();
    }
    return plan;
  }

  static List<Choice> parseChoices(String text) {
    final out = <Choice>[];
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final match =
          RegExp(r'^[-*]?\s*([A-Da-d])\s*[\.、．):：]\s*(.+)$').firstMatch(line);
      if (match == null) continue;
      var rest = match.group(2)!.trim();
      var dimension = '';
      final dimMatch = RegExp(r'[\[【(（]([^\]】)）]{1,14})[\]】)）]\s*$').firstMatch(rest);
      if (dimMatch != null) {
        dimension = dimMatch.group(1)!.trim();
        rest = rest.substring(0, dimMatch.start).trim();
      }
      if (rest.endsWith('。')) rest = rest.substring(0, rest.length - 1);
      if (rest.isEmpty) continue;
      out.add(Choice(
        label: match.group(1)!.toUpperCase(),
        description: rest,
        dimension: dimension,
      ));
    }
    return out;
  }

  static List<Choice> defaultChoices(MonthlyPlan plan) {
    if (plan.items.isEmpty) {
      return const [
        Choice(label: 'A', description: '按既定计划推进，保持节奏', dimension: '执行'),
        Choice(label: 'B', description: '临时增加一项高价值投入', dimension: '加码'),
        Choice(label: 'C', description: '放慢节奏，优先休整与复盘', dimension: '休整'),
        Choice(label: 'D', description: '调整方向，尝试新领域', dimension: '转向'),
      ];
    }
    return plan.items
        .map((e) => Choice(
              label: e.label,
              description: '按「${e.name}」推进',
              dimension: e.dimension.isEmpty ? '执行' : e.dimension,
            ))
        .toList();
  }

  /// 把 ARCHIVE 注释行解析成 ArchiveLine；解析失败时用快照兜底。
  static ArchiveLine buildArchiveLine({
    required String comment,
    required MonthlyState snapshot,
    required String narrative,
    required String rawOutput,
    required String lastEventMonth,
  }) {
    final match = _archiveRe.firstMatch(comment);
    final body = match?.group(1)?.trim() ?? '';
    final parts = body.split('|').map((e) => e.trim()).toList();
    if (parts.length >= 8) {
      final ym = parts[0];
      final ymMatch = RegExp(r'Y(\d{4})M(\d{1,2})').firstMatch(ym);
      final year = ymMatch != null
          ? int.parse(ymMatch.group(1)!)
          : snapshot.year;
      final month =
          ymMatch != null ? int.parse(ymMatch.group(2)!) : snapshot.month;
      final scoreMatch = RegExp(r'(\d)').firstMatch(parts[7]);
      return ArchiveLine(
        yearMonth: 'Y${year}M$month',
        year: year,
        month: month,
        age: snapshot.age,
        location: parts[1],
        identity: parts[2],
        savings: int.tryParse(RegExp(r'-?\d+').firstMatch(parts[3])?.group(0) ?? '') ??
            snapshot.savings,
        health: parts[4],
        skills: parts[5],
        risks: parts[6],
        visionScore: scoreMatch != null
            ? int.parse(scoreMatch.group(1)!)
            : snapshot.visionScore,
        lastEventMonth: parts.length > 8 ? parts[8] : '',
        narrative: narrative,
        rawOutput: rawOutput,
      );
    }
    return ArchiveLine(
      yearMonth: 'Y${snapshot.year}M${snapshot.month}',
      year: snapshot.year,
      month: snapshot.month,
      age: snapshot.age,
      location: snapshot.location,
      identity: snapshot.identity,
      savings: snapshot.savings,
      health: snapshot.health,
      skills: snapshot.skills.join('/'),
      risks: snapshot.risks.join('；'),
      visionScore: snapshot.visionScore,
      lastEventMonth: lastEventMonth,
      narrative: narrative,
      rawOutput: rawOutput,
    );
  }
}