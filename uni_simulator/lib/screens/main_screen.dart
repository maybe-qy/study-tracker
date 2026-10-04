import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/game_provider.dart';
import '../services/command_service.dart';
import '../services/prompt_builder.dart';
import '../theme/app_theme.dart';
import 'archive_screen.dart';
import 'narrative_screen.dart';
import 'profile_screen.dart';

/// 主游戏界面：推演 / 存档 / 档案 三个标签，顶栏提供计划、命令与设置入口。
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    ref.listen<GameUiState>(gameProvider, (previous, next) {
      final error = next.error;
      if (error != null && error != previous?.error) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        ref.read(gameProvider.notifier).clearError();
      }
      if (next.recalibrationPrompt != null &&
          previous?.recalibrationPrompt == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.push('/recalibrate');
        });
      }
    });

    final ui = ref.watch(gameProvider);
    final game = ui.game;

    if (game == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('大学模拟器')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_add_alt, size: 44, color: AppColors.line),
              const SizedBox(height: 16),
              const Text('尚未建立档案。',
                  style: TextStyle(fontSize: 14, color: AppColors.inkSoft)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('去初始化'),
              ),
            ],
          ),
        ),
      );
    }

    final phase = PromptBuilder.phaseOf(game.profile, game.year, game.month);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(game.displayMonth),
            Text(
              '$phase · ${game.profile.name}${game.paused ? ' · 已暂停' : ''}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: AppColors.inkSoft,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '调整计划',
            onPressed: () => context.push('/plan'),
            icon: const Icon(Icons.edit_note),
          ),
          IconButton(
            tooltip: '命令',
            onPressed: _showCommandDialog,
            icon: const Icon(Icons.terminal),
          ),
          IconButton(
            tooltip: '设置',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: const [
              NarrativeScreen(),
              ArchiveScreen(),
              ProfileScreen(),
            ],
          ),
          if (ui.busy) _busyOverlay(ui.status),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: '推演',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: '存档',
          ),
          NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge),
            label: '档案',
          ),
        ],
      ),
    );
  }

  Widget _busyOverlay(String? status) => Container(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
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
                    status ?? '处理中…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Future<void> _showCommandDialog() async {
    final controller = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('命令'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: '/help'),
              onSubmitted: (v) => Navigator.pop(dialogContext, v),
            ),
            const SizedBox(height: 12),
            const Text(
              '/restart  /pause  /resume\n/edit  /jump 2029 3  /export  /help',
              style: TextStyle(
                  fontSize: 11.5, color: AppColors.inkSoft, height: 1.8),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('执行'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (input == null || input.trim().isEmpty) return;
    await _execute(input.trim());
  }

  Future<void> _execute(String input) async {
    final command = CommandService().parse(input);
    final notifier = ref.read(gameProvider.notifier);
    switch (command.type) {
      case GameCommandType.restart:
        final ok = await _confirm(
          '重新开始',
          '将清空当前档案与全部存档，且不可恢复。确定继续吗？',
          confirmText: '清空并重开',
        );
        if (ok != true) return;
        await notifier.restart();
        if (mounted) context.go('/');
        break;
      case GameCommandType.pause:
        if (!(ref.read(gameProvider).game?.paused ?? false)) {
          await notifier.togglePause();
        }
        _toast('已暂停推演。');
        break;
      case GameCommandType.resume:
        if (ref.read(gameProvider).game?.paused ?? false) {
          await notifier.togglePause();
        }
        _toast('已继续推演。');
        break;
      case GameCommandType.edit:
        setState(() => _index = 2);
        _toast('已切换到档案页，点击字段即可修改。');
        break;
      case GameCommandType.jump:
        final year = command.year!;
        final month = command.month!;
        final ok = await _confirm(
          '跳转月份',
          '将跳转到 $year 年 $month 月重新推演，并删除该月及其后的存档。',
          confirmText: '跳转',
        );
        if (ok != true) return;
        await notifier.jumpTo(year, month);
        if (!mounted) return;
        final error = ref.read(gameProvider).error;
        if (error != null) {
          _toast(error);
          return;
        }
        context.push('/plan');
        break;
      case GameCommandType.export:
        final markdown = await notifier.exportMarkdown();
        if (!mounted) return;
        await _showExport(markdown);
        break;
      case GameCommandType.help:
        await _showInfo('命令列表', CommandService.help);
        break;
      case GameCommandType.unknown:
        _toast('未知命令。输入 /help 查看可用命令。');
        break;
    }
  }

  Future<bool?> _confirm(String title, String content,
      {String confirmText = '确定'}) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content, style: const TextStyle(height: 1.7)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  Future<void> _showInfo(String title, String content) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: SelectableText(
            content,
            style: const TextStyle(fontSize: 13, height: 1.8),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('关闭'),
            ),
          ],
        ),
      );

  Future<void> _showExport(String markdown) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('导出 ARCHIVE'),
          content: SizedBox(
            width: double.maxFinite,
            height: 380,
            child: SingleChildScrollView(
              child: SelectableText(
                markdown.isEmpty ? '（暂无存档）' : markdown,
                style: const TextStyle(fontSize: 12, height: 1.7),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: markdown));
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板')),
                  );
                }
              },
              child: const Text('复制全部'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('关闭'),
            ),
          ],
        ),
      );

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}