import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/character_profile.dart';
import '../providers/character_provider.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';

/// 人物档案页：可编辑字段。
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider).game;
    final CharacterProfile profile =
        game != null ? game.profile : ref.watch(characterProvider);
    final editable = game != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (!editable)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              '当前为草稿档案，将在初始化完成后生效。',
              style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
            ),
          ),
        _section('基本'),
        _row(context, ref, profile, '姓名', profile.name, (p, v) => p.name = v),
        _row(context, ref, profile, '性别', profile.gender,
            (p, v) => p.gender = v),
        _dateRow(context, ref, profile, '出生日期', profile.birthDate,
            (p, v) => p.birthDate = v),
        _row(context, ref, profile, '家庭所在地', profile.hometown,
            (p, v) => p.hometown = v),
        _section('学业'),
        _row(context, ref, profile, '学校 / 所在地', profile.university,
            (p, v) => p.university = v),
        _row(context, ref, profile, '专业', profile.major, (p, v) => p.major = v),
        _dateRow(context, ref, profile, '入学时间', profile.enrollmentDate,
            (p, v) => p.enrollmentDate = v),
        _dateRow(context, ref, profile, '毕业时间', profile.graduationDate,
            (p, v) => p.graduationDate = v),
        _section('人物设定'),
        _listRow(context, ref, profile, '核心性格', profile.personality,
            (p, v) => p.personality = v, max: 5),
        _row(context, ref, profile, '长期愿景', profile.longTermVision,
            (p, v) => p.longTermVision = v, multiline: true),
        _listRow(context, ref, profile, '当前优势', profile.strengths,
            (p, v) => p.strengths = v),
        _listRow(context, ref, profile, '当前困境', profile.weaknesses,
            (p, v) => p.weaknesses = v),
        _row(context, ref, profile, '底线 / 禁区', profile.forbiddenZone,
            (p, v) => p.forbiddenZone = v, multiline: true),
        _listRow(context, ref, profile, '永久项', profile.permanentItems,
            (p, v) => p.permanentItems = v),
        _row(context, ref, profile, '风险偏好', profile.riskTolerance,
            (p, v) => p.riskTolerance = v),
        _section('关键节点'),
        ...profile.keyNodes.map((node) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flag_outlined,
                      size: 16, color: AppColors.inkSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${node.label}${node.date != null ? '（${node.date}）' : ''}'
                      '${node.description.isNotEmpty ? ' · ${node.description}' : ''}',
                      style: const TextStyle(fontSize: 13, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
            letterSpacing: 1.2,
          ),
        ),
      );

  CharacterProfile _clone(CharacterProfile p) =>
      CharacterProfile.fromJson(p.toJson());

  Future<void> _applyProfile(
      WidgetRef ref, CharacterProfile updated) async {
    if (ref.read(gameProvider).game != null) {
      await ref.read(gameProvider.notifier).updateProfile(updated);
    } else {
      ref.read(characterProvider.notifier).set(updated);
    }
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    CharacterProfile profile,
    String label,
    String value,
    void Function(CharacterProfile, String) apply, {
    bool multiline = false,
  }) =>
      _tile(
        label: label,
        value: value.isEmpty ? '—' : value,
        onTap: () async {
          final controller = TextEditingController(text: value);
          final result = await showDialog<String>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text('修改$label'),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLines: multiline ? 4 : 1,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, controller.text.trim()),
                  child: const Text('保存'),
                ),
              ],
            ),
          );
          controller.dispose();
          if (result == null) return;
          final target = _clone(profile);
          apply(target, result);
          await _applyProfile(ref, target);
        },
      );

  Widget _listRow(
    BuildContext context,
    WidgetRef ref,
    CharacterProfile profile,
    String label,
    List<String> value,
    void Function(CharacterProfile, List<String>) apply, {
    int? max,
  }) =>
      _tile(
        label: label,
        value: value.isEmpty ? '—' : value.join('、'),
        onTap: () async {
          final controller = TextEditingController(text: value.join('、'));
          final result = await showDialog<String>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text('修改$label'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: '用「、」分隔'),
                  ),
                  if (max != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('最多 $max 项',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.inkSoft)),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, controller.text.trim()),
                  child: const Text('保存'),
                ),
              ],
            ),
          );
          controller.dispose();
          if (result == null) return;
          var list = result
              .split(RegExp(r'[,，、/;；|]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          if (max != null && list.length > max) {
            list = list.sublist(0, max);
          }
          final target = _clone(profile);
          apply(target, list);
          await _applyProfile(ref, target);
        },
      );

  Widget _dateRow(
    BuildContext context,
    WidgetRef ref,
    CharacterProfile profile,
    String label,
    DateTime value,
    void Function(CharacterProfile, DateTime) apply,
  ) =>
      _tile(
        label: label,
        value: '${value.year}-${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}',
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value,
            firstDate: DateTime(1990),
            lastDate: DateTime(2100),
          );
          if (picked == null) return;
          final target = _clone(profile);
          apply(target, picked);
          await _applyProfile(ref, target);
        },
      );

  Widget _tile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    label,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.inkSoft),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                        fontSize: 13.5, color: AppColors.ink, height: 1.6),
                  ),
                ),
                const Icon(Icons.edit_outlined,
                    size: 15, color: AppColors.inkSoft),
              ],
            ),
          ),
        ),
      );
}