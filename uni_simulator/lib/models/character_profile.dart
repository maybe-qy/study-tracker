import 'milestone.dart';

/// 人物档案。合并了提示词中「人物档案」与「人物画像维护」两处字段。
class CharacterProfile {
  String name;
  String gender;
  DateTime birthDate;
  String hometown; // 家庭所在地
  String university; // 大学所在地 / 学校
  String education;
  String careerStatus; // 当前身份
  String major;
  DateTime enrollmentDate;
  DateTime graduationDate;
  List<String> personality; // 核心性格 ≤5 词
  String longTermVision; // 长期愿景
  List<String> strengths;
  List<String> weaknesses;
  String forbiddenZone; // 底线 / 禁区
  List<String> preferences;
  String riskTolerance;
  List<Milestone> keyNodes;
  List<String> permanentItems; // 永久项

  CharacterProfile({
    required this.name,
    this.gender = '',
    required this.birthDate,
    this.hometown = '',
    this.university = '',
    this.education = '',
    this.careerStatus = '大学在读',
    this.major = '',
    required this.enrollmentDate,
    required this.graduationDate,
    List<String>? personality,
    this.longTermVision = '',
    List<String>? strengths,
    List<String>? weaknesses,
    this.forbiddenZone = '',
    List<String>? preferences,
    this.riskTolerance = '',
    List<Milestone>? keyNodes,
    List<String>? permanentItems,
  })  : personality = personality ?? <String>[],
        strengths = strengths ?? <String>[],
        weaknesses = weaknesses ?? <String>[],
        preferences = preferences ?? <String>[],
        keyNodes = keyNodes ?? <Milestone>[],
        permanentItems = permanentItems ?? <String>['运动锚点', '英语线'];

  /// 示例用的虚拟档案（非真实人物），可在初始化页覆盖。
  factory CharacterProfile.demo() => CharacterProfile(
        name: '林知远',
        gender: '男',
        birthDate: DateTime(2009, 3, 15),
        hometown: '成都',
        university: '江城大学 · 江城',
        education: '本科',
        careerStatus: '大一新生',
        major: '软件工程',
        enrollmentDate: DateTime(2028, 9, 1),
        graduationDate: DateTime(2032, 6, 30),
        personality: ['外冷内热', '直接', '爱较真', '抗压强'],
        longTermVision: 'AI 产品方向 → 技术型产品负责人',
        strengths: ['逻辑缜密', '动手能力强', '善于复盘'],
        weaknesses: ['新环境适应偏慢', '表达偏克制'],
        forbiddenZone: '不碰违法、伤害他人之事',
        preferences: ['写代码', '跑步', '产品复盘'],
        riskTolerance: '中高',
        keyNodes: [
          const Milestone(label: '入学', date: '2028-09', description: '江城大学软件工程'),
          const Milestone(label: '毕业', date: '2032-06', description: '本科毕业'),
          const Milestone(label: '目标', date: '2032-07', description: '进入互联网公司产品岗'),
        ],
        permanentItems: ['运动锚点', '英语线'],
      );

  /// 出生日期到指定年月时的周岁。
  int ageAt(int year, int month) {
    var age = year - birthDate.year;
    if (month < birthDate.month) age--;
    return age;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'gender': gender,
        'birthDate': birthDate.toIso8601String(),
        'hometown': hometown,
        'university': university,
        'education': education,
        'careerStatus': careerStatus,
        'major': major,
        'enrollmentDate': enrollmentDate.toIso8601String(),
        'graduationDate': graduationDate.toIso8601String(),
        'personality': personality,
        'longTermVision': longTermVision,
        'strengths': strengths,
        'weaknesses': weaknesses,
        'forbiddenZone': forbiddenZone,
        'preferences': preferences,
        'riskTolerance': riskTolerance,
        'keyNodes': keyNodes.map((e) => e.toJson()).toList(),
        'permanentItems': permanentItems,
      };

  factory CharacterProfile.fromJson(Map<String, dynamic> json) =>
      CharacterProfile(
        name: json['name'] as String? ?? '未命名',
        gender: json['gender'] as String? ?? '',
        birthDate: DateTime.tryParse(json['birthDate'] as String? ?? '') ??
            DateTime(2009, 3, 15),
        hometown: json['hometown'] as String? ?? '',
        university: json['university'] as String? ?? '',
        education: json['education'] as String? ?? '',
        careerStatus: json['careerStatus'] as String? ?? '',
        major: json['major'] as String? ?? '',
        enrollmentDate:
            DateTime.tryParse(json['enrollmentDate'] as String? ?? '') ??
                DateTime(2028, 9, 1),
        graduationDate:
            DateTime.tryParse(json['graduationDate'] as String? ?? '') ??
                DateTime(2032, 6, 30),
        personality: _strList(json['personality']),
        longTermVision: json['longTermVision'] as String? ?? '',
        strengths: _strList(json['strengths']),
        weaknesses: _strList(json['weaknesses']),
        forbiddenZone: json['forbiddenZone'] as String? ?? '',
        preferences: _strList(json['preferences']),
        riskTolerance: json['riskTolerance'] as String? ?? '',
        keyNodes: (json['keyNodes'] as List<dynamic>? ?? [])
            .map((e) => Milestone.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        permanentItems: _strList(json['permanentItems']),
      );

  static List<String> _strList(dynamic value) =>
      (value as List<dynamic>? ?? []).map((e) => e.toString()).toList();
}