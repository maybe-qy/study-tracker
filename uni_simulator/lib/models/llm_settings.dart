/// LLM 服务配置。Key 由使用者在「设置」页自行填写，默认不内置。
class LlmSettings {
  /// 服务商标识：deepseek / openai / anthropic / custom
  String provider;
  String baseUrl;
  String apiKey;
  String model;
  double temperature;
  int maxTokens;

  /// 是否开启「思考模式」（仅 DeepSeek 生效）。
  /// 默认关闭：思考 token 会占用输出额度，容易导致长正文被截断。
  bool thinking;

  LlmSettings({
    this.provider = 'deepseek',
    this.baseUrl = 'https://api.deepseek.com',
    this.apiKey = '',
    this.model = 'deepseek-flash',
    this.temperature = 0.9,
    this.maxTokens = 8192,
    this.thinking = false,
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
        'thinking': thinking,
      };

  factory LlmSettings.fromJson(Map<String, dynamic> json) => LlmSettings(
        provider: json['provider'] as String? ?? 'deepseek',
        baseUrl: json['baseUrl'] as String? ?? 'https://api.deepseek.com',
        apiKey: json['apiKey'] as String? ?? '',
        model: json['model'] as String? ?? 'deepseek-flash',
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.9,
        maxTokens: (json['maxTokens'] as num?)?.toInt() ?? 8192,
        thinking: json['thinking'] as bool? ?? false,
      );

  LlmSettings copyWith({
    String? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
    double? temperature,
    int? maxTokens,
    bool? thinking,
  }) =>
      LlmSettings(
        provider: provider ?? this.provider,
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
        temperature: temperature ?? this.temperature,
        maxTokens: maxTokens ?? this.maxTokens,
        thinking: thinking ?? this.thinking,
      );

  /// 各服务商的默认值，供设置页快速切换。
  static const Map<String, Map<String, String>> presets = {
    'deepseek': {
      'baseUrl': 'https://api.deepseek.com',
      'model': 'deepseek-flash',
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