import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../db/database_helper.dart';
import '../main.dart';
import 'settings_notifier.dart';
import '../services/export_service.dart';

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

  Future<void> _backupDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final dbPath = p.join(databasesPath, 'famfinplan.db');
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) throw Exception("Database tidak ditemukan");

      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(appDir.path, 'backups'));
      if (!await backupDir.exists()) await backupDir.create(recursive: true);

      final backupPath = p.join(
        backupDir.path,
        'famfinplan_backup_${DateTime.now().millisecondsSinceEpoch}.db',
      );

      await dbFile.copy(backupPath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("backup_success") + ": $backupPath")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("backup_failed") + ": $e")),
      );
    }
  }

  Future<void> _restoreDatabase() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(appDir.path, 'backups'));
      if (!await backupDir.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr("restore_failed") + ": Folder backup tidak ada")),
        );
        return;
      }

      final files = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.db'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));

      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr("restore_failed") + ": Tidak ada file backup")),
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

      final success = await DatabaseHelper.instance.restoreDatabase(fileToRestore.path);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${tr("restore_success")}: ${p.basename(fileToRestore.path)}"),
          ),
        );
        FamFinPlan.restartApp(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr("restore_failed"))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("restore_failed") + ": $e")),
      );
    }
  }

  Future<void> _resetDatabase() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr("type_reset_to_confirm")),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: tr("type_reset_here")),
        ),
        actions: [
          TextButton(
            child: Text(tr("cancel")),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr("confirm")),
            onPressed: () {
              if (controller.text.trim().toUpperCase() == "RESET") {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr("reset_not_confirmed"))),
                );
              }
            },
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _backupDatabase();
    await DatabaseHelper.instance.resetDatabase();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr("database_reset_success"))),
    );
  }

  Future<void> _deleteSingleBackup() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(appDir.path, 'backups'));

      if (!await backupDir.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr("no_backups_found"))),
        );
        return;
      }

      final files = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.db'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));

      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr("no_backups_found"))),
        );
        return;
      }

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
        SnackBar(content: Text(tr("delete_failed") + ": $e")),
      );
    }
  }

  Future<void> _shareDatabase() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.share, color: Colors.blue),
            title: Text(tr("share_database")),
            onTap: () async {
              Navigator.pop(context);
              try {
                final databasesPath = await getDatabasesPath();
                final dbPath = p.join(databasesPath, 'famfinplan.db');
                final dbFile = File(dbPath);

                if (!await dbFile.exists()) throw Exception("Database tidak ditemukan");

                await ExportService.shareFile(dbFile.path, text: tr("share_database"));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("${tr("share_failed")}: $e")),
                );
              }
            },
          ),
        ],
      ),
    );
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
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Currency Setting
            _buildCard(
              tr("currency"),
              Icons.attach_money,
              DropdownButtonFormField<String>(
                value: selectedCurrency,
                items: currencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) => setState(() => selectedCurrency = value!),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ),

            // Language Setting
            _buildCard(
              tr("language"),
              Icons.language,
              DropdownButtonFormField<String>(
                value: selectedLanguage,
                items: languagesMap.keys
                    .map((lang) => DropdownMenuItem(value: lang, child: Text(lang)))
                    .toList(),
                onChanged: (value) => setState(() => selectedLanguage = value!),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ),

            // Database Actions
            _buildCard(
              tr("database_actions"),
              Icons.storage,
              Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.save, color: Colors.blue),
                    title: Text(tr("backup_database")),
                    onTap: _backupDatabase,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    tileColor: Colors.blue[50],
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.restore, color: Colors.orange),
                    title: Text(tr("restore_database")),
                    onTap: _restoreDatabase,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    tileColor: Colors.orange[50],
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.share, color: Colors.blueAccent),
                    title: Text(tr("share_database")),
                    onTap: _shareDatabase,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    tileColor: Colors.blue[50],
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: Colors.red),
                    title: Text(tr("reset_database")),
                    onTap: _resetDatabase,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    tileColor: Colors.red[50],
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.purple),
                    title: Text(tr("delete_backup_file")),
                    onTap: _deleteSingleBackup,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    tileColor: Colors.purple[50],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save),
                      label: Text(tr("save")),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
