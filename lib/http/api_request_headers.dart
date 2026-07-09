import 'dart:ui' as ui;



import 'package:flutter/foundation.dart';



/// Default header values: locale, OS, timezone offset (Bearer and JSON attached by Dio interceptor / request).

class ApiRequestHeaders {

  ApiRequestHeaders._();


  static const String xClientOs = 'X-Client-Os';

  static const String xClientPlatform = 'X-Client-Platform';

  static const String xOffSet = 'X-Off-Set';

  static const String xMenuCode = 'X-Menu-Code';

  /// Default `Accept-Language` from [ui.PlatformDispatcher] (overridable per Dio request only).

  static String get defaultAcceptLanguage => _acceptLanguage;

  static String get defaultClientOs => _clientOs;

  static String get defaultClientPlatform => _clientPlatform;

  static String get defaultMenuCode => _menuCode;

  /// JSON `Content-Type` headers for POST bodies.

  static Map<String, String> jsonOnlyHeaders() => {
        'Accept-Language': defaultAcceptLanguage,
        xClientOs: defaultClientOs,
        xClientPlatform: defaultClientPlatform,
        xOffSet: getClientOffset(),
        xMenuCode: defaultMenuCode,
        'Content-Type': 'application/json',
      };

  /// Client machine offset, e.g. `+07:00` — matches Java `ZoneOffset.of()`.
  static String getClientOffset() {

    final totalMinutes = DateTime.now().timeZoneOffset.inMinutes;
    final sign = totalMinutes >= 0 ? '+' : '-';
    final abs = totalMinutes.abs();
    final h = (abs ~/ 60).toString().padLeft(2, '0');
    final m = (abs % 60).toString().padLeft(2, '0');

    return '$sign$h:$m';

  }

  static String get _acceptLanguage {
    final locale = ui.PlatformDispatcher.instance.locale;
    final lang = locale.languageCode;
    final country = locale.countryCode;
    if (country != null && country.isNotEmpty) {
      return '$lang;$lang-$country';
    }
    return lang;
  }

  static String get _menuCode {
    
      return "";
  }

  static String get _clientOs {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  static String get _clientPlatform {

    if (kIsWeb) return 'WEB';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return 'MOBILE';
      case TargetPlatform.macOS:
        return 'MACOS';
      case TargetPlatform.windows:
        return 'WINDOWS';
      case TargetPlatform.linux:
        return 'LINUX';
      case TargetPlatform.fuchsia:
        return 'FUCHSIA';
    }
  }

}




