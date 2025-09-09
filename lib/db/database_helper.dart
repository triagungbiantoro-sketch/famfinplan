import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

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

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'famfinplan.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE income (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        category TEXT,
        note TEXT,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE expense (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        category TEXT,
        note TEXT,
        date TEXT NOT NULL
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
        date TEXT NOT NULL
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
        nextOilDate TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE budget ADD COLUMN monthYear TEXT DEFAULT ""');
      await db.execute('ALTER TABLE budget_usage ADD COLUMN monthYear TEXT DEFAULT ""');
    }
  }

  /// Backup database ke file lain
  Future<String?> backupDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final dbFile = File(join(dbPath, 'famfinplan.db'));
      if (!await dbFile.exists()) return null;

      final backupFile = File(join(
        dbPath,
        'famfinplan_backup_${DateTime.now().millisecondsSinceEpoch}.db',
      ));
      await dbFile.copy(backupFile.path);
      print('Backup sukses di: ${backupFile.path}');
      return backupFile.path;
    } catch (e) {
      print('Backup gagal: $e');
      return null;
    }
  }

  /// Reset database
  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'famfinplan.db');
    await deleteDatabase(path);
    _database = null;
    await database; // recreate database kosong
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

    final id = await db.insert('budget', {'totalBudget': 0, 'usedBudget': 0, 'monthYear': m});
    return {'id': id, 'totalBudget': 0.0, 'usedBudget': 0.0, 'monthYear': m};
  }

  Future<void> setBudget(double totalBudget, {DateTime? month}) async {
    final db = await database;
    final m = _formatMonth(month ?? DateTime.now());
    final existing = await getBudget(month: month);
    if (existing != null) {
      await db.update('budget', {'totalBudget': totalBudget, 'usedBudget': 0, 'monthYear': m},
          where: 'id = ?', whereArgs: [existing['id']]);
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
  Future<int> insertVehicle(Map<String, dynamic> row) async {
    final db = await database;
    final id = await db.insert('vehicles', row);
    dataChanged.value = !dataChanged.value;
    return id;
  }

  Future<List<Map<String, dynamic>>> getVehicles() async {
    final db = await database;
    return await db.query('vehicles', orderBy: "id DESC");
  }

  Future<int> updateVehicle(int id, Map<String, dynamic> row) async {
    final db = await database;
    final result = await db.update('vehicles', row, where: 'id = ?', whereArgs: [id]);
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

  Future<void> addBudgetUsage(double amount, String? note, {DateTime? month}) async {
    final db = await database;
    final now = DateTime.now();
    final m = _formatMonth(month ?? now);
    await db.insert('budget_usage', {'amount': amount, 'note': note, 'monthYear': m, 'date': now.toIso8601String()});

    final budget = await getBudget(month: month);
    if (budget != null) {
      double used = (budget['usedBudget'] ?? 0) + amount;
      await db.update('budget', {'usedBudget': used}, where: 'id = ?', whereArgs: [budget['id']]);
    }
    dataChanged.value = !dataChanged.value;
  }

  Future<void> updateBudgetUsage(int id, double newAmount, String? note, {DateTime? month}) async {
    final db = await database;
    final old = await db.query('budget_usage', where: 'id = ?', whereArgs: [id]);
    if (old.isEmpty) return;

    final oldAmount = old.first['amount'] as double;
    await db.update('budget_usage', {'amount': newAmount, 'note': note}, where: 'id = ?', whereArgs: [id]);

    final budget = await getBudget(month: month);
    if (budget != null) {
      double used = (budget['usedBudget'] ?? 0) - oldAmount + newAmount;
      await db.update('budget', {'usedBudget': used}, where: 'id = ?', whereArgs: [budget['id']]);
    }
    dataChanged.value = !dataChanged.value;
  }

  Future<void> deleteBudgetUsage(int id, {DateTime? month}) async {
    final db = await database;
    final usage = await db.query('budget_usage', where: 'id = ?', whereArgs: [id]);
    if (usage.isEmpty) return;

    final amount = usage.first['amount'] as double;
    await db.delete('budget_usage', where: 'id = ?', whereArgs: [id]);

    final budget = await getBudget(month: month);
    if (budget != null) {
      double used = (budget['usedBudget'] ?? 0) - amount;
      await db.update('budget', {'usedBudget': used}, where: 'id = ?', whereArgs: [budget['id']]);
    }
    dataChanged.value = !dataChanged.value;
  }

  String _formatMonth(DateTime date) => DateFormat('yyyy-MM').format(date);
}
