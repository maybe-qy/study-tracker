import 'package:flutter/material.dart';

import '../models/monthly_plan.dart';
import '../theme/app_theme.dart';

/// 计划事项卡片：权重滑块 + 名称编辑 + 删除。
class PlanCard extends StatelessWidget {
  final PlanItem item;
  final int index;
  final bool draggable;
  final ValueChanged<int> onWeightChanged;
  final VoidCallback? onRemove;
  final VoidCallback? onEditName;

  const PlanCard({
    super.key,
    required this.item,
    required this.index,
    this.draggable = false,
    required this.onWeightChanged,
    this.onRemove,
    this.onEditName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onEditName,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name.isEmpty ? '（未命名事项）' : item.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                            height: 1.4,
                          ),
                        ),
                        if (item.reason.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.reason,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (item.dimension.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.bone,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text(item.dimension,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.inkSoft)),
                  ),
                if (onRemove != null)
                  IconButton(
                    tooltip: '移除事项',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, size: 18, color: AppColors.inkSoft),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: item.weight.toDouble().clamp(0, 100),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    onChanged: (v) => onWeightChanged(v.round()),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${item.weight}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}