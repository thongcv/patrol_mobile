import 'dart:ui' as ui;



import 'package:flutter/foundation.dart';



/// Giá trị header mặc định: locale, OS, timezone offset (Bearer và JSON do Dio interceptor / request gắn).

class ApiRequestHeaders {

  ApiRequestHeaders._();



  static const String xClientOs = 'x-client-os';



  /// Giống `x-off-set` phía frontend Web / Java backend.

  static const String xOffSet = 'x-off-set';



  /// `Accept-Language` mặc định từ [ui.PlatformDispatcher] (chỉ có thể ghi đè trên Dio request).

  static String get defaultAcceptLanguage => _acceptLanguage;



  static String get defaultClientOs => _clientOs;



  /// Headers JSON cho POST refresh (không gắn Bearer từ prefs).

  static Map<String, String> jsonOnlyHeaders() => {

        'Accept-Language': defaultAcceptLanguage,

        xClientOs: defaultClientOs,

        xOffSet: getClientOffset(),

        'Content-Type': 'application/json',

      };



  /// Offset máy client, ví dụ `+07:00` — khớp `ZoneOffset.of()` phía Java.

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

}

