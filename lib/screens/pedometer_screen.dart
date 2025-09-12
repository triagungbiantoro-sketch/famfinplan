import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Init AdMob
  MobileAds.instance.initialize();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('id')],
      path: 'assets/langs',
      fallbackLocale: const Locale('en'),
      child: const PedometerApp(),
    ),
  );
}

class PedometerApp extends StatelessWidget {
  const PedometerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const PedometerScreen(),
    );
  }
}

enum PedometerState { stopped, running, paused }

class PedometerScreen extends StatefulWidget {
  const PedometerScreen({super.key});

  @override
  State<PedometerScreen> createState() => _PedometerScreenState();
}

class _PedometerScreenState extends State<PedometerScreen> {
  StreamSubscription<StepCount>? _subscription;
  final ValueNotifier<int> _stepsNotifier = ValueNotifier<int>(0);
  final int _goal = 10000;

  PedometerState _pedometerState = PedometerState.stopped;

  int _totalStepsAtPause = 0;
  int _initialStepCount = 0;
  final List<Map<String, dynamic>> _history = [];

  // App Open Ad
  AppOpenAd? _appOpenAd;
  bool _isShowingAppOpenAd = false;

  // Interstitial Ad
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;

  @override
  void initState() {
    super.initState();
    _requestPermission();
    _loadAppOpenAd();
    _loadInterstitialAd();
  }

  Future<void> _requestPermission() async {
    if (await Permission.activityRecognition.request().isGranted) {
      debugPrint("Activity Recognition permission granted");
    } else {
      debugPrint("Activity Recognition permission denied");
    }
  }

