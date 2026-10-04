import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/archive_line.dart';

/// 存档服务（SQLite）：按月存储 ARCHIVE 行与叙事全文。
class ArchiveService {
  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'uni_simulator.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE archives (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            year_month TEXT NOT NULL,
            year INTEGER NOT NULL,
            month INTEGER NOT NULL,
            age INTEGER NOT NULL,
            location TEXT,
            identity TEXT,
            savings INTEGER,
            health TEXT,
            skills TEXT,
            risks TEXT,
            vision_score INTEGER,
            last_event_month TEXT,
            narrative TEXT,
            raw_output TEXT
          )
        ''');
        await db.execute(
            'CREATE UNIQUE INDEX idx_year_month ON archives(year_month)');
      },
    );
    return _db!;
  }

  Future<int> insert(ArchiveLine line) async {
    final db = await _open();
    return db.insert(
      'archives',
      line.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ArchiveLine>> all() async {
    final db = await _open();
    final rows = await db.query('archives', orderBy: 'year ASC, month ASC');
    return rows.map(ArchiveLine.fromDbMap).toList();
  }

  Future<List<ArchiveLine>> byYear(int year) async {
    final db = await _open();
    final rows = await db.query('archives',
        where: 'year = ?', whereArgs: [year], orderBy: 'month ASC');
    return rows.map(ArchiveLine.fromDbMap).toList();
  }

  Future<void> deleteFrom(int year, int month) async {
    final db = await _open();
    await db.delete('archives',
        where: 'year > ? OR (year = ? AND month >= ?)',
        whereArgs: [year, year, month]);
  }

  Future<void> deleteAll() async {
    final db = await _open();
    await db.delete('archives');
  }

  /// 导出为 Markdown，便于归档与分享。
  Future<String> exportMarkdown() async {
    final lines = await all();
    final buffer = StringBuffer('# 大学模拟器 · 人生档案\n\n');
    for (final line in lines) {
      buffer.writeln('## ${line.year}年${line.month}月 · ${line.age}岁');
      buffer.writeln();
      buffer.writeln(
          '${line.location} | ${line.identity} | 积蓄 ${line.savings} | ${line.health}');
      buffer.writeln('长期愿景契合度：${line.visionScore}星');
      if (line.risks.isNotEmpty) {
        buffer.writeln('潜在风险：${line.risks}');
      }
      buffer.writeln();
      buffer.writeln(line.narrative);
      buffer.writeln();
      buffer.writeln(line.toCommentLine());
      buffer.writeln('\n---\n');
    }
    return buffer.toString();
  }
}