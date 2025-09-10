import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Import screens
import 'screens/dashboard.dart';
import 'screens/settings_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Inisialisasi timezone
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

  // Inisialisasi notifikasi
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const InitializationSettings initSettings =
      InitializationSettings(android: androidInit, iOS: iosInit);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    // Optional: handle klik notifikasi
    onDidReceiveNotificationResponse: (details) {
      // Bisa ditambahkan logic buka halaman tertentu
      print('Notification clicked: ${details.payload}');
    },
  );

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
