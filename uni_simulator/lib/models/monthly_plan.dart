import 'random_event.dart';

/// 计划草案中的单个事项。
class PlanItem {
  String label; // A/B/C/D
  String name;
  int weight; // 建议权重（百分比）
  String reason;
  String dimension; // 维度标签

  PlanItem({
    required this.label,
    required this.name,
    this.weight = 0,
    this.reason = '',
    this.dimension = '',
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'name': name,
        'weight': weight,
        'reason': reason,
        'dimension': dimension,
      };

  factory PlanItem.fromJson(Map<String, dynamic> json) => PlanItem(
        label: json['label'] as String? ?? '',
        name: json['name'] as String? ?? '',
        weight: (json['weight'] as num?)?.toInt() ?? 0,
        reason: json['reason'] as String? ?? '',
        dimension: json['dimension'] as String? ?? '',
      );

  PlanItem copyWith({String? label, String? name, int? weight, String? reason, String? dimension}) =>
      PlanItem(
        label: label ?? this.label,
        name: name ?? this.name,
        weight: weight ?? this.weight,
        reason: reason ?? this.reason,
        dimension: dimension ?? this.dimension,
      );
}

/// 下月计划草案。
class MonthlyPlan {
  List<PlanItem> items;
  bool hasRandomEvent;
  RandomEvent? event;

  MonthlyPlan({
    List<PlanItem>? items,
    this.hasRandomEvent = false,
    this.event,
  }) : items = items ?? <PlanItem>[];

  int get totalWeight =>
      items.fold<int>(0, (sum, item) => sum + item.weight);

  void renormalize() {
    // 保留输入顺序，按比例缩放到 100，最后一项吸收舍入误差。
    final total = totalWeight;
    if (items.isEmpty || total == 0) return;
    if (total == 100) return;
    var acc = 0;
    for (var i = 0; i < items.length; i++) {
      if (i == items.length - 1) {
        items[i].weight = (100 - acc).clamp(0, 100);
      } else {
        final w = ((items[i].weight / total) * 100).round();
        items[i].weight = w;
        acc += w;
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'hasRandomEvent': hasRandomEvent,
        'event': event?.toJson(),
      };

  factory MonthlyPlan.fromJson(Map<String, dynamic> json) => MonthlyPlan(
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => PlanItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        hasRandomEvent: json['hasRandomEvent'] as bool? ?? false,
        event: json['event'] == null
            ? null
            : RandomEvent.fromJson(
                Map<String, dynamic>.from(json['event'] as Map)),
      );
}