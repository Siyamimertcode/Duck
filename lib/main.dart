import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show PlatformDispatcher;
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/select_level_screen.dart';
import 'screens/placement_test_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/app_state.dart';
import 'services/sound_service.dart';
import 'services/duck_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter framework error: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught platform error: $error');
    debugPrint('$stack');
    return true;
  };

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFFCFCFB),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize app state (theme, locale, vibration, notifications)
  try {
    await AppState.instance.init();
  } catch (e) {
    debugPrint('AppState init error: $e');
  }

  // Initialize sound effects service
  try {
    await SoundService().init();
  } catch (e) {
    debugPrint('SoundService init error: $e');
  }

  // Initialize notifications
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();
    if (AppState.instance.notificationsEnabled) {
      await notificationService.requestPermission();
      await notificationService.scheduleDaily();
    }
  } catch (e) {
    debugPrint('NotificationService init error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    setState(() {}); // Rebuild MaterialApp when theme/locale changes
  }

  @override
  Widget build(BuildContext context) {
    // Update system UI overlay based on theme
    final isDark = AppState.instance.isDark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark
            ? const Color(0xFF0D1B16)
            : const Color(0xFFFCFCFB),
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Duck - Learn English',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', ''), Locale('tr', 'TR')],
      theme: DuckTheme.light,
      darkTheme: DuckTheme.dark,
      themeMode: AppState.instance.themeMode,
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/onboarding':
            return MaterialPageRoute(builder: (_) => const OnboardingScreen());
          case '/select-level':
            return MaterialPageRoute(builder: (_) => const SelectLevelScreen());
          case '/level-test':
            return MaterialPageRoute(
              builder: (_) => const PlacementTestScreen(),
            );
          case '/home':
            // Accept both string (from splash) and map (from select-level)
            final args = settings.arguments;
            String userName = 'Kullanıcı';

            if (args is String) {
              userName = args;
            } else if (args is Map<String, dynamic>) {
              userName = args['userName'] as String? ?? 'Kullanıcı';
            }

            return MaterialPageRoute(
              builder: (_) => HomeScreen(userName: userName),
            );
          default:
            return MaterialPageRoute(builder: (_) => const SplashScreen());
        }
      },
    );
  }
}
