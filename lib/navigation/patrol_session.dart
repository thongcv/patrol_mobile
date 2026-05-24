import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../services/account_session_store.dart';
import '../services/patrol_realtime_track_coordinator.dart';
import '../http/api_failure.dart';

/// Routes to login and notifies on new token — equivalent to Web `location`/CustomEvent.
abstract final class PatrolSession {
  PatrolSession._();

  static GlobalKey<NavigatorState>? _navigatorKey;
  static Locale Function()? _currentLocale;
  static ValueChanged<Locale>? _onLocaleChanged;

  static final StreamController<void> _authStored =
      StreamController<void>.broadcast();

  static final StreamController<void> _sessionEnded =
      StreamController<void>.broadcast();

  static Stream<void> get authStoredChanges => _authStored.stream;

  /// Token expired / refresh failed — [LocationGateScreen] listens to show login again.
  static Stream<void> get sessionEnded => _sessionEnded.stream;

  static void attach({
    required GlobalKey<NavigatorState> navigatorKey,
    required Locale Function() currentLocale,
    required ValueChanged<Locale> onLocaleChanged,
  }) {
    _navigatorKey = navigatorKey;
    _currentLocale = currentLocale;
    _onLocaleChanged = onLocaleChanged;
  }

  static void detach() {
    _navigatorKey = null;
    _currentLocale = null;
    _onLocaleChanged = null;
  }

  static void notifyAuthStored() {
    if (!_authStored.isClosed) _authStored.add(null);
  }

  /// Invalid session (401/403): clears token and navigates to login.
  static Future<void> endSessionAndNavigateToLogin() async {
    await PatrolRealtimeTrackCoordinator.onSessionEnded();
    await AccountSessionStore.instance.clearToken();
    navigateToLoginReplaceAll();
  }

  static bool isUnauthorized(ApiFailure? failure) =>
      failure?.kind == ApiFailureKind.unauthorized;

  /// Clears stack and navigates to [LoginScreen] (e.g. refresh token failed).
  static void navigateToLoginReplaceAll() {
    if (!_sessionEnded.isClosed) _sessionEnded.add(null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _pushLoginRoute());
  }

  static void _pushLoginRoute() {
    final nav = _navigatorKey?.currentState;
    final locale = _currentLocale?.call();
    final onLoc = _onLocaleChanged;
    if (nav == null || locale == null || onLoc == null) return;

    final login = MaterialPageRoute<void>(
      builder: (_) => LoginScreen(
        locale: locale,
        onLocaleChanged: onLoc,
      ),
    );

    if (nav.canPop()) {
      nav.pushAndRemoveUntil<void>(login, (_) => false);
    } else {
      nav.pushReplacement(login);
    }
  }
}
