/// 月度状态快照。
class MonthlyState {
  int year;
  int month;
  int age;
  String location;
  String identity;
  int savings; // 积蓄（元）
  String relationship;
  String health;
  List<String> skills;
  int visionScore; // 1-5 星
  String visionNote;
  List<String> risks;
  String archiveLine; // ARCHIVE 行原文

  MonthlyState({
    required this.year,
    required this.month,
    required this.age,
    this.location = '',
    this.identity = '',
    this.savings = 0,
    this.relationship = '',
    this.health = '',
    List<String>? skills,
    this.visionScore = 3,
    this.visionNote = '',
    List<String>? risks,
    this.archiveLine = '',
  })  : skills = skills ?? <String>[],
        risks = risks ?? <String>[];

  String get yearMonth => 'Y${year}M$month';

  bool get hasHighRisk => risks.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'year': year,
        'month': month,
        'age': age,
        'location': location,
        'identity': identity,
        'savings': savings,
        'relationship': relationship,
        'health': health,
        'skills': skills,
        'visionScore': visionScore,
        'visionNote': visionNote,
        'risks': risks,
        'archiveLine': archiveLine,
      };

  factory MonthlyState.fromJson(Map<String, dynamic> json) => MonthlyState(
        year: (json['year'] as num?)?.toInt() ?? 0,
        month: (json['month'] as num?)?.toInt() ?? 0,
        age: (json['age'] as num?)?.toInt() ?? 0,
        location: json['location'] as String? ?? '',
        identity: json['identity'] as String? ?? '',
        savings: (json['savings'] as num?)?.toInt() ?? 0,
        relationship: json['relationship'] as String? ?? '',
        health: json['health'] as String? ?? '',
        skills: (json['skills'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        visionScore: (json['visionScore'] as num?)?.toInt() ?? 3,
        visionNote: json['visionNote'] as String? ?? '',
        risks: (json['risks'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        archiveLine: json['archiveLine'] as String? ?? '',
      );
}