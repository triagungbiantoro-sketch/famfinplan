import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../db/database_helper.dart';
import '../main.dart';
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

    // Ganti bahasa
    if (languagesMap.containsKey(selectedLanguage)) {
      await context.setLocale(languagesMap[selectedLanguage]!);
      FamFinPlan.restartApp(context);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr("settings_saved"))),
    );
  }

  Future<void> _resetDatabase() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr("type_reset_to_confirm")),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: tr("type_reset_here"),
          ),
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

    final backupPath = await DatabaseHelper.instance.backupDatabase();
    if (!mounted) return;

    if (backupPath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("backup_success") + ": $backupPath")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("backup_failed"))),
      );
    }

    await DatabaseHelper.instance.resetDatabase();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr("database_reset_success"))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr("settings")),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr("currency"),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedCurrency,
              items: currencies
                  .map((currency) => DropdownMenuItem(
                        value: currency,
                        child: Text(currency),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedCurrency = value!;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              tr("language"),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedLanguage,
              items: languagesMap.keys
                  .map((lang) => DropdownMenuItem(
                        value: lang,
                        child: Text(lang),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedLanguage = value!;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save),
                    label: Text(tr("save")),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _resetDatabase,
                    icon: const Icon(
                      Icons.delete_forever,
                      color: Colors.white,
                    ),
                    label: Text(
                      tr("reset_database"),
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
