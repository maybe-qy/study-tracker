import 'package:flutter/material.dart';

import '../models/random_event.dart';
import '../theme/app_theme.dart';

/// 选择题按钮。
class ChoiceButton extends StatelessWidget {
  final Choice choice;
  final bool enabled;
  final VoidCallback onTap;

  const ChoiceButton({
    super.key,
    required this.choice,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    choice.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        choice.description,
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.55,
                          color: AppColors.ink,
                        ),
                      ),
                      if (choice.dimension.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.bone,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Text(
                            choice.dimension,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.inkSoft),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}