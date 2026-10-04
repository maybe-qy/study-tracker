import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/character_profile.dart';
import '../models/milestone.dart';
import '../providers/character_provider.dart';
import '../providers/game_provider.dart';
import '../providers/service_providers.dart';
import '../theme/app_theme.dart';

/// 初始化流程：分步收集人物信息。
class InitScreen extends ConsumerStatefulWidget {
  const InitScreen({super.key});

  @override
  ConsumerState<InitScreen> createState() => _InitScreenState();
}

class _InitScreenState extends ConsumerState<InitScreen> {
  final _pageController = PageController();
  int _step = 0;
  static const int _totalSteps = 3;

  late final TextEditingController _name;
  late final TextEditingController _gender;
  late final TextEditingController _hometown;
  late final TextEditingController _university;
  late final TextEditingController _major;
  late final TextEditingController _personality;
  late final TextEditingController _vision;
  late final TextEditingController _strengths;
  late final TextEditingController _weaknesses;
  late final TextEditingController _forbidden;
  late final TextEditingController _permanent;
  late final TextEditingController _risk;

  DateTime _birthDate = DateTime(2009, 3, 15);
  DateTime _enrollDate = DateTime(2028, 9, 1);
  DateTime _gradDate = DateTime(2032, 6, 30);

  @override
  void initState() {
    super.initState();
    final p = ref.read(characterProvider);
    _name = TextEditingController(text: p.name);
    _gender = TextEditingController(text: p.gender);
    _hometown = TextEditingController(text: p.hometown);
    _university = TextEditingController(text: p.university);
    _major = TextEditingController(text: p.major);
    _personality = TextEditingController(text: p.personality.join('、'));
    _vision = TextEditingController(text: p.longTermVision);
    _strengths = TextEditingController(text: p.strengths.join('、'));
    _weaknesses = TextEditingController(text: p.weaknesses.join('、'));
    _forbidden = TextEditingController(text: p.forbiddenZone);
    _permanent = TextEditingController(text: p.permanentItems.join('、'));
    _risk = TextEditingController(text: p.riskTolerance);
    _birthDate = p.birthDate;
    _enrollDate = p.enrollmentDate;
    _gradDate = p.graduationDate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final game = ref.read(gameProvider).game;
      if (game != null && game.started) {
        context.go('/game');
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in [
      _name,
      _gender,
      _hometown,
      _university,
      _major,
      _personality,
      _vision,
      _strengths,
      _weaknesses,
      _forbidden,
      _permanent,
      _risk,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _parseList(String value) => value
      .split(RegExp(r'[,，、/;；|]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  CharacterProfile _buildProfile() {
    final personality = _parseList(_personality.text);
    return CharacterProfile(
      name: _name.text.trim().isEmpty ? '未命名' : _name.text.trim(),
      gender: _gender.text.trim(),
      birthDate: _birthDate,
      hometown: _hometown.text.trim(),
      university: _university.text.trim(),
      education: '本科',
      careerStatus: '大一新生',
      major: _major.text.trim(),
      enrollmentDate: _enrollDate,
      graduationDate: _gradDate,
      personality: personality.length > 5 ? personality.sublist(0, 5) : personality,
      longTermVision: _vision.text.trim(),
      strengths: _parseList(_strengths.text),
      weaknesses: _parseList(_weaknesses.text),
      forbiddenZone: _forbidden.text.trim(),
      preferences: const [],
      riskTolerance: _risk.text.trim(),
      keyNodes: [
        Milestone(
          label: '入学',
          date: _fmtYm(_enrollDate),
          description: _university.text.trim(),
        ),
        Milestone(
          label: '毕业',
          date: _fmtYm(_gradDate),
          description: '本科毕业',
        ),
      ],
      permanentItems: _permanent.text.trim().isEmpty
          ? const ['运动锚点', '英语线']
          : _parseList(_permanent.text),
    );
  }

  static String _fmtYm(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  double get _progress => (_step + 1) / _totalSteps;

  void _next() {
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _finish() async {
    final settings = ref.read(llmSettingsProvider);
    if (!settings.isConfigured) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('尚未配置 LLM'),
          content: const Text(
            '推演依赖大模型生成叙事。请先在「设置」中填写 API Key 与接口地址。',
            style: TextStyle(height: 1.7),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('去设置'),
            ),
          ],
        ),
      );
      if (go == true && mounted) context.push('/settings');
      return;
    }

    final profile = _buildProfile();
    ref.read(characterProvider.notifier).set(profile);
    await ref.read(gameProvider.notifier).newGame(profile);
    if (!mounted) return;
    final error = ref.read(gameProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    context.go('/plan');
  }

  @override
  Widget build(BuildContext context) {
    final hasSave = ref.watch(gameProvider).game?.started ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('大学模拟器'),
        actions: [
          IconButton(
            tooltip: '设置',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (hasSave)
              Container(
                width: double.infinity,
                color: AppColors.accentSoft,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('检测到已有存档。',
                          style: TextStyle(fontSize: 13, color: AppColors.accent)),
                    ),
                    TextButton(
                      onPressed: () => context.go('/game'),
                      child: const Text('继续推演'),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '第 ${_step + 1} / $_totalSteps 步',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.inkSoft),
                      ),
                      const Spacer(),
                      Text(
                        const ['基本信息', '学业信息', '人物设定'][_step],
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 4,
                      backgroundColor: AppColors.line,
                      valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _stepBasic(),
                  _stepStudy(),
                  _stepPersona(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: _back,
                      child: const Text('上一步'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_step == _totalSteps - 1 ? '开始推演' : '下一步'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scroll(List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: children,
      );

  Widget _stepBasic() => _scroll([
        _label('姓名'),
        _text(_name, hint: '林知远'),
        _label('性别'),
        _text(_gender, hint: '男 / 女'),
        _label('出生日期'),
        _dateTile(_birthDate, (d) => setState(() => _birthDate = d),
            first: DateTime(1990), last: DateTime(2020)),
        _label('家庭所在地'),
        _text(_hometown, hint: '成都'),
      ]);

  Widget _stepStudy() => _scroll([
        _label('大学 / 学校（含所在地）'),
        _text(_university, hint: '江城大学 · 江城'),
        _label('专业'),
        _text(_major, hint: '软件工程'),
        _label('入学时间'),
        _dateTile(_enrollDate, (d) => setState(() => _enrollDate = d),
            first: DateTime(2020), last: DateTime(2040)),
        _label('毕业时间'),
        _dateTile(_gradDate, (d) => setState(() => _gradDate = d),
            first: DateTime(2020), last: DateTime(2045)),
        _hint('提示：入学与毕业时间决定四年阶段划分（大一 / 大二 / 大三 / 大四）。'),
      ]);

  Widget _stepPersona() => _scroll([
        _label('核心性格（≤5 个词，用「、」分隔）'),
        _text(_personality, hint: '外冷内热、直接、爱较真、抗压强'),
        _label('长期愿景'),
        _text(_vision, hint: 'AI 产品方向 → 技术型产品负责人', maxLines: 3),
        _label('当前优势（用「、」分隔）'),
        _text(_strengths, hint: '逻辑缜密、动手能力强、善于复盘', maxLines: 3),
        _label('当前困境（用「、」分隔）'),
        _text(_weaknesses, hint: '新环境适应偏慢、表达偏克制', maxLines: 3),
        _label('底线 / 禁区'),
        _text(_forbidden, hint: '不碰违法、伤害他人之事', maxLines: 2),
        _label('永久项（贯穿全程，默认 运动锚点 + 英语线）'),
        _text(_permanent, hint: '运动锚点、英语线'),
        _label('风险偏好'),
        _text(_risk, hint: '中高'),
      ]);

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      );

  Widget _text(TextEditingController controller,
          {String? hint, int maxLines = 1}) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(hintText: hint),
      );

  Widget _dateTile(DateTime value, ValueChanged<DateTime> onPick,
      {required DateTime first, required DateTime last}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: first,
          lastDate: last,
          helpText: '选择日期',
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Text('${value.year} 年 ${value.month} 月 ${value.day} 日',
                style: const TextStyle(fontSize: 14)),
            const Spacer(),
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 12, color: AppColors.inkSoft, height: 1.7),
        ),
      );
}