  // ---------------- App Open Ad ----------------
  void _loadAppOpenAd() {
    AppOpenAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/3419835294', // test ad unit
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('App Open Ad loaded');
          _appOpenAd = ad;
          _showAppOpenAd();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Failed to load App Open Ad: $error');
        },
      ),
    );
  }

  void _showAppOpenAd() {
    if (_appOpenAd == null || _isShowingAppOpenAd) return;

    _isShowingAppOpenAd = true;

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isShowingAppOpenAd = false;
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isShowingAppOpenAd = false;
      },
    );

    _appOpenAd!.show();
  }

  // ---------------- Interstitial Ad ----------------
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // test ad unit
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          debugPrint('Interstitial Ad loaded');
        },
        onAdFailedToLoad: (err) {
          debugPrint('Failed to load Interstitial Ad: $err');
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  void _showInterstitialAd(VoidCallback onAdDismissed) {
    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd(); // preload lagi
          onAdDismissed();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _loadInterstitialAd();
          onAdDismissed();
        },
      );

      _interstitialAd!.show();
      _interstitialAd = null;
      _isInterstitialAdReady = false;
    } else {
      onAdDismissed();
    }
  }

  // ---------------- Pedometer logic ----------------
  void _handleButton() {
    switch (_pedometerState) {
      case PedometerState.stopped:
        _startPedometer();
        break;
      case PedometerState.running:
        _pausePedometer();
        break;
      case PedometerState.paused:
        _resumePedometer();
        break;
    }
  }

  void _startPedometer() {
    _subscription = Pedometer.stepCountStream.listen(_onStepCount)
      ..onError(_onStepCountError);
    _initialStepCount = 0;
    _totalStepsAtPause = 0;
    setState(() {
      _pedometerState = PedometerState.running;
    });
  }

  int _pauseCount = 0; // hitung berapa kali pause

  void _pausePedometer() {
    _subscription?.cancel();
    _subscription = null;

    final steps = _stepsNotifier.value;
    if (steps > 0) _saveHistory(steps);

    _totalStepsAtPause = _stepsNotifier.value;
    _initialStepCount = 0;
    setState(() {
      _pedometerState = PedometerState.paused;
    });

    // Tambahkan logika interstitial otomatis
    _pauseCount++;
    if (_pauseCount % 3 == 0) { // setiap 3 kali pause
      _showInterstitialAd(() {
        debugPrint("Interstitial after pause dismissed");
      });
    }
  }

  void _resumePedometer() {
    _subscription = Pedometer.stepCountStream.listen(_onStepCount)
      ..onError(_onStepCountError);
    setState(() {
      _pedometerState = PedometerState.running;
    });
  }

  void _resetSteps() {
    _showInterstitialAd(() {
      _actuallyResetSteps();
    });
  }

  void _actuallyResetSteps() {
    _subscription?.cancel();
    _subscription = null;

    final steps = _stepsNotifier.value;
    if (steps > 0) _saveHistory(steps);

    _totalStepsAtPause = 0;
    _initialStepCount = 0;
    _stepsNotifier.value = 0;
    setState(() {
      _pedometerState = PedometerState.stopped;
    });
  }

  void _onStepCount(StepCount event) {
    if (_initialStepCount == 0) _initialStepCount = event.steps;
    _stepsNotifier.value = event.steps - _initialStepCount + _totalStepsAtPause;
  }

  void _onStepCountError(error) {
    _stepsNotifier.value = 0;
    setState(() {
      _pedometerState = PedometerState.stopped;
    });
    debugPrint('Pedometer Error: $error');
  }

  void _saveHistory(int steps) {
    _history.insert(0, {
      'time': DateTime.now(),
      'steps': steps,
      'calories': (steps * 0.04).toStringAsFixed(1),
      'minutes': (steps / 100).toStringAsFixed(1),
      'distance': (steps * 0.0008).toStringAsFixed(2),
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _stepsNotifier.dispose();
    _appOpenAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  String get _buttonLabel {
    switch (_pedometerState) {
      case PedometerState.stopped:
        return 'start'.tr();
      case PedometerState.running:
        return 'pause'.tr();
      case PedometerState.paused:
        return 'continue'.tr();
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('pedometer'.tr(), style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text(
                        'today_steps'.tr(),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ValueListenableBuilder<int>(
                      valueListenable: _stepsNotifier,
                      builder: (context, steps, child) {
                        double progress = (steps / _goal).clamp(0.0, 1.0);
                        return Center(
                          child: SizedBox(
                            width: 200,
                            height: 200,
                            child: CustomPaint(
                              painter: _GoalCirclePainter(progress),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TweenAnimationBuilder<int>(
                                      tween: IntTween(begin: 0, end: steps),
                                      duration: const Duration(milliseconds: 300),
                                      builder: (context, value, child) {
                                        return Text(
                                          '$value',
                                          style: const TextStyle(
                                              fontSize: 48, fontWeight: FontWeight.bold),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'goal'.tr(args: [_goal.toString()]),
                                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _pedometerState == PedometerState.running ? 'sensor_active'.tr() : 'sensor_off'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: _pedometerState == PedometerState.running ? Colors.green : Colors.red,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _handleButton,
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                          child: Text(_buttonLabel, style: const TextStyle(fontSize: 18)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _resetSteps,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                          child: Text('reset'.tr(), style: const TextStyle(fontSize: 18)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 5,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(Icons.local_fire_department, 'calories'.tr(),
                                '${(_stepsNotifier.value * 0.04).toStringAsFixed(1)} kCal'),
                            _buildStatItem(Icons.timer, 'time'.tr(),
                                '${(_stepsNotifier.value / 100).toStringAsFixed(1)} mnt'),
                            _buildStatItem(Icons.map, 'distance'.tr(),
                                '${(_stepsNotifier.value * 0.0008).toStringAsFixed(2)} km'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('history'.tr(),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 300,
                      child: _history.isEmpty
                          ? Center(child: Text('no_history'.tr()))
                          : ListView.builder(
                              itemCount: _history.length,
                              itemBuilder: (context, index) {
                                final item = _history[index];
                                final time = item['time'] as DateTime;
                                return ListTile(
                                  leading: const Icon(Icons.history),
                                  title: Text('${item['steps']} ${'steps'.tr()}'),
                                  subtitle: Text(
                                      '${'calories'.tr()}: ${item['calories']} kCal | ${'time'.tr()}: ${item['minutes']} mnt | ${'distance'.tr()}: ${item['distance']} km\n${time.day}/${time.month}/${time.year} ${time.hour}:${time.minute.toString().padLeft(2, '0')}'),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 36, color: Colors.blueAccent),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }
}

class _GoalCirclePainter extends CustomPainter {
  final double progress;
  _GoalCirclePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 15.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;

    final backgroundPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final goalLinePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius, backgroundPaint);

    final angle = 2 * 3.1415926535 * progress;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -3.1415926535 / 2,
        angle, false, progressPaint);

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -3.1415926535 / 2,
        2 * 3.1415926535, false, goalLinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
