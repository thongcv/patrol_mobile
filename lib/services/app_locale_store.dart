import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';

/// UI locale — persisted when the user changes language (login / home); readable from background isolate.
abstract final class AppLocaleStore {
  AppLocaleStore._();

  static const Locale defaultLocale = Locale('vi');

  static Future<Locale> readLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return _localeFromLanguageCode(prefs.getString(StorageKeys.appLocaleLanguageCode));
  }

  static Future<void> saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.appLocaleLanguageCode,
      locale.languageCode,
    );
  }

  static Locale _localeFromLanguageCode(String? code) {
    if (code == 'en') return const Locale('en');
    return defaultLocale;
  }
}
