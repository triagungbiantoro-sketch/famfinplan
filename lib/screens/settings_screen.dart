import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import 'settings_notifier.dart';
import '../services/export_service.dart';
import '../db/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String selectedCurrency = "IDR (Rp)";
  String selectedLanguage = "Indonesia";

  final List<String> currencies = [
    "IDR (Rp)",
    "USD (\$)",
    "EUR (€)",
    "JPY (¥)",
  ];

  final Map<String, Locale> languagesMap = {
    "Indonesia": const Locale('id'),
    "English": const Locale('en'),
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await SettingsNotifier.instance.loadSettings();
    setState(() {
      selectedCurrency = SettingsNotifier.instance.currentCurrency.value;
      selectedLanguage = SettingsNotifier.instance.currentLanguage.value;
    });
  }

  Future<void> _saveSettings() async {
    await SettingsNotifier.instance.saveSettings(selectedCurrency, selectedLanguage);

    if (languagesMap.containsKey(selectedLanguage)) {
      await EasyLocalization.of(context)!.setLocale(languagesMap[selectedLanguage]!);
      FamFinPlan.restartApp(context);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr("settings_saved"))),
    );
  }

  /// Ambil path sesuai database
  Future<String> _getDatabasePath(String dbName) async {
    if (dbName == 'notes.db') {
      final appDocDir = await getApplicationDocumentsDirectory();
      return p.join(appDocDir.path, dbName);
    } else {
      final databasesPath = await getDatabasesPath();
      return p.join(databasesPath, dbName);
    }
  }

  Future<void> _backupDatabase(String dbName) async {
    try {
      final dbPath = await _getDatabasePath(dbName);
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) throw Exception("Database tidak ditemukan");

      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(appDir.path, 'backups'));
      if (!await backupDir.exists()) await backupDir.create(recursive: true);

      final backupPath =
          p.join(backupDir.path, '${dbName}_backup_${DateTime.now().millisecondsSinceEpoch}.db');

      await dbFile.copy(backupPath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${tr("backup_success")}: $backupPath")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${tr("backup_failed")}: $e")),
      );
    }
  }

  Future<void> _backupAllDatabases() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(appDir.path, 'backups'));
      if (!await backupDir.exists()) await backupDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final zipFileName = 'all_databases_backup_$timestamp.zip';
      final zipFilePath = p.join(backupDir.path, zipFileName);

      final encoder = ZipFileEncoder();
      encoder.create(zipFilePath);

      final dbFiles = [
        'famfinplan.db',
        'notes.db',
      ];

      for (var dbName in dbFiles) {
        final dbPath = await _getDatabasePath(dbName);
        final dbFile = File(dbPath);
        if (await dbFile.exists()) {
          encoder.addFile(dbFile);
        }
      }

      encoder.close();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${tr("backup_success")}: Semua database dibackup di $zipFilePath")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${tr("backup_failed")}: $e")),
      );
    }
  }

  Future<void> _restoreDatabase(String dbName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(appDir.path, 'backups'));
      if (!await backupDir.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${tr("restore_failed")}: Folder backup tidak ada")),
        );
        return;
      }

      final files = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.db') && p.basename(f.path).startsWith(dbName))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));

      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${tr("restore_failed")}: Tidak ada file backup")),
        );
        return;
      }

      final fileNames = files.map((f) => p.basename(f.path)).toList();
      String? selectedFile = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr("select_backup_to_restore")),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: fileNames.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(fileNames[index]),
                  onTap: () => Navigator.pop(context, fileNames[index]),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: Text(tr("cancel")),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );

      if (selectedFile == null) return;

      final fileToRestore =
          files.firstWhere((f) => p.basename(f.path) == selectedFile);

      bool success = false;
      if (dbName == 'famfinplan.db') {
        success = await DatabaseHelper.instance.restoreDatabase(fileToRestore.path);
      } else if (dbName == 'notes.db') {
        final restorePath = await _getDatabasePath('notes.db');
        final backupFile = File(fileToRestore.path);
        if (await backupFile.exists()) {
          await backupFile.copy(restorePath);
          success = true;
        }
      }

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${tr("restore_success")}: ${p.basename(fileToRestore.path)}")),
        );
        if (dbName == 'famfinplan.db') FamFinPlan.restartApp(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr("restore_failed"))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${tr("restore_failed")}: $e")),
      );
    }
  }

  Future<void> _restoreFromZip() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null) return;

      final zipFile = File(result.files.single.path!);
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        if (file.isFile) {
          final data = file.content as List<int>;
          final dbName = file.name;

          String restorePath;
          if (dbName == 'notes.db') {
            final appDocDir = await getApplicationDocumentsDirectory();
            restorePath = p.join(appDocDir.path, dbName);
          } else {
            final databasesPath = await getDatabasesPath();
            restorePath = p.join(databasesPath, dbName);
          }

          final outFile = File(restorePath);
          await outFile.writeAsBytes(Uint8List.fromList(data), flush: true);
        }
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr("restore_success")),
          content: Text(tr("please_restart_app")),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("OK"),
            ),
            ElevatedButton(
              onPressed: () {
                SystemNavigator.pop();
              },
              child: Text(tr("restart_app")),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${tr("restore_failed")}: $e")),
      );
    }
  }

  Future<void> _deleteBackupFile(String dbName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(appDir.path, 'backups'));
      if (!await backupDir.exists()) return;

      final files = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.db') && p.basename(f.path).startsWith(dbName))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));

      if (files.isEmpty) return;

      final fileNames = files.map((f) => p.basename(f.path)).toList();
      String? selectedFile = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr("select_backup_to_delete")),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: fileNames.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(fileNames[index]),
                  trailing: const Icon(Icons.delete, color: Colors.red),
                  onTap: () => Navigator.pop(context, fileNames[index]),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: Text(tr("cancel")),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );

      if (selectedFile == null) return;

      final fileToDelete =
          files.firstWhere((f) => p.basename(f.path) == selectedFile);
      await fileToDelete.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${tr("delete_success")}: $selectedFile")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${tr("delete_failed")}: $e")),
      );
    }
  }

  Future<void> _shareDatabase(String dbName) async {
    try {
      final dbPath = await _getDatabasePath(dbName);
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) throw Exception("Database tidak ditemukan");

      await ExportService.shareFile(dbFile.path, text: "${tr("share_database")}: $dbName");
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${tr("share_failed")}: $e")),
      );
    }
  }

  Widget _buildCard(String title, IconData icon, Widget child) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: Colors.green),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr("settings")),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Currency
          _buildCard(
            tr("currency"),
            Icons.attach_money,
            DropdownButton<String>(
              value: selectedCurrency,
              isExpanded: true,
              items: currencies.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) => setState(() => selectedCurrency = value!),
            ),
          ),
          // Language
          _buildCard(
            tr("language"),
            Icons.language,
            DropdownButton<String>(
              value: selectedLanguage,
              isExpanded: true,
              items: languagesMap.keys
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (value) => setState(() => selectedLanguage = value!),
            ),
          ),
          // Database Actions
          _buildCard(
            tr("database_actions"),
            Icons.storage,
            ExpansionTile(
              title: Text(tr("database_actions"), style: const TextStyle(fontWeight: FontWeight.bold)),
              leading: const Icon(Icons.storage, color: Colors.green),
              children: [
                ListTile(
                  leading: const Icon(Icons.save, color: Colors.blue),
                  title: Text(tr("backup_famfinplan")),
                  onTap: () => _backupDatabase('famfinplan.db'),
                ),
                ListTile(
                  leading: const Icon(Icons.restore, color: Colors.orange),
                  title: Text(tr("restore_famfinplan")),
                  onTap: () => _restoreDatabase('famfinplan.db'),
                ),
                ListTile(
                  leading: const Icon(Icons.share, color: Colors.blueAccent),
                  title: Text(tr("share_famfinplan")),
                  onTap: () => _shareDatabase('famfinplan.db'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: Text(tr("reset_famfinplan")),
                  onTap: () => _restoreDatabase('famfinplan.db'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.save, color: Colors.blue),
                  title: Text(tr("backup_notes")),
                  onTap: () => _backupDatabase('notes.db'),
                ),
                ListTile(
                  leading: const Icon(Icons.restore, color: Colors.orange),
                  title: Text(tr("restore_notes")),
                  onTap: () => _restoreDatabase('notes.db'),
                ),
                ListTile(
                  leading: const Icon(Icons.share, color: Colors.blueAccent),
                  title: Text(tr("share_notes")),
                  onTap: () => _shareDatabase('notes.db'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: Text(tr("reset_notes")),
                  onTap: () => _restoreDatabase('notes.db'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.save, color: Colors.green),
                  title: Text(tr("backup_all_databases")),
                  onTap: _backupAllDatabases,
                ),
                ListTile(
                  leading: const Icon(Icons.restore_page, color: Colors.teal),
                  title: Text(tr("restore_from_zip")),
                  onTap: _restoreFromZip,
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.purple),
                  title: Text(tr("delete_backup_file")),
                  onTap: () async {
                    final dbOption = await showDialog<String>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: Text(tr("select_database")),
                        children: [
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, 'famfinplan.db'),
                            child: Text(tr("famfinplan_db")),
                          ),
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, 'notes.db'),
                            child: Text(tr("notes_db")),
                          ),
                        ],
                      ),
                    );
                    if (dbOption != null) _deleteBackupFile(dbOption);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveSettings,
            child: Text(tr("save_settings")),
          ),
        ],
      ),
    );
  }
}
