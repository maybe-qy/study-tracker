import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/archive_line.dart';
import '../providers/service_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/archive_timeline.dart';

/// 存档时间线（按月排列，点击展开详情）。
class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(archivesProvider);
    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
            strokeWidth: 2.5, color: AppColors.accent),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            '读取存档失败：$error',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.danger),
          ),
        ),
      ),
      data: (lines) => RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async => ref.invalidate(archivesProvider),
        child: ArchiveTimeline(
          lines: lines,
          onOpen: (line) => _openDetail(context, line),
        ),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, ArchiveLine line) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${line.year}年${line.month}月 · ${line.age}岁',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '复制 ARCHIVE 行',
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: line.toCommentLine()));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ARCHIVE 行已复制')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_outlined,
                        size: 18, color: AppColors.inkSoft),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Text(
                    '${line.location} | ${line.identity} | 积蓄 ${line.savings}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${line.health} | ${line.skills}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.inkSoft),
                  ),
                  if (line.risks.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '潜在风险：${line.risks}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.danger, height: 1.6),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SelectableText(
                    line.narrative.isEmpty ? '（本月叙事未保存）' : line.narrative,
                    style: AppTheme.narrativeStyle,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bone,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: SelectableText(
                      line.toCommentLine(),
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.5,
                        color: AppColors.inkSoft,
                        fontFamily: 'monospace',
                        fontFamilyFallback: ['monospace'],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}