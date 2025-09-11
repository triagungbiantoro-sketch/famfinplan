import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// Model Event
class Event {
  int? id;
  String title;
  String description;
  String category; // misal: Finance, Personal, Health
  DateTime eventDate;
  int priority; // 1 = rendah, 2 = sedang, 3 = tinggi
  bool isCompleted; // untuk menandai sudah selesai atau belum
  int reminderMinutes; // menit sebelum event untuk reminder, 0 = no reminder

  Event({
    this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.eventDate,
    this.priority = 2,
    this.isCompleted = false,
    this.reminderMinutes = 0,
  });

  // Convert Event ke Map untuk database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'eventDate': eventDate.toIso8601String(),
      'priority': priority,
      'isCompleted': isCompleted ? 1 : 0,
      'reminderMinutes': reminderMinutes,
    };
  }

  // Convert Map dari database ke Event
  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      eventDate: DateTime.tryParse(map['eventDate'] ?? '') ?? DateTime.now(),
      priority: map['priority'] ?? 2,
      isCompleted: map['isCompleted'] == 1,
      reminderMinutes: map['reminderMinutes'] ?? 0,
    );
  }
}

// Database Helper
class EventDatabase {
  static final EventDatabase instance = EventDatabase._init();
  static Database? _database;

  EventDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('event.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // versi baru karena ada perubahan schema
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT,
        eventDate TEXT NOT NULL,
        priority INTEGER,
        isCompleted INTEGER,
        reminderMinutes INTEGER DEFAULT 0
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE events ADD COLUMN reminderMinutes INTEGER DEFAULT 0
      ''');
    }
  }

  // CRUD OPERATIONS
  Future<int> createEvent(Event event) async {
    final db = await instance.database;
    return await db.insert('events', event.toMap());
  }

  Future<List<Event>> getAllEvents() async {
    final db = await instance.database;
    final result = await db.query('events', orderBy: 'eventDate ASC');
    return result.map((map) => Event.fromMap(map)).toList();
  }

  Future<int> updateEvent(Event event) async {
    final db = await instance.database;
    return await db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<int> deleteEvent(int id) async {
    final db = await instance.database;
    return await db.delete(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

    Future<void> resetDatabase() async {
    final db = await instance.database;
    await db.execute('DROP TABLE IF EXISTS events');
    await _createDB(db, 2); // versi sesuai schema saat ini
  }


  Future close() async {
    final db = await instance.database;
    await db.close();
  }
}
