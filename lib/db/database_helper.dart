import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  ValueNotifier<bool> dataChanged = ValueNotifier(false);

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<String> get databasePath async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'famfinplan.db');
  }

  Future<Database> _initDatabase() async {
    final path = await databasePath;
    return await openDatabase(
      path,
      version: 10, // versi terbaru
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE income (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        category TEXT,
        note TEXT,
        date TEXT NOT NULL,
        imagePath TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE expense (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        category TEXT,
        note TEXT,
        date TEXT NOT NULL,
        imagePath TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE budget (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        totalBudget REAL NOT NULL,
        usedBudget REAL NOT NULL,
        monthYear TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE budget_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        note TEXT,
        monthYear TEXT NOT NULL,
        date TEXT NOT NULL,
        realized INTEGER DEFAULT 0,
        notify_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE vehicles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicleType TEXT NOT NULL,
        plateNumber TEXT NOT NULL,
        taxDate TEXT NOT NULL,
        lastOilKm INTEGER NOT NULL,
        oilUsageMonths INTEGER NOT NULL,
        lastOilChangeDate TEXT,
        nextOilDate TEXT,
        reminderDateTime TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await _addColumnIfNotExists(db, 'budget', 'monthYear', 'TEXT DEFAULT ""');
      await _addColumnIfNotExists(db, 'budget_usage', 'monthYear', 'TEXT DEFAULT ""');
    }
    if (oldVersion < 5) {
      await _addColumnIfNotExists(db, 'budget_usage', 'realized', 'INTEGER DEFAULT 0');
    }
    if (oldVersion < 6) {
      await _addColumnIfNotExists(db, 'budget_usage', 'notify_at', 'TEXT');
    }
    if (oldVersion < 7) {
      await _addColumnIfNotExists(db, 'vehicles', 'lastOilChangeDate', 'TEXT');
    }
    if (oldVersion < 8) {
      await _addColumnIfNotExists(db, 'vehicles', 'nextOilDate', 'TEXT');
    }
    if (oldVersion < 9) {
      await _addColumnIfNotExists(db, 'vehicles', 'reminderDateTime', 'TEXT');
    }
    if (oldVersion < 10) {
      await _addColumnIfNotExists(db, 'income', 'imagePath', 'TEXT');
      await _addColumnIfNotExists(db, 'expense', 'imagePath', 'TEXT');
    }
  }

  Future<void> _addColumnIfNotExists(Database db, String table, String column, String type) async {
    final result = await db.rawQuery('PRAGMA table_info($table)');
    final exists = result.any((col) => col['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  // -------------------- BACKUP --------------------
  Future<String?> backupDatabase() async {
    try {
      final dbPath = await databasePath;
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) return null;

      final backupDir =
          Directory('${(await getApplicationDocumentsDirectory()).path}/backups');
      if (!await backupDir.exists()) await backupDir.create();

      final backupPath =
          join(backupDir.path, 'famfinplan_backup_${DateTime.now().millisecondsSinceEpoch}.db');
      await dbFile.copy(backupPath);
      return backupPath;
    } catch (e) {
      print('Backup gagal: $e');
      return null;
    }
  }

  Future<bool> backupDatabaseTo(String outputPath) async {
    try {
      final dbPath = await databasePath;
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) return false;

      final destFile = File(outputPath);
      await dbFile.copy(destFile.path);
      return true;
    } catch (e) {
      print('Backup gagal: $e');
      return false;
    }
  }

  // -------------------- RESTORE --------------------
  Future<bool> restoreDatabase(String backupPath) async {
    try {
      final path = await databasePath;
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      final backupFile = File(backupPath);
      if (!await backupFile.exists()) return false;

      await backupFile.copy(path);
      await database;
      dataChanged.value = !dataChanged.value;
      return true;
    } catch (e) {
      print('Restore gagal: $e');
      return false;
    }
  }

  // -------------------- RESET --------------------
  Future<void> resetDatabase() async {
    final path = await databasePath;
    await deleteDatabase(path);
    _database = null;
    await database;
    dataChanged.value = !dataChanged.value;
  }

  // -------------------- INCOME --------------------
  Future<int> insertIncome(Map<String, dynamic> row) async {
    final db = await database;
    final id = await db.insert('income', row);
    dataChanged.value = !dataChanged.value;
    return id;
  }

  Future<List<Map<String, dynamic>>> getIncomes() async {
    final db = await database;
    return await db.query('income', orderBy: "date DESC");
  }

  Future<List<Map<String, dynamic>>> getIncomesByMonthYear(int month, int year) async {
    final db = await database;
    final all = await db.query('income', orderBy: "date DESC");
    return all.where((inc) {
      final date = _parseDate(inc['date']);
      return date.month == month && date.year == year;
    }).toList();
  }

  Future<int> updateIncome(int id, Map<String, dynamic> row) async {
    final db = await database;
    final result = await db.update('income', row, where: 'id = ?', whereArgs: [id]);
    dataChanged.value = !dataChanged.value;
    return result;
  }

  Future<int> deleteIncome(int id) async {
    final db = await database;
    final result = await db.delete('income', where: 'id = ?', whereArgs: [id]);
    dataChanged.value = !dataChanged.value;
    return result;
  }

  // -------------------- EXPENSE --------------------
  Future<int> insertExpense(Map<String, dynamic> row) async {
    final db = await database;
    final id = await db.insert('expense', row);
    dataChanged.value = !dataChanged.value;
    return id;
  }

  Future<List<Map<String, dynamic>>> getExpenses() async {
    final db = await database;
    return await db.query('expense', orderBy: "date DESC");
  }

  Future<List<Map<String, dynamic>>> getExpensesByMonthYear(int month, int year) async {
    final db = await database;
    final all = await db.query('expense', orderBy: "date DESC");
    return all.where((exp) {
      final date = _parseDate(exp['date']);
      return date.month == month && date.year == year;
    }).toList();
  }

  Future<int> updateExpense(int id, Map<String, dynamic> row) async {
    final db = await database;
    final result = await db.update('expense', row, where: 'id = ?', whereArgs: [id]);
    dataChanged.value = !dataChanged.value;
    return result;
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    final result = await db.delete('expense', where: 'id = ?', whereArgs: [id]);
    dataChanged.value = !dataChanged.value;
    return result;
  }

  // -------------------- BUDGET --------------------
  Future<Map<String, dynamic>?> getBudget({DateTime? month}) async {
    final db = await database;
    final m = _formatMonth(month ?? DateTime.now());
    final res = await db.query('budget', where: 'monthYear = ?', whereArgs: [m]);
    if (res.isNotEmpty) return res.first;

    final id = await db.insert('budget', {
      'totalBudget': 0,
      'usedBudget': 0,
      'monthYear': m,
    });
    return {'id': id, 'totalBudget': 0.0, 'usedBudget': 0.0, 'monthYear': m};
  }

  Future<List<Map<String, dynamic>>> getAllBudgets() async {
    final db = await database;
    return await db.query('budget', orderBy: 'monthYear DESC');
  }

  Future<int> addBudget(double totalBudget, {DateTime? month}) async {
    final db = await database;
    final m = _formatMonth(month ?? DateTime.now());
    final existing = await getBudget(month: month);
    if (existing != null) {
      return await db.update('budget', {'totalBudget': totalBudget}, where: 'id = ?', whereArgs: [existing['id']]);
    } else {
      return await db.insert('budget', {'totalBudget': totalBudget, 'usedBudget': 0, 'monthYear': m});
    }
  }

  Future<void> setBudget(double totalBudget, {DateTime? month}) async {
    final db = await database;
    final m = _formatMonth(month ?? DateTime.now());
    final existing = await getBudget(month: month);
    if (existing != null) {
      await db.update(
        'budget',
        {'totalBudget': totalBudget, 'usedBudget': 0, 'monthYear': m},
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
    } else {
      await db.insert('budget', {'totalBudget': totalBudget, 'usedBudget': 0, 'monthYear': m});
    }
    await db.delete('budget_usage', where: 'monthYear = ?', whereArgs: [m]);
    dataChanged.value = !dataChanged.value;
  }

  Future<void> updateBudgetTotal(double totalBudget, {DateTime? month}) async {
    final db = await database;
    final existing = await getBudget(month: month);
    if (existing != null) {
      await db.update('budget', {'totalBudget': totalBudget}, where: 'id = ?', whereArgs: [existing['id']]);
      dataChanged.value = !dataChanged.value;
    }
  }

  // -------------------- VEHICLES --------------------
  Future<int> insertVehicle(Map<String, dynamic> row, {DateTime? reminderDateTime}) async {
    final db = await database;
    final safeRow = {
      'vehicleType': row['vehicleType'] ?? '',
      'plateNumber': row['plateNumber'] ?? '',
      'taxDate': row['taxDate'] ?? DateTime.now().toIso8601String(),
      'lastOilKm': row['lastOilKm'] ?? 0,
      'oilUsageMonths': row['oilUsageMonths'] ?? 0,
      'lastOilChangeDate': row['lastOilChangeDate'],
      'nextOilDate': row['nextOilDate'],
      'reminderDateTime': reminderDateTime?.toIso8601String() ?? row['reminderDateTime'],
    };
    final id = await db.insert('vehicles', safeRow);
    dataChanged.value = !dataChanged.value;
    return id;
  }

  Future<List<Map<String, dynamic>>> getVehicles() async {
    final db = await database;
    return await db.query('vehicles', orderBy: "id DESC");
  }

  Future<int> updateVehicle(int id, Map<String, dynamic> row, {DateTime? reminderDateTime}) async {
    final db = await database;
    final safeRow = {
      'vehicleType': row['vehicleType'] ?? '',
      'plateNumber': row['plateNumber'] ?? '',
      'taxDate': row['taxDate'] ?? DateTime.now().toIso8601String(),
      'lastOilKm': row['lastOilKm'] ?? 0,
      'oilUsageMonths': row['oilUsageMonths'] ?? 0,
      'lastOilChangeDate': row['lastOilChangeDate'],
      'nextOilDate': row['nextOilDate'],
      'reminderDateTime': reminderDateTime?.toIso8601String() ?? row['reminderDateTime'],
    };
    final result = await db.update('vehicles', safeRow, where: 'id = ?', whereArgs: [id]);
    dataChanged.value = !dataChanged.value;
    return result;
  }

  Future<int> deleteVehicle(int id) async {
    final db = await database;
    final result = await db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
    dataChanged.value = !dataChanged.value;
    return result;
  }

  // -------------------- BUDGET USAGE --------------------
  Future<List<Map<String, dynamic>>> getBudgetUsage({DateTime? month}) async {
    final db = await database;
    final m = _formatMonth(month ?? DateTime.now());
    return await db.query('budget_usage', where: 'monthYear = ?', whereArgs: [m], orderBy: "date DESC");
  }

  Future<void> addBudgetUsage(double amount, String? note, {DateTime? month, DateTime? notifyAt}) async {
    final db = await database;
    final now = DateTime.now();
    final m = _formatMonth(month ?? now);
    await db.insert('budget_usage', {
      'amount': amount,
      'note': note,
      'monthYear': m,
      'date': now.toIso8601String(),
      'realized': 0,
      'notify_at': notifyAt?.toIso8601String(),
    });

    final budget = await getBudget(month: month);
    if (budget != null) {
      double used = (budget['usedBudget'] ?? 0).toDouble() + amount;
      await db.update('budget', {'usedBudget': used}, where: 'id = ?', whereArgs: [budget['id']]);
    }
    dataChanged.value = !dataChanged.value;
  }

  Future<void> updateBudgetUsage(int id, double newAmount, String? note, {DateTime? month, DateTime? notifyAt}) async {
    final db = await database;
    final old = await db.query('budget_usage', where: 'id = ?', whereArgs: [id]);
    if (old.isEmpty) return;

    final oldAmount = (old.first['amount'] as num).toDouble();
    await db.update('budget_usage', {'amount': newAmount, 'note': note, 'notify_at': notifyAt?.toIso8601String()}, where: 'id = ?', whereArgs: [id]);

    final budget = await getBudget(month: month);
    if (budget != null) {
      double used = (budget['usedBudget'] ?? 0).toDouble() - oldAmount + newAmount;
      await db.update('budget', {'usedBudget': used}, where: 'id = ?', whereArgs: [budget['id']]);
    }
    dataChanged.value = !dataChanged.value;
  }

  Future<void> deleteBudgetUsage(int id, {DateTime? month}) async {
    final db = await database;
    final usage = await db.query('budget_usage', where: 'id = ?', whereArgs: [id]);
    if (usage.isEmpty) return;

    final amount = (usage.first['amount'] as num).toDouble();
    await db.delete('budget_usage', where: 'id = ?', whereArgs: [id]);

    final budget = await getBudget(month: month);
    if (budget != null) {
      double used = (budget['usedBudget'] ?? 0).toDouble() - amount;
      await db.update('budget', {'usedBudget': used}, where: 'id = ?', whereArgs: [budget['id']]);
    }
    dataChanged.value = !dataChanged.value;
  }

  Future<void> updateBudgetUsageRealized(int id, bool realized, {DateTime? month}) async {
    final db = await database;
    await db.update('budget_usage', {'realized': realized ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
    dataChanged.value = !dataChanged.value;
  }

  // -------------------- SUMMARY --------------------
  Future<Map<String, double>> getMonthlySummary(int month, int year) async {
    final incomes = await getIncomesByMonthYear(month, year);
    final expenses = await getExpensesByMonthYear(month, year);

    double totalIncome = 0.0;
    double totalExpense = 0.0;

    for (var inc in incomes) {
      totalIncome += (inc['amount'] as num).toDouble();
    }
    for (var exp in expenses) {
      totalExpense += (exp['amount'] as num).toDouble();
    }

    return {'income': totalIncome, 'expense': totalExpense};
  }

  // -------------------- HELPERS --------------------
  String _formatMonth(DateTime date) => DateFormat('yyyy-MM').format(date);

  DateTime _parseDate(Object? value) {
    if (value == null) throw FormatException("Date value is null");
    return DateTime.parse(value as String);
  }
}
