import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'navigation/patrol_session.dart';
import 'screens/location_gate_screen.dart';
import 'http/patrol_dio.dart';
import 'services/account_session_store.dart';
import 'services/app_locale_store.dart';
import 'services/patrol_active_round_coordinator.dart';
import 'background/patrol_background_service.dart';
import 'services/patrol_realtime_track_coordinator.dart';
import 'services/patrol_startup_coordinator.dart';

const Duration _kMainBootstrapTimeout = Duration(seconds: 5);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Avoid blocking the first Flutter frame on fonts.googleapis.com (offline / slow CDN).
  GoogleFonts.config.allowRuntimeFetching = false;

  unawaited(_bootstrapFirebaseAndMessaging());

  Locale initialLocale = AppLocaleStore.defaultLocale;
  try {
    initialLocale = await AppLocaleStore.readLocale().timeout(
      _kMainBootstrapTimeout,
      onTimeout: () => AppLocaleStore.defaultLocale,
    );
  } catch (_) {
    //
  }

  try {
    await PatrolDio.ensureReady().timeout(_kMainBootstrapTimeout);
  } on TimeoutException {
    //
  } catch (_) {
    //
  }

  try {
    await AccountSessionStore.instance.loadFromPrefs().timeout(
      _kMainBootstrapTimeout,
    );
  } on TimeoutException {
    //
  } catch (_) {
    //
  }

  runApp(PatrolMobileApp(initialLocale: initialLocale));
}

Future<void> _bootstrapFirebaseAndMessaging() async {
  try {
    await _initializeFirebase().timeout(_kMainBootstrapTimeout);
    if (Firebase.apps.isEmpty) return;
    FirebaseMessaging.instance.onTokenRefresh.listen(
      AccountSessionStore.instance.cacheDevicePushToken,
    );
    unawaited(_setupFirebaseMessaging());
  } catch (_) {
    //
  }
}

Future<void> _initializeFirebase() async {
  if (kIsWeb) return;
  try {
    final options = await DefaultFirebaseOptions.resolveForInit();
    if (options != null) {
      await Firebase.initializeApp(options: options);
      return;
    }
    if (!kIsWeb && Platform.isIOS) {
      await Firebase.initializeApp();
    }
  } catch (_) {
  }
}

Future<void> _setupFirebaseMessaging() async {
  try {
    await FirebaseMessaging.instance.requestPermission();
  } catch (_) {
  }
}

class PatrolMobileApp extends StatefulWidget {
  const PatrolMobileApp({super.key, required this.initialLocale});

  final Locale initialLocale;

  @override
  State<PatrolMobileApp> createState() => _PatrolMobileAppState();
}

class _PatrolMobileAppState extends State<PatrolMobileApp>
    with WidgetsBindingObserver {
  late Locale _locale;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
    WidgetsBinding.instance.addObserver(this);
    // Configure FGS once after first frame (plugins ready; not on socket path).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PatrolBackgroundService.configureAtAppStart();
      await PatrolBackgroundService.processPendingNotificationActions();
      await PatrolBackgroundService.ensureCheckpointTtsRelayAttached();
    });
    PatrolSession.attach(
      navigatorKey: _navigatorKey,
      currentLocale: () => _locale,
      onLocaleChanged: _onLocaleChanged,
    );
    PatrolStartupCoordinator.resetForNewProcessLaunch();
    PatrolStartupCoordinator.attach();
    PatrolActiveRoundCoordinator.attach();
    PatrolRealtimeTrackCoordinator.attach(
      navigatorKey: _navigatorKey,
      currentLocale: () => _locale,
    );
  }

  void _onLocaleChanged(Locale locale) {
    if (_locale == locale) return;
    setState(() => _locale = locale);
    unawaited(AppLocaleStore.saveLocale(locale));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(PatrolBackgroundService.processPendingNotificationActions());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PatrolStartupCoordinator.detach();
    PatrolActiveRoundCoordinator.detach();
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
      debugShowCheckedModeBanner: true,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: LocationGateScreen(
        locale: _locale,
        onLocaleChanged: _onLocaleChanged,
      ),
    );
  }
}
