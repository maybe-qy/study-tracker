import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/game_state.dart';
import '../models/random_event.dart';
import '../providers/game_provider.dart';
import '../services/prompt_builder.dart';
import '../theme/app_theme.dart';
import '../widgets/choice_button.dart';
import '../widgets/state_snapshot.dart';
import '../widgets/typewriter_text.dart';

/// 叙事展示（主游戏页的「推演」标签）。
class NarrativeScreen extends ConsumerWidget {
  const NarrativeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider).game;
    if (game == null) {
      return const _Hint(
        icon: Icons.person_add_alt,
        text: '尚未建立档案。请先完成初始化。',
      );
    }

    final output = game.lastOutput;
    if (output == null) {
      return _PendingMonth(game: game);
    }

    final snapshot = output.snapshot;
    final choices = game.pendingChoices;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _monthHeader(game),
              if (game.pendingEvent?.triggered ?? false) ...[
                const SizedBox(height: 12),
                _eventBanner(game.pendingEvent!),
              ],
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  child: TypewriterText(
                    key: ValueKey('narrative-${game.year}-${game.month}'),
                    text: output.narrative,
                    style: AppTheme.narrativeStyle,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '（轻触正文可立即显示全文）',
                style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 16),
              StateSnapshotCard(
                state: snapshot,
                archiveLine: output.archiveLine.isNotEmpty
                    ? output.archiveLine
                    : snapshot.archiveLine,
                onCopyArchive: () async {
                  final text = output.archiveLine.isNotEmpty
                      ? output.archiveLine
                      : snapshot.archiveLine;
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ARCHIVE 行已复制')),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              _nextPlanPreview(game),
            ],
          ),
        ),
        if (!game.choicesResolved && choices.isNotEmpty)
          _choiceBar(context, ref, choices),
        if (game.choicesResolved) _resolvedBar(context),
      ],
    );
  }

  Widget _monthHeader(GameState game) {
    final phase = PromptBuilder.phaseOf(game.profile, game.year, game.month);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          game.displayMonth,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '$phase · ${game.profile.name}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
          ),
        ),
      ],
    );
  }

  Widget _eventBanner(RandomEvent event) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt_outlined,
                    size: 16, color: AppColors.danger),
                const SizedBox(width: 6),
                Text(
                  '${event.type} · ${event.title}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              event.description,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.ink, height: 1.6),
            ),
          ],
        ),
      );

  Widget _nextPlanPreview(GameState game) {
    final plan = game.nextPlanDraft;
    if (plan == null || plan.items.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '下月计划草案',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            ...plan.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${item.label}. ${item.name}（${item.weight}%）',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.inkSoft, height: 1.6),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _choiceBar(
      BuildContext context, WidgetRef ref, List<Choice> choices) {
    return Material(
      color: AppColors.bone,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '本月选择（提交后进入下月计划）',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                child: Column(
                  children: choices
                      .map((choice) => ChoiceButton(
                            choice: choice,
                            enabled: !ref.watch(gameProvider).busy &&
                                !(ref.watch(gameProvider).game?.paused ?? false),
                            onTap: () => _confirmChoice(context, ref, choice),
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resolvedBar(BuildContext context) => Material(
        color: AppColors.bone,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '本月选择已提交。',
                  style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
              ),
              FilledButton(
                onPressed: () => context.push('/plan'),
                child: const Text('调整下月计划'),
              ),
            ],
          ),
        ),
      );

  Future<void> _confirmChoice(
      BuildContext context, WidgetRef ref, Choice choice) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('确认本月选择',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
            const SizedBox(height: 12),
            Text(
              '${choice.label}. ${choice.description}',
              style: const TextStyle(
                  fontSize: 14.5, height: 1.7, color: AppColors.ink),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: const Text('再想想'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: const Text('确认'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await ref.read(gameProvider.notifier).choose(choice);
    if (context.mounted) context.push('/plan');
  }
}

class _PendingMonth extends StatelessWidget {
  final GameState game;
  const _PendingMonth({required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_note, size: 44, color: AppColors.line),
            const SizedBox(height: 16),
            Text(
              '${game.displayMonth} 尚未推演。\n调整并确认计划后，这里会出现本月的叙事。',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.inkSoft, height: 1.9),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.push('/plan'),
              child: const Text('去调整计划'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Hint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: AppColors.line),
              const SizedBox(height: 16),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.inkSoft, height: 1.9),
              ),
            ],
          ),
        ),
      );
}