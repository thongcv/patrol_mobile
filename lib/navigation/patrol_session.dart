import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/login_screen.dart';

/// Định hướng “về đăng nhập” và thông báo token mới — tương đương `location`/CustomEvent Web.
abstract final class PatrolSession {
  PatrolSession._();

  static GlobalKey<NavigatorState>? _navigatorKey;
  static Locale Function()? _currentLocale;
  static ValueChanged<Locale>? _onLocaleChanged;

  static final StreamController<void> _authStored =
      StreamController<void>.broadcast();

  static Stream<void> get authStoredChanges => _authStored.stream;

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

  /// Xóa stack và đưa người dùng về [LoginScreen] (ví dụ refresh token thất bại).
  static void navigateToLoginReplaceAll() {
    final nav = _navigatorKey?.currentState;
    final locale = _currentLocale?.call();
    final onLoc = _onLocaleChanged;
    if (nav == null || locale == null || onLoc == null) return;
    nav.pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(
          locale: locale,
          onLocaleChanged: onLoc,
        ),
      ),
      (_) => false,
    );
  }
}
