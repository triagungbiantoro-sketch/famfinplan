import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class IncomeDB {
  static final IncomeDB instance = IncomeDB._init();
  static Database? _database;

  IncomeDB._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB("income.db");
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
    CREATE TABLE income (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      amount REAL NOT NULL,
      category TEXT NOT NULL,
      note TEXT,
      date TEXT NOT NULL
    )
    ''');
  }

  Future<int> insert(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert("income", row);
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    final db = await instance.database;
    return await db.query("income", orderBy: "date DESC");
  }

  Future<int> update(int id, Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.update("income", row, where: "id = ?", whereArgs: [id]);
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete("income", where: "id = ?", whereArgs: [id]);
  }
}
