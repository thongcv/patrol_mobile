import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'config/google_maps_config.dart';
import 'l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'navigation/patrol_session.dart';
import 'screens/location_gate_screen.dart';
import 'services/account_session_store.dart';
import 'services/app_locale_store.dart';
import 'services/patrol_background_service.dart';
import 'services/patrol_realtime_track_coordinator.dart';

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
        'Google Maps: missing GOOGLE_MAPS_API_KEY (--dart-define).',
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
    // Do not block first frame on FCM permission/token (FIS can be slow offline).
    unawaited(_setupFirebaseMessaging());
  } catch (e, st) {
    debugPrint('Firebase init: $e\n$st');
  }
  await AccountSessionStore.instance.loadFromPrefs();
  runApp(const PatrolMobileApp());
  // After first frame — configure() is heavy and must not block Choreographer.
  unawaited(PatrolBackgroundService.ensureInitialized());
}

Future<void> _setupFirebaseMessaging() async {
  try {
    await FirebaseMessaging.instance.requestPermission();
  } catch (e, st) {
    debugPrint('Firebase Messaging permission: $e\n$st');
  }
}

class PatrolMobileApp extends StatefulWidget {
  const PatrolMobileApp({super.key});

  @override
  State<PatrolMobileApp> createState() => _PatrolMobileAppState();
}

class _PatrolMobileAppState extends State<PatrolMobileApp> {
  Locale _locale = AppLocaleStore.defaultLocale;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    unawaited(_restoreLocale());
    PatrolSession.attach(
      navigatorKey: _navigatorKey,
      currentLocale: () => _locale,
      onLocaleChanged: _onLocaleChanged,
    );
    PatrolRealtimeTrackCoordinator.attach(
      navigatorKey: _navigatorKey,
      currentLocale: () => _locale,
    );
  }

  Future<void> _restoreLocale() async {
    final saved = await AppLocaleStore.readLocale();
    if (!mounted) return;
    setState(() => _locale = saved);
  }

  void _onLocaleChanged(Locale locale) {
    setState(() => _locale = locale);
    unawaited(AppLocaleStore.saveLocale(locale));
  }

  @override
  void dispose() {
    PatrolRealtimeTrackCoordinator.detach();
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
        // Do not call GoogleFonts.interTextTheme here — it blocks the UI thread at startup.
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: LocationGateScreen(
        locale: _locale,
        onLocaleChanged: _onLocaleChanged,
      ),
    );
  }
}
