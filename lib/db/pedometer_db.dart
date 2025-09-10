import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class PedometerDB {
  static final PedometerDB instance = PedometerDB._init();
  static Database? _database;

  PedometerDB._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pedometer.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE steps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT UNIQUE,
        steps INTEGER
      )
    ''');
  }

  /// Simpan langkah per hari
  Future<void> saveSteps(int steps) async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().split("T")[0];

    await db.insert(
      'steps',
      {'date': today, 'steps': steps},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Ambil langkah hari ini
  Future<int> getTodaySteps() async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().split("T")[0];

    final res = await db.query(
      'steps',
      where: 'date = ?',
      whereArgs: [today],
    );

    if (res.isNotEmpty) {
      return res.first['steps'] as int;
    }
    return 0;
  }

  /// Ambil langkah 7 hari terakhir (termasuk hari ini)
  Future<List<int>> getWeeklySteps() async {
    final db = await instance.database;
    final today = DateTime.now();
    final last7days = today.subtract(const Duration(days: 6));

    final res = await db.query(
      'steps',
      where: "date >= ?",
      whereArgs: [last7days.toIso8601String().split("T")[0]],
      orderBy: "date ASC",
    );

    List<int> weekly = [];
    for (int i = 0; i < 7; i++) {
      final day = today.subtract(Duration(days: 6 - i));
      final dateStr = day.toIso8601String().split("T")[0];

      final match = res.firstWhere(
        (row) => row['date'] == dateStr,
        orElse: () => {'steps': 0},
      );

      weekly.add(match['steps'] as int);
    }

    return weekly;
  }

  Future close() async {
    final db = await _database;
    if (db != null) {
      await db.close();
    }
  }
}
