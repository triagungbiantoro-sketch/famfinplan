import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class KendaraanDB {
  KendaraanDB._();
  static final KendaraanDB instance = KendaraanDB._();

  static Database? _database;

  final String tableName = "vehicles";

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB("kendaraan.db");
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // ⬅️ naikkan versi supaya ALTER TABLE jalan
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vehicleType TEXT,
            plateNumber TEXT,
            taxDate TEXT,
            lastOilKm INTEGER,
            oilUsageMonths INTEGER,
            nextOilDate TEXT,
            lastOilDate TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              "ALTER TABLE $tableName ADD COLUMN lastOilDate TEXT");
        }
      },
    );
  }

  Future<int> insertVehicle(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(tableName, data);
  }

  Future<List<Map<String, dynamic>>> getVehicles() async {
    final db = await database;
    return await db.query(tableName, orderBy: "id DESC");
  }

  Future<int> updateVehicle(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(tableName, data,
        where: "id = ?", whereArgs: [id]);
  }

  Future<int> deleteVehicle(int id) async {
    final db = await database;
    return await db.delete(tableName, where: "id = ?", whereArgs: [id]);
  }
}
