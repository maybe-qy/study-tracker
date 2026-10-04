import 'dart:math';

import '../models/random_event.dart';

/// 随机事件引擎。计数器为内部状态，不输出到用户界面。
class EventEngine {
  int _monthsSinceLast = 0;
  final int _triggerInterval; // 每 2-3 月触发
  final Random _random;

  EventEngine({int triggerInterval = 2, Random? random})
      : _triggerInterval = triggerInterval,
        _random = random ?? Random();

  int get monthsSinceLast => _monthsSinceLast;

  void restore(int monthsSinceLast) {
    _monthsSinceLast = monthsSinceLast;
  }

  /// 是否触发随机事件。每次调用（即每推进一个月）自增计数。
  bool shouldTrigger() {
    _monthsSinceLast++;
    final due = _monthsSinceLast >= _triggerInterval + _random.nextInt(2);
    if (due) {
      _monthsSinceLast = 0;
      return true;
    }
    return false;
  }

  RandomEvent? maybeGenerate(String phase) {
    if (!shouldTrigger()) return null;
    return generateEvent(phase);
  }

  RandomEvent generateEvent(String phase) {
    final pool = _getEventPool(phase);
    final event = pool[_random.nextInt(pool.length)];
    return RandomEvent(
      type: event.type,
      title: event.title,
      description: event.description,
      choices: event.choices,
      triggered: true,
      monthsSinceLast: 0,
    );
  }

  List<RandomEvent> _getEventPool(String phase) {
    if (phase.contains('大一')) return _freshman;
    if (phase.contains('大二')) return _sophomore;
    if (phase.contains('大三')) return _junior;
    if (phase.contains('大四')) return _senior;
    return _freshman;
  }

  static final List<RandomEvent> _freshman = [
    RandomEvent(
      type: '个人意外',
      title: '寝室作息冲突',
      description: '室友通宵打游戏，你连着几天睡不好，白天上课打瞌睡。',
      choices: [
        Choice(label: 'A', description: '当面把话说清楚，一起定寝室作息约定', dimension: '沟通'),
        Choice(label: 'B', description: '买隔音耳塞和眼罩，先自己扛过去', dimension: '自控'),
        Choice(label: 'C', description: '申请换寝室', dimension: '环境'),
        Choice(label: 'D', description: '索性跟着一起熬夜，白天补觉', dimension: '风险'),
      ],
    ),
    RandomEvent(
      type: '内心危机',
      title: '专业是不是选错了',
      description: '第一学期过半，你发现课程和你想象的软件工程不太一样。',
      choices: [
        Choice(label: 'A', description: '找学长和老师聊，了解这个专业真实的成长路径', dimension: '认知'),
        Choice(label: 'B', description: '自学一门感兴趣的技术，用作品验证', dimension: '行动'),
        Choice(label: 'C', description: '先按部就班把绩点稳住，观望一学期', dimension: '稳定'),
        Choice(label: 'D', description: '认真研究转专业的可能性', dimension: '方向'),
      ],
    ),
    RandomEvent(
      type: '宏观波动',
      title: '第一场校赛报名',
      description: '学院发布了程序设计竞赛通知，报名截止就在本周。',
      choices: [
        Choice(label: 'A', description: '立刻报名，拉上两个同学组队', dimension: '竞赛'),
        Choice(label: 'B', description: '一个人报名，先试试单人赛', dimension: '竞赛'),
        Choice(label: 'C', description: '这次不报，专心把课程基础打牢', dimension: '学业'),
        Choice(label: 'D', description: '报名但只当练手，不投入太多', dimension: '试探'),
      ],
    ),
  ];

  static final List<RandomEvent> _sophomore = [
    RandomEvent(
      type: '个人意外',
      title: '比赛队友掉链子',
      description: '离提交还有两周，负责后端的队友说家里有事要退出。',
      choices: [
        Choice(label: 'A', description: '自己顶上，把后端也接过来', dimension: '承压'),
        Choice(label: 'B', description: '紧急招募新队友，重新分工', dimension: '组织'),
        Choice(label: 'C', description: '缩小范围，砍掉一半功能保交付', dimension: '取舍'),
        Choice(label: 'D', description: '放弃这次比赛', dimension: '撤退'),
      ],
    ),
    RandomEvent(
      type: '宏观波动',
      title: '有公司想买你的项目',
      description: '你在创业赛上做的产品，被一家小公司看中，想买断代码。',
      choices: [
        Choice(label: 'A', description: '卖掉，把第一桶金存起来', dimension: '变现'),
        Choice(label: 'B', description: '开源核心代码，换来口碑与曝光', dimension: '作品'),
        Choice(label: 'C', description: '拒绝，继续自己迭代成更完整的产品', dimension: '长期'),
        Choice(label: 'D', description: '谈成合作分成，而不是一次性买断', dimension: '谈判'),
      ],
    ),
  ];

  static final List<RandomEvent> _junior = [
    RandomEvent(
      type: '个人意外',
      title: '实习面试撞车',
      description: '两家公司的终面安排在同一天同一时段。',
      choices: [
        Choice(label: 'A', description: '联系 HR 尽量改期，两边都争取', dimension: '沟通'),
        Choice(label: 'B', description: '选更想去的那家，另一家放弃', dimension: '取舍'),
        Choice(label: 'C', description: '先去一家，结束后立刻赶另一场', dimension: '冒险'),
        Choice(label: 'D', description: '都推掉，等更合适的批次', dimension: '观望'),
      ],
    ),
    RandomEvent(
      type: '内心危机',
      title: '方向收敛的焦虑',
      description: '同学里有人已经拿到大厂意向，你还在产品和技术之间摇摆。',
      choices: [
        Choice(label: 'A', description: '把两条路各做一个小项目，用结果说话', dimension: '验证'),
        Choice(label: 'B', description: '找已在目标岗位的学长学姐深聊一次', dimension: '认知'),
        Choice(label: 'C', description: '先定产品方向，技术作为支撑，立刻补短板', dimension: '方向'),
        Choice(label: 'D', description: '继续两线并行，等实习结果再决定', dimension: '观望'),
      ],
    ),
  ];

  static final List<RandomEvent> _senior = [
    RandomEvent(
      type: '宏观波动',
      title: '转正名额收紧',
      description: '部门传出转正名额减少的消息，同期实习生人心浮动。',
      choices: [
        Choice(label: 'A', description: '主动找主管谈，明确表达留任意愿与价值', dimension: '沟通'),
        Choice(label: 'B', description: '一边争取本部门，一边投递其他公司', dimension: '备份'),
        Choice(label: 'C', description: '把手上的版本做扎实，用交付说话', dimension: '交付'),
        Choice(label: 'D', description: '暂停求职，先专心毕设与考试', dimension: '学业'),
      ],
    ),
    RandomEvent(
      type: '内心危机',
      title: '为什么是这家公司',
      description: '面试官问你：为什么选我们，而不是给得更高的那家？',
      choices: [
        Choice(label: 'A', description: '把选择讲成长期笃定：方向、业务与成长空间', dimension: '叙事'),
        Choice(label: 'B', description: '坦诚说薪资也是重要考量，但更看重成长', dimension: '坦诚'),
        Choice(label: 'C', description: '强调自己在该业务上的已有积累与作品', dimension: '作品'),
        Choice(label: 'D', description: '现场反问面试官，了解更多再作答', dimension: '试探'),
      ],
    ),
  ];
}