import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/access_token_payload.dart';
import '../config/storage_keys.dart';

/// Headers dùng chung cho mọi request API: `Accept-Language`, `x-client-os`,
/// `Authorization: Bearer …` nếu có token trong store, và `Content-Type` khi gửi JSON.
class ApiRequestHeaders {
  ApiRequestHeaders._();

  static Future<Map<String, String>> build({bool jsonBody = true}) async {
    final headers = <String, String>{
      'Accept-Language': _acceptLanguage,
      'x-client-os': _clientOs,
      if (jsonBody) 'Content-Type': 'application/json',
    };
    final p = await SharedPreferences.getInstance();
    final t = AccessTokenPayload.getAccessTokenStored(
      p.getString(StorageKeys.accessToken),
    );
    if (t != null && t.isNotEmpty) {
      headers['Authorization'] = 'Bearer $t';
    }
    return headers;
  }

  static String get _acceptLanguage {
    final locale = ui.PlatformDispatcher.instance.locale;
    final lang = locale.languageCode;
    final country = locale.countryCode;
    if (country != null && country.isNotEmpty) {
      return '$lang-$country';
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
