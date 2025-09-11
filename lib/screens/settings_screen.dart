import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import 'settings_notifier.dart';

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

  final ScrollController _scrollController = ScrollController();

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
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr("settings_saved"))),
    );
  }

  Future<String> _getDatabasePath(String dbName) async {
    if (dbName == 'notes.db') {
      final appDocDir = await getApplicationDocumentsDirectory();
      return p.join(appDocDir.path, dbName);
    } else {
      final databasesPath = await getDatabasesPath();
      return p.join(databasesPath, dbName);
    }
  }

  Future<String?> _createBackupZip() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(appDir.path, 'backups'));
      if (!await backupDir.exists()) await backupDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final zipFileName = 'all_databases_backup_$timestamp.zip';
      final zipFilePath = p.join(backupDir.path, zipFileName);

      final encoder = ZipFileEncoder();
      encoder.create(zipFilePath);

      final dbFiles = ['famfinplan.db', 'notes.db'];

      for (var dbName in dbFiles) {
        final dbPath = await _getDatabasePath(dbName);
        final dbFile = File(dbPath);
        if (await dbFile.exists()) {
          encoder.addFile(dbFile);
        }
      }

      encoder.close();
      return zipFilePath;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${tr("backup_failed")}: $e")),
      );
      return null;
    }
  }

  Future<void> _backupAllDatabases() async {
    final zipPath = await _createBackupZip();
    if (zipPath != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${tr("backup_success")}: Semua database dibackup di $zipPath")),
      );
    }
  }

  Future<void> _shareDatabase() async {
    final zipPath = await _createBackupZip();
    if (zipPath == null) return;

    try {
      await Share.shareXFiles([XFile(zipPath)], text: tr("share_database_text"));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${tr("share_failed")}: $e")),
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onPressed,
    Color color = Colors.green,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(
            icon: Icon(icon),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: color,
            ),
            onPressed: onPressed,
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
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
        key: const PageStorageKey('settings_screen_list'),
        controller: _scrollController,
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
              onChanged: (value) async {
                setState(() => selectedLanguage = value!);
                await EasyLocalization.of(context)!.setLocale(languagesMap[value]!);
              },
            ),
          ),
          // Database Actions as ExpansionTile
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ExpansionTile(
              leading: const Icon(Icons.storage, color: Colors.green),
              title: Text(tr("database_actions"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    children: [
                      _buildActionButton(
                        icon: Icons.save,
                        label: tr("backup_all_databases"),
                        description: tr("backup_all_databases_desc"),
                        onPressed: _backupAllDatabases,
                      ),
                      _buildActionButton(
                        icon: Icons.restore_page,
                        label: tr("restore_from_zip"),
                        description: tr("restore_from_zip_desc"),
                        onPressed: _restoreFromZip,
                      ),
                      _buildActionButton(
                        icon: Icons.share,
                        label: tr("share_database"),
                        description: tr("share_database_desc"),
                        onPressed: _shareDatabase,
                      ),
                      _buildActionButton(
                        icon: Icons.delete_forever,
                        label: tr("reset_database"),
                        description: tr("reset_database_desc"),
                        color: Colors.red,
                        onPressed: () async {
                          final controller = TextEditingController();
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(tr("confirm_reset_database")),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(tr("type_reset_to_confirm")),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: controller,
                                    decoration: InputDecoration(
                                      hintText: "RESET",
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: Text(tr("cancel")),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () {
                                    if (controller.text.trim().toUpperCase() == "RESET") {
                                      Navigator.of(ctx).pop(true);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(tr("wrong_confirmation_text"))),
                                      );
                                    }
                                  },
                                  child: Text(tr("confirm")),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await DatabaseHelper.instance.resetDatabase();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(tr("database_reset_success"))),
                            );
                          }
                        },
                      ),
                    ],
                  ),
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
