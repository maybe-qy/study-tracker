import 'package:flutter/material.dart';

import '../models/archive_line.dart';
import '../theme/app_theme.dart';

/// ARCHIVE 时间线。
class ArchiveTimeline extends StatelessWidget {
  final List<ArchiveLine> lines;
  final void Function(ArchiveLine line)? onOpen;

  const ArchiveTimeline({super.key, required this.lines, this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          children: [
            Icon(Icons.timeline, size: 40, color: AppColors.line),
            SizedBox(height: 12),
            Text(
              '还没有存档。完成第一个月的推演后，\nARCHIVE 行会按月出现在这里。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft, height: 1.8),
            ),
          ],
        ),
      );
    }

    // 按年份分组
    final grouped = <int, List<ArchiveLine>>{};
    for (final line in lines) {
      grouped.putIfAbsent(line.year, () => []).add(line);
    }
    final years = grouped.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        for (final year in years) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
            child: Text(
              '$year 年',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                letterSpacing: 1,
              ),
            ),
          ),
          ...grouped[year]!.map((line) => _TimelineTile(line: line, onOpen: onOpen)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final ArchiveLine line;
  final void Function(ArchiveLine line)? onOpen;

  const _TimelineTile({required this.line, this.onOpen});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 18),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Container(width: 1.5, color: AppColors.line),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onOpen == null ? null : () => onOpen!(line),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${line.month}月 · ${line.age}岁',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                            const Spacer(),
                            ...List.generate(
                              5,
                              (i) => Icon(
                                i < line.visionScore
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 13,
                                color: i < line.visionScore
                                    ? AppColors.warn
                                    : AppColors.line,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${line.location} | ${line.identity}',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.inkSoft),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '积蓄 ${line.savings} | ${line.health}',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.inkSoft),
                        ),
                        if (line.risks.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '风险：${line.risks}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.danger,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}