import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'screens/dashboard.dart';
import 'services/notification_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();  
  await EasyLocalization.ensureInitialized();

  // Inisialisasi NotificationService (sudah include timezone)
  await NotificationService.instance.init();

    // ===== Inisialisasi Google Mobile Ads =====
  await MobileAds.instance.initialize();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('id')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const FamFinPlan(),
    ),
  );
}

class FamFinPlan extends StatefulWidget {
  const FamFinPlan({super.key});

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_FamFinPlanState>()?.restartApp();
  }

  @override
  State<FamFinPlan> createState() => _FamFinPlanState();
}

class _FamFinPlanState extends State<FamFinPlan> {
  Key key = UniqueKey();

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
