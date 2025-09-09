import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsNotifier {
  SettingsNotifier._privateConstructor();
  static final SettingsNotifier instance = SettingsNotifier._privateConstructor();

  /// Currency global
  ValueNotifier<String> currentCurrency = ValueNotifier("IDR (Rp)");

  /// Language global
  ValueNotifier<String> currentLanguage = ValueNotifier("Indonesia");

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    currentCurrency.value = prefs.getString("currency") ?? "IDR (Rp)";
    currentLanguage.value = prefs.getString("language") ?? "Indonesia";
  }

  Future<void> saveSettings(String currency, String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("currency", currency);
    await prefs.setString("language", language);

    currentCurrency.value = currency;
    currentLanguage.value = language;
  }
}
