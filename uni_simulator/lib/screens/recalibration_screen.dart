import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/game_provider.dart';
import '../providers/service_providers.dart';
import '../theme/app_theme.dart';

/// 愿景重校准：连续三个月愿景契合度 ≤ 2 星时进入。
class RecalibrationScreen extends ConsumerStatefulWidget {
  const RecalibrationScreen({super.key});

  @override
  ConsumerState<RecalibrationScreen> createState() =>
      _RecalibrationScreenState();
}

class _RecalibrationScreenState extends ConsumerState<RecalibrationScreen> {
  final _answer = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _answer.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '请先写下你的回答，再继续。');
      return;
    }
    final game = ref.read(gameProvider).game;
    if (game == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final (vision, note) = await ref
          .read(narrativeServiceProvider)
          .recalibrateVision(
            settings: ref.read(llmSettingsProvider),
            state: game,
            userAnswer: text,
          );
      await ref
          .read(gameProvider.notifier)
          .applyRecalibration(vision, note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('长期愿景已更新：$vision')),
      );
      context.pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prompt = ref.watch(gameProvider).recalibrationPrompt ??
        '（重校准对话缺失）';
    return Scaffold(
      appBar: AppBar(
        title: const Text('愿景重校准'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(gameProvider.notifier).dismissRecalibration();
            context.pop();
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                prompt,
                style: AppTheme.narrativeStyle,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '你的回答',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _answer,
            maxLines: 8,
            style: const TextStyle(fontSize: 14.5, height: 1.8),
            decoration: const InputDecoration(
              hintText: '不必写得多完整，只要诚实。',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.danger, height: 1.6),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('提交并重新校准'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              ref.read(gameProvider.notifier).dismissRecalibration();
              context.pop();
            },
            child: const Text('暂不校准，继续推演'),
          ),
        ],
      ),
    );
  }
}