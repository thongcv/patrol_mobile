import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'config/google_maps_config.dart';
import 'l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'navigation/patrol_session.dart';
import 'screens/location_gate_screen.dart';
import 'services/account_session_store.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Google Maps API key: AndroidManifest (Gradle) + iOS AppDelegate/Info.plist.
  assert(() {
    if (!GoogleMapsConfig.isConfigured) {
      debugPrint(
        'Google Maps: chưa có GOOGLE_MAPS_API_KEY (--dart-define).',
      );
    }
    return true;
  }());
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.instance.onTokenRefresh.listen(
      AccountSessionStore.instance.cacheDevicePushToken,
    );
    await FirebaseMessaging.instance.requestPermission();
  } catch (e, st) {
    debugPrint('Firebase init: $e\n$st');
  }
  await AccountSessionStore.instance.loadFromPrefs();
  runApp(const PatrolMobileApp());
}

class PatrolMobileApp extends StatefulWidget {
  const PatrolMobileApp({super.key});

  @override
  State<PatrolMobileApp> createState() => _PatrolMobileAppState();
}

class _PatrolMobileAppState extends State<PatrolMobileApp> {
  Locale _locale = const Locale('vi');
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    PatrolSession.attach(
      navigatorKey: _navigatorKey,
      currentLocale: () => _locale,
      onLocaleChanged: (Locale l) => setState(() => _locale = l),
    );
  }

  @override
  void dispose() {
    PatrolSession.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFF2563EB),
        surface: const Color(0xFF0F172A),
      ),
    );

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'SPS Patrol',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: baseTheme.copyWith(
        textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: LocationGateScreen(
        locale: _locale,
        onLocaleChanged: (Locale l) => setState(() => _locale = l),
      ),
    );
  }
}
