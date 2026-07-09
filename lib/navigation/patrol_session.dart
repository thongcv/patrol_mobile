import 'dart:async';

import 'package:flutter/material.dart';

import '../background/patrol_background_isolate_flags.dart';
import '../background/patrol_fgs_isolate_bridge.dart';
import '../screens/login_screen.dart';
import '../services/account_session_store.dart';

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

  /// Session ended (401 / logout) — [LocationGateScreen] listens to show login again.
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
    _sessionExpiredHandled = false;
    if (!_authStored.isClosed) _authStored.add(null);
  }

  static void notifySessionEnded() {
    if (!_sessionEnded.isClosed) _sessionEnded.add(null);
  }

  static Future<void>? _endSessionInFlight;

  /// Set after first 401/logout-expiry handling — blocks repeated navigation jitter
  /// from parallel API 401/403s (Dio interceptor).
  static bool _sessionExpiredHandled = false;

  /// REST 401/403 — FGS relays to main; main isolate clears session here.
  static Future<void> handleUnauthorizedApiResponse() async {
    if (PatrolBackgroundIsolateFlags.active) {
      PatrolFgsIsolateBridge.notifySessionExpiredToMain();
      return;
    }
    await endSessionAndNavigateToLogin();
  }

  /// Invalid session (401/403): clears token and navigates to login.
  static Future<void> endSessionAndNavigateToLogin() async {
    if (_sessionExpiredHandled) return;
    final inFlight = _endSessionInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    _sessionExpiredHandled = true;
    final future = _endSessionAndNavigateToLoginImpl();
    _endSessionInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_endSessionInFlight, future)) {
        _endSessionInFlight = null;
      }
    }
  }

  static Future<void> _endSessionAndNavigateToLoginImpl() async {
    await AccountSessionStore.instance.clearToken();
    navigateToLoginReplaceAll();
  }

  static const String _loginRouteName = '/login';

  static bool _loginNavigationQueued = false;

  /// Clears stack and navigates to [LoginScreen] (e.g. session expired).
  static void navigateToLoginReplaceAll() {
    if (_loginNavigationQueued) return;
    _loginNavigationQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loginNavigationQueued = false;
      _pushLoginRouteIfNeeded();
    });
  }

  static bool _topRouteIsLogin(NavigatorState nav) {
    var isLogin = false;
    nav.popUntil((route) {
      isLogin = route.settings.name == _loginRouteName;
      return true;
    });
    return isLogin;
  }

  static void _pushLoginRouteIfNeeded() {
    final nav = _navigatorKey?.currentState;
    final locale = _currentLocale?.call();
    final onLoc = _onLocaleChanged;
    if (nav == null || locale == null || onLoc == null) return;
    if (_topRouteIsLogin(nav)) return;

    final login = MaterialPageRoute<void>(
      settings: const RouteSettings(name: _loginRouteName),
      builder: (ctx) => LoginScreen(
        locale: _currentLocale?.call() ?? Localizations.localeOf(ctx),
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
