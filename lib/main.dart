import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Import DashboardScreen
import 'screens/dashboard.dart';
import 'screens/settings_screen.dart'; // pastikan import ini

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Inisialisasi timezone untuk notifikasi
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('id')],
      path: 'assets/translations', // folder JSON terjemahan
      fallbackLocale: const Locale('en'),
      child: const FamFinPlan(),
    ),
  );
}

class FamFinPlan extends StatefulWidget {
  const FamFinPlan({super.key});

  // Static method supaya bisa dipanggil dari SettingsScreen
  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_FamFinPlanState>()?.restartApp();
  }

  @override
  State<FamFinPlan> createState() => _FamFinPlanState();
}

class _FamFinPlanState extends State<FamFinPlan> {
  Key key = UniqueKey();

  // Method untuk rebuild seluruh app
  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: key,
      title: 'FamFinPlan',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const DashboardScreen(),
    );
  }
}
