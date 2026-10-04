import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/llm_settings.dart';
import '../providers/service_providers.dart';
import '../theme/app_theme.dart';

/// 设置页：由使用者自行填写 LLM 配置。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late final TextEditingController _model;
  late double _temperature;
  late int _maxTokens;
  late String _provider;
  bool _obscure = true;
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(llmSettingsProvider);
    _baseUrl = TextEditingController(text: s.baseUrl);
    _apiKey = TextEditingController(text: s.apiKey);
    _model = TextEditingController(text: s.model);
    _temperature = s.temperature;
    _maxTokens = s.maxTokens;
    _provider = s.provider;
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    super.dispose();
  }

  LlmSettings _compose() => LlmSettings(
        provider: _provider,
        baseUrl: _baseUrl.text.trim(),
        apiKey: _apiKey.text.trim(),
        model: _model.text.trim(),
        temperature: _temperature,
        maxTokens: _maxTokens,
      );

  Future<void> _save() async {
    await ref.read(llmSettingsProvider.notifier).update(_compose());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已保存')));
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final reply =
          await ref.read(llmServiceProvider).testConnection(_compose());
      setState(() {
        _testOk = true;
        _testResult = '连接成功，模型回复：$reply';
      });
    } catch (e) {
      setState(() {
        _testOk = false;
        _testResult = e.toString();
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _applyPreset(String provider) {
    final preset = LlmSettings.presets[provider];
    setState(() {
      _provider = provider;
      if (preset != null) {
        if ((preset['baseUrl'] ?? '').isNotEmpty) {
          _baseUrl.text = preset['baseUrl']!;
        }
        if ((preset['model'] ?? '').isNotEmpty) {
          _model.text = preset['model']!;
        }
      }
    });
    ref.read(llmSettingsProvider.notifier).applyPreset(provider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          const Text(
            '叙事由大模型生成。请填写你自己的 API Key；本应用不会上传除推演请求外的任何数据。',
            style: TextStyle(
                fontSize: 12.5, color: AppColors.inkSoft, height: 1.8),
          ),
          const SizedBox(height: 18),
          _label('服务商'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: LlmSettings.presets.entries.map((entry) {
              final selected = _provider == entry.key;
              return ChoiceChip(
                label: Text(entry.value['label'] ?? entry.key),
                selected: selected,
                onSelected: (_) => _applyPreset(entry.key),
                selectedColor: AppColors.accentSoft,
                backgroundColor: AppColors.surface,
                side: BorderSide(
                    color: selected ? AppColors.accent : AppColors.line),
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  color: selected ? AppColors.accent : AppColors.ink,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _label('接口地址（Base URL）'),
          TextField(
            controller: _baseUrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'https://api.deepseek.com/v1',
            ),
          ),
          const SizedBox(height: 18),
          _label('API Key'),
          TextField(
            controller: _apiKey,
            obscureText: _obscure,
            decoration: InputDecoration(
              hintText: 'sk-...',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.inkSoft,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _label('模型名'),
          TextField(
            controller: _model,
            decoration: const InputDecoration(hintText: 'deepseek-chat'),
          ),
          const SizedBox(height: 18),
          _label('Temperature（叙事随机性）'),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _temperature,
                  min: 0,
                  max: 2,
                  divisions: 20,
                  label: _temperature.toStringAsFixed(1),
                  onChanged: (v) => setState(() => _temperature = v),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  _temperature.toStringAsFixed(1),
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
          const SizedBox(height: 6),
          _label('单次最大 Token'),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _maxTokens.toDouble(),
                  min: 1024,
                  max: 16384,
                  divisions: 30,
                  label: '$_maxTokens',
                  onChanged: (v) =>
                      setState(() => _maxTokens = v.round()),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '$_maxTokens',
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
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: _testing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering, size: 16),
                  label: Text(_testing ? '测试中…' : '测试连接'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('保存配置'),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _testOk ? AppColors.accentSoft : AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _testResult!,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  color: _testOk ? AppColors.accent : AppColors.danger,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            '说明\n'
            '· 支持 OpenAI 兼容接口（DeepSeek / OpenAI / 自建）与 Anthropic Claude。\n'
            '· 长文叙事建议 max tokens ≥ 4096，温度 0.8–1.1。\n'
            '· 密钥仅保存在本机 Hive 数据库中。',
            style: TextStyle(
                fontSize: 12, color: AppColors.inkSoft, height: 1.9),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      );
}