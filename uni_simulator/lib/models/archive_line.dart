/// 存档行（ARCHIVE）。同时作为 SQLite 中 archives 表的映射对象。
class ArchiveLine {
  int? id;
  final String yearMonth; // Y2028M9
  final int year;
  final int month;
  final int age;
  final String location;
  final String identity;
  final int savings;
  final String health;
  final String skills;
  final String risks;
  final int visionScore;
  final String lastEventMonth;
  final String narrative; // 该月叙事全文（SQLite 存储）
  final String rawOutput; // LLM 原始输出

  ArchiveLine({
    this.id,
    required this.yearMonth,
    required this.year,
    required this.month,
    required this.age,
    this.location = '',
    this.identity = '',
    this.savings = 0,
    this.health = '',
    this.skills = '',
    this.risks = '',
    this.visionScore = 3,
    this.lastEventMonth = '',
    this.narrative = '',
    this.rawOutput = '',
  });

  /// HTML 注释格式的 ARCHIVE 行（与提示词输出格式一致）。
  String toCommentLine() =>
      '<!-- ARCHIVE: $yearMonth | $location | $identity | $savings | $health | '
      '$skills | $risks | $visionScore星 | $lastEventMonth -->';

  Map<String, dynamic> toDbMap() => {
        if (id != null) 'id': id,
        'year_month': yearMonth,
        'year': year,
        'month': month,
        'age': age,
        'location': location,
        'identity': identity,
        'savings': savings,
        'health': health,
        'skills': skills,
        'risks': risks,
        'vision_score': visionScore,
        'last_event_month': lastEventMonth,
        'narrative': narrative,
        'raw_output': rawOutput,
      };

  factory ArchiveLine.fromDbMap(Map<String, dynamic> map) => ArchiveLine(
        id: map['id'] as int?,
        yearMonth: map['year_month'] as String? ?? '',
        year: (map['year'] as num?)?.toInt() ?? 0,
        month: (map['month'] as num?)?.toInt() ?? 0,
        age: (map['age'] as num?)?.toInt() ?? 0,
        location: map['location'] as String? ?? '',
        identity: map['identity'] as String? ?? '',
        savings: (map['savings'] as num?)?.toInt() ?? 0,
        health: map['health'] as String? ?? '',
        skills: map['skills'] as String? ?? '',
        risks: map['risks'] as String? ?? '',
        visionScore: (map['vision_score'] as num?)?.toInt() ?? 3,
        lastEventMonth: map['last_event_month'] as String? ?? '',
        narrative: map['narrative'] as String? ?? '',
        rawOutput: map['raw_output'] as String? ?? '',
      );
}