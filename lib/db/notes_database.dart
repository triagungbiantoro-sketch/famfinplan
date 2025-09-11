import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class NotesDatabase {
  NotesDatabase._privateConstructor();
  static final NotesDatabase instance = NotesDatabase._privateConstructor();

  static Database? _database;

  Future<Database> get database async => _database ??= await _initDatabase();

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'notes.db');
    return await openDatabase(
      path,
      version: 3, // versi baru
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        content TEXT,
        date TEXT,
        alarmDate TEXT,
        imagePath TEXT
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE notes ADD COLUMN alarmDate TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE notes ADD COLUMN imagePath TEXT');
    }
  }

  // Insert new note
  Future<int> insertNote(Map<String, dynamic> note) async {
    Database db = await instance.database;
    return await db.insert('notes', note);
  }

  // Get all notes ordered by date DESC
  Future<List<Map<String, dynamic>>> getAllNotes() async {
    Database db = await instance.database;
    return await db.query('notes', orderBy: 'date DESC');
  }

  // Update a note
  Future<int> updateNote(Map<String, dynamic> note) async {
    Database db = await instance.database;
    return await db.update(
      'notes',
      note,
      where: 'id = ?',
      whereArgs: [note['id']],
    );
  }

  // Delete a note
  Future<int> deleteNote(int id) async {
    Database db = await instance.database;
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Optional: Get a single note by ID
  Future<Map<String, dynamic>?> getNoteById(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> results =
        await db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (results.isNotEmpty) return results.first;
    return null;
  }

  // Optional: Delete all notes
  Future<int> deleteAllNotes() async {
    Database db = await instance.database;
    return await db.delete('notes');
  }

    Future<void> resetDatabase() async {
    final db = await instance.database;
    await db.execute('DROP TABLE IF EXISTS notes');
    await _onCreate(db, 3); // versi saat ini
  }

}
