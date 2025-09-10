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
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        content TEXT,
        date TEXT
      )
    ''');
  }

  // CRUD operations
  Future<int> insertNote(Map<String, dynamic> note) async {
    Database db = await instance.database;
    return await db.insert('notes', note);
  }

  Future<List<Map<String, dynamic>>> getAllNotes() async {
    Database db = await instance.database;
    return await db.query('notes', orderBy: 'date DESC');
  }

  Future<int> updateNote(Map<String, dynamic> note) async {
    Database db = await instance.database;
    return await db.update('notes', note, where: 'id = ?', whereArgs: [note['id']]);
  }

  Future<int> deleteNote(int id) async {
    Database db = await instance.database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
}
