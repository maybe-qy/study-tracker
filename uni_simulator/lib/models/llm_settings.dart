/// LLM 服务配置。Key 由使用者在「设置」页自行填写，默认不内置。
class LlmSettings {
  /// 服务商标识：deepseek / openai / anthropic / custom
  String provider;
  String baseUrl;
  String apiKey;
  String model;
  double temperature;
  int maxTokens;

  LlmSettings({
    this.provider = 'deepseek',
    this.baseUrl = 'https://api.deepseek.com/v1',
    this.apiKey = '',
    this.model = 'deepseek-chat',
    this.temperature = 0.9,
    this.maxTokens = 4096,
  });

  bool get isConfigured => apiKey.trim().isNotEmpty && baseUrl.trim().isNotEmpty;

  bool get isAnthropic => provider == 'anthropic';

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'temperature': temperature,
        'maxTokens': maxTokens,
      };

  factory LlmSettings.fromJson(Map<String, dynamic> json) => LlmSettings(
        provider: json['provider'] as String? ?? 'deepseek',
        baseUrl: json['baseUrl'] as String? ?? 'https://api.deepseek.com/v1',
        apiKey: json['apiKey'] as String? ?? '',
        model: json['model'] as String? ?? 'deepseek-chat',
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.9,
        maxTokens: (json['maxTokens'] as num?)?.toInt() ?? 4096,
      );

  LlmSettings copyWith({
    String? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
    double? temperature,
    int? maxTokens,
  }) =>
      LlmSettings(
        provider: provider ?? this.provider,
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
        temperature: temperature ?? this.temperature,
        maxTokens: maxTokens ?? this.maxTokens,
      );

  /// 各服务商的默认值，供设置页快速切换。
  static const Map<String, Map<String, String>> presets = {
    'deepseek': {
      'baseUrl': 'https://api.deepseek.com/v1',
      'model': 'deepseek-chat',
      'label': 'DeepSeek',
    },
    'openai': {
      'baseUrl': 'https://api.openai.com/v1',
      'model': 'gpt-4o-mini',
      'label': 'OpenAI',
    },
    'anthropic': {
      'baseUrl': 'https://api.anthropic.com',
      'model': 'claude-sonnet-4-5',
      'label': 'Anthropic Claude',
    },
    'custom': {
      'baseUrl': '',
      'model': '',
      'label': '自定义（OpenAI 兼容）',
    },
  };
}