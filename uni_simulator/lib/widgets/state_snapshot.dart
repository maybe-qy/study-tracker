import 'package:flutter/material.dart';

import '../models/monthly_state.dart';
import '../theme/app_theme.dart';

/// 状态快照卡片。关键数据高亮，风险项红色标注。
class StateSnapshotCard extends StatelessWidget {
  final MonthlyState state;
  final String? archiveLine;
  final VoidCallback? onCopyArchive;

  const StateSnapshotCard({
    super.key,
    required this.state,
    this.archiveLine,
    this.onCopyArchive,
  });

  static const List<String> _healthKeywords = ['身体', '健康', '熬夜', '失眠', '病', '疲惫'];

  bool get _showGentleReminder => state.risks
      .any((r) => _healthKeywords.any((k) => r.contains(k)));

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_outlined,
                    size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 8),
                Text(
                  '${state.year}年${state.month}月 · ${state.age}岁 状态快照',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _line(
              icons: Icons.place_outlined,
              text: state.location.isEmpty ? '—' : state.location,
              trailingWidget: _chip('身份', state.identity.isEmpty ? '—' : state.identity),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _metric('积蓄', '${state.savings}', highlight: true),
                const SizedBox(width: 10),
                _metric('健康', state.health.isEmpty ? '—' : state.health),
                const SizedBox(width: 10),
                Expanded(
                  child: _metric(
                    '关系',
                    state.relationship.isEmpty ? '—' : state.relationship,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _visionRow(),
            const SizedBox(height: 10),
            _skillsRow(),
            const SizedBox(height: 12),
            _risksRow(),
            if (_showGentleReminder) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '身体信号持续被忽略，建议暂停推演。',
                  style: TextStyle(fontSize: 13, color: AppColors.danger),
                ),
              ),
            ],
            if (archiveLine != null && archiveLine!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.bone,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Text(
                        archiveLine!,
                        style: const TextStyle(
                          fontSize: 10.5,
                          height: 1.5,
                          color: AppColors.inkSoft,
                          fontFamily: 'monospace',
                          fontFamilyFallback: ['monospace'],
                        ),
                      ),
                    ),
                  ),
                  if (onCopyArchive != null)
                    IconButton(
                      tooltip: '复制 ARCHIVE 行',
                      onPressed: onCopyArchive,
                      icon: const Icon(Icons.copy_outlined,
                          size: 18, color: AppColors.inkSoft),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line({
    required IconData icons,
    required String text,
    Widget? trailingWidget,
  }) =>
      Row(
        children: [
          Icon(icons, size: 16, color: AppColors.inkSoft),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: AppColors.ink),
            ),
          ),
          ?trailingWidget,
        ],
      );

  Widget _chip(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.accentSoft,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$label $value',
          style: const TextStyle(fontSize: 11.5, color: AppColors.accent),
        ),
      );

  Widget _metric(String label, String value, {bool highlight = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: highlight ? 19 : 14,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              color: highlight ? AppColors.accent : AppColors.ink,
            ),
          ),
        ],
      );

  Widget _visionRow() => Row(
        children: [
          const Text('长期愿景契合度',
              style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          const SizedBox(width: 8),
          ...List.generate(
            5,
            (i) => Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(
                i < state.visionScore ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 16,
                color: i < state.visionScore
                    ? AppColors.warn
                    : AppColors.line,
              ),
            ),
          ),
          if (state.visionNote.isNotEmpty) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                state.visionNote,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
            ),
          ],
        ],
      );

  Widget _skillsRow() {
    if (state.skills.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: state.skills
          .map((s) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bone,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(s,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.ink)),
              ))
          .toList(),
    );
  }

  Widget _risksRow() {
    if (state.risks.isEmpty) {
      return const Row(
        children: [
          Icon(Icons.check_circle_outline, size: 15, color: AppColors.inkSoft),
          SizedBox(width: 6),
          Text('潜在风险：暂无',
              style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('潜在风险',
            style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
        const SizedBox(height: 6),
        ...state.risks.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(Icons.warning_amber_rounded,
                        size: 14, color: AppColors.danger),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      r,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.danger, height: 1.5),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}