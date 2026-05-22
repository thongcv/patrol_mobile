import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../services/account_session_store.dart';
import '../http/api_failure.dart';

/// Định hướng “về đăng nhập” và thông báo token mới — tương đương `location`/CustomEvent Web.
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

  /// Token hết hạn / refresh thất bại — [LocationGateScreen] lắng nghe để hiện lại login.
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

  /// Phiên không hợp lệ (401/403): xóa token và đưa về đăng nhập.
  static Future<void> endSessionAndNavigateToLogin() async {
    await AccountSessionStore.instance.clearToken();
    navigateToLoginReplaceAll();
  }

  static bool isUnauthorized(ApiFailure? failure) =>
      failure?.kind == ApiFailureKind.unauthorized;

  /// Xóa stack và đưa người dùng về [LoginScreen] (ví dụ refresh token thất bại).
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
