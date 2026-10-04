import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/game_provider.dart';
import '../providers/plan_provider.dart';
import '../services/prompt_builder.dart';
import '../theme/app_theme.dart';
import '../widgets/plan_card.dart';

/// 计划调整页：调整下月各项权重、增删与排序。
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final game = ref.read(gameProvider).game;
      if (game != null) {
        ref.read(planProvider.notifier).load(game.pendingPlan);
      }
    });
  }

  Future<void> _confirm() async {
    final plan = ref.read(planProvider);
    if (plan.items.isEmpty) {
      _toast('至少保留一项计划。');
      return;
    }
    if (plan.totalWeight != 100) {
      _toast('权重合计需为 100%（当前 ${plan.totalWeight}%）。');
      return;
    }
    await ref.read(gameProvider.notifier).confirmPlan(plan);
    if (!mounted) return;
    final error = ref.read(gameProvider).error;
    if (error != null) {
      _toast(error);
      return;
    }
    context.go('/game');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editName(int index, String current) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑事项'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(hintText: '事项内容'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty) {
      ref.read(planProvider.notifier).rename(index, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(gameProvider);
    final game = ui.game;
    final plan = ref.watch(planProvider);
    final notifier = ref.read(planProvider.notifier);

    if (game == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('计划调整')),
        body: const Center(child: Text('尚未建立档案。')),
      );
    }

    final phase = PromptBuilder.phaseOf(game.profile, game.year, game.month);
    final event = game.pendingEvent;
    final total = plan.totalWeight;

    return Scaffold(
      appBar: AppBar(
        title: Text('${game.displayMonth} 计划'),
        actions: [
          IconButton(
            tooltip: '归档',
            onPressed: () => context.go('/game'),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Text(
                      '$phase · 计划草案（可调整）',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '永久项「运动锚点（20%）+ 英语线」已绑定贯穿全程，无需在此列出，但会出现在叙事中。',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                        height: 1.7,
                      ),
                    ),
                    if (event != null && event.triggered) ...[
                      const SizedBox(height: 14),
                      _eventCard(event.title, event.type, event.description),
                    ],
                    const SizedBox(height: 16),
                    if (plan.items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            '当前没有计划事项。\n可点击下方「添加事项」，或回到初始化重新生成。',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.inkSoft,
                                height: 1.8),
                          ),
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: plan.items.length,
                        onReorderItem: notifier.reorder,
                        itemBuilder: (context, index) {
                          final item = plan.items[index];
                          return Padding(
                            key: ObjectKey(item),
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: PlanCard(
                                    item: item,
                                    index: index,
                                    onWeightChanged: (v) =>
                                        notifier.setWeight(index, v),
                                    onEditName: () =>
                                        _editName(index, item.name),
                                    onRemove: plan.items.length > 1
                                        ? () => notifier.removeAt(index)
                                        : null,
                                  ),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Padding(
                                    padding: EdgeInsets.only(top: 22, left: 2),
                                    child: Icon(Icons.drag_indicator,
                                        size: 18, color: AppColors.inkSoft),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: plan.items.length >= 6
                              ? null
                              : notifier.addItem,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('添加事项'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: notifier.distributeEvenly,
                          child: const Text('均分权重'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: notifier.normalize,
                          child: const Text('归一到 100%'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _bottomBar(total),
            ],
          ),
          if (ui.busy)
            Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: AppColors.accent),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          ui.status ?? '处理中…',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13.5, color: AppColors.ink),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _eventCard(String title, String type, String description) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt_outlined, size: 16, color: AppColors.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '本月随机事件 · $type',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink)),
            const SizedBox(height: 4),
            Text(description,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.ink, height: 1.6)),
          ],
        ),
      );

  Widget _bottomBar(int total) {
    final valid = total == 100;
    return Material(
      color: AppColors.bone,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Row(
          children: [
            Row(
              children: [
                const Text('总权重',
                    style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
                const SizedBox(width: 6),
                Text(
                  '$total%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: valid ? AppColors.accent : AppColors.danger,
                  ),
                ),
              ],
            ),
            const Spacer(),
            FilledButton(
              onPressed: (valid && !ref.watch(gameProvider).busy) ? _confirm : null,
              child: const Text('确认并推演本月'),
            ),
          ],
        ),
      ),
    );
  }
}