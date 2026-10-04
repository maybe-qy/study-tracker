/// 选择题 / 事件选项。
class Choice {
  final String label; // A/B/C/D
  final String description; // 行动描述
  final String dimension; // 维度标签

  const Choice({
    required this.label,
    required this.description,
    this.dimension = '',
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'description': description,
        'dimension': dimension,
      };

  factory Choice.fromJson(Map<String, dynamic> json) => Choice(
        label: json['label'] as String? ?? '',
        description: json['description'] as String? ?? '',
        dimension: json['dimension'] as String? ?? '',
      );
}

/// 随机事件。
class RandomEvent {
  final String type; // 宏观波动 / 个人意外 / 内心危机
  final String title;
  final String description;
  final List<Choice> choices;
  bool triggered;
  final int monthsSinceLast; // 距上次随机事件月数

  RandomEvent({
    required this.type,
    required this.title,
    required this.description,
    this.choices = const <Choice>[],
    this.triggered = false,
    this.monthsSinceLast = 0,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'description': description,
        'choices': choices.map((e) => e.toJson()).toList(),
        'triggered': triggered,
        'monthsSinceLast': monthsSinceLast,
      };

  factory RandomEvent.fromJson(Map<String, dynamic> json) => RandomEvent(
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        choices: (json['choices'] as List<dynamic>? ?? [])
            .map((e) => Choice.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        triggered: json['triggered'] as bool? ?? false,
        monthsSinceLast: (json['monthsSinceLast'] as num?)?.toInt() ?? 0,
      );
}