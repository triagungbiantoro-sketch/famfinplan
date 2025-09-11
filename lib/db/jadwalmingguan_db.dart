import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class JadwalMingguanDB {
  static final JadwalMingguanDB instance = JadwalMingguanDB._init();
  static Database? _database;

  JadwalMingguanDB._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('jadwal_mingguan.db');
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
      CREATE TABLE jadwal_mingguan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hari TEXT NOT NULL,
        waktu TEXT NOT NULL,
        kegiatan TEXT NOT NULL,
        status INTEGER NOT NULL
      )
    ''');
  }

  Future<int> insertJadwal(Map<String, dynamic> jadwal) async {
    final db = await instance.database;
    return await db.insert('jadwal_mingguan', jadwal);
  }

  Future<List<Map<String, dynamic>>> getJadwalByHari(String hari) async {
    final db = await instance.database;
    return await db.query(
      'jadwal_mingguan',
      where: 'hari = ?',
      whereArgs: [hari],
      orderBy: 'waktu ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllJadwal() async {
    final db = await instance.database;
    return await db.query('jadwal_mingguan', orderBy: 'hari ASC, waktu ASC');
  }

  Future<int> updateJadwal(int id, Map<String, dynamic> jadwal) async {
    final db = await instance.database;
    return await db.update(
      'jadwal_mingguan',
      jadwal,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteJadwal(int id) async {
    final db = await instance.database;
    return await db.delete(
      'jadwal_mingguan',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

    Future<void> resetDatabase() async {
    final db = await instance.database;
    await db.execute('DROP TABLE IF EXISTS jadwal_mingguan');
    await _createDB(db, 1); // versi saat ini
  }


  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
