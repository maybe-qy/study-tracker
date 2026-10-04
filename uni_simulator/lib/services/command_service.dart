/// 用户命令解析。
enum GameCommandType {
  restart,
  pause,
  resume,
  edit,
  jump,
  export,
  help,
  unknown,
}

class GameCommand {
  final GameCommandType type;
  final int? year;
  final int? month;
  final String raw;

  const GameCommand({
    required this.type,
    this.year,
    this.month,
    this.raw = '',
  });
}

class CommandService {
  static const String help = '''
可用命令：
  /restart          重新开始（清空档案与存档）
  /pause            暂停推演
  /resume           继续推演
  /edit             打开人物档案编辑
  /jump 2029 3      跳转到指定年月重新推演（截断其后存档）
  /export           导出全部 ARCHIVE 为 Markdown
  /help             查看命令列表
''';

  /// 解析一行命令。支持 `/jump 2029 3`、`/jump 2029-3`、`/jump 2029M3`。
  GameCommand parse(String input) {
    final text = input.trim();
    if (!text.startsWith('/')) {
      return GameCommand(type: GameCommandType.unknown, raw: text);
    }
    final parts = text.split(RegExp(r'\s+'));
    final name = parts.first.toLowerCase();
    final rest = parts.skip(1).toList();

    switch (name) {
      case '/restart':
        return const GameCommand(type: GameCommandType.restart);
      case '/pause':
        return const GameCommand(type: GameCommandType.pause);
      case '/resume':
        return const GameCommand(type: GameCommandType.resume);
      case '/edit':
        return const GameCommand(type: GameCommandType.edit);
      case '/export':
        return const GameCommand(type: GameCommandType.export);
      case '/help':
        return const GameCommand(type: GameCommandType.help);
      case '/jump':
        final joined = rest.join('-');
        final match = RegExp(r'(\d{4})\D+(\d{1,2})').firstMatch(joined);
        if (match == null) {
          return GameCommand(type: GameCommandType.unknown, raw: text);
        }
        final year = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        if (month < 1 || month > 12) {
          return GameCommand(type: GameCommandType.unknown, raw: text);
        }
        return GameCommand(
            type: GameCommandType.jump, year: year, month: month, raw: text);
      default:
        return GameCommand(type: GameCommandType.unknown, raw: text);
    }
  }
}