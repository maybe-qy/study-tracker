/// 关键时间节点（入学、实习、毕业、入职等）。
class Milestone {
  final String label;
  final String? date; // YYYY-MM 或 YYYY-MM-DD
  final String description;

  const Milestone({
    required this.label,
    this.date,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'date': date,
        'description': description,
      };

  factory Milestone.fromJson(Map<String, dynamic> json) => Milestone(
        label: json['label'] as String? ?? '',
        date: json['date'] as String?,
        description: json['description'] as String? ?? '',
      );

  Milestone copyWith({String? label, String? date, String? description}) =>
      Milestone(
        label: label ?? this.label,
        date: date ?? this.date,
        description: description ?? this.description,
      );
}