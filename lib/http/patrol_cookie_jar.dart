import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

/// Auth cookies for Dio REST and STOMP/SockJS (`Cookie` + `X-XSRF-TOKEN`).
abstract final class PatrolCookieJar {
  PatrolCookieJar._();

  static const accessTokenCookieName = 'access_token';
  static const xsrfTokenCookieName = 'XSRF-TOKEN';
  static const xsrfTokenHeaderName = 'X-XSRF-TOKEN';

  static PersistCookieJar? _jar;
  static Future<void>? _initFuture;

  static bool get isInitialized => _jar != null;

  static Future<void> ensureInitialized() {
    return _initFuture ??= _init();
  }

  static Future<void> _init() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    _jar = PersistCookieJar(
      ignoreExpires: false,
      storage: FileStorage('${appDocDir.path}/.cookies/'),
    );
  }

  static PersistCookieJar get jar {
    final j = _jar;
    if (j == null) {
      throw StateError('Call PatrolCookieJar.ensureInitialized() first');
    }
    return j;
  }

  static void attachTo(Dio dio) {
    dio.interceptors.add(CookieManager(jar));
  }

  static Future<String?> getAccessToken() async {
    await ensureInitialized();
    return _cookieValue(accessTokenCookieName);
  }

  static Future<bool> hasSession() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> clear() async {
    await ensureInitialized();
    await jar.deleteAll();
  }

  /// Headers for SockJS/WebSocket handshake — all persisted cookies + CSRF.
  static Future<PatrolStompAuthHeaders?> stompAuthHeaders() async {
    await ensureInitialized();
    final base = AppConfig.effectiveBaseUrl.trim();
    if (base.isEmpty) return null;

    final cookies = await jar.loadForRequest(Uri.parse(base));
    if (cookies.isEmpty) return null;

    final hasAccess = cookies.any(
      (c) => c.name == accessTokenCookieName && c.value.isNotEmpty,
    );
    if (!hasAccess) return null;

    final cookieHeader =
        cookies.map((c) => '${c.name}=${c.value}').join('; ');

    var xsrfToken = '';
    for (final c in cookies) {
      if (c.name == xsrfTokenCookieName && c.value.isNotEmpty) {
        xsrfToken = c.value;
        break;
      }
    }

    return PatrolStompAuthHeaders(
      cookieHeader: cookieHeader,
      xsrfToken: xsrfToken,
    );
  }

  static Future<String?> _cookieValue(String name) async {
    final base = AppConfig.effectiveBaseUrl.trim();
    if (base.isEmpty) return null;

    final cookies = await jar.loadForRequest(Uri.parse(base));
    for (final c in cookies) {
      if (c.name == name && c.value.isNotEmpty) {
        return c.value;
      }
    }
    return null;
  }
}

class PatrolStompAuthHeaders {
  const PatrolStompAuthHeaders({
    required this.cookieHeader,
    required this.xsrfToken,
  });

  final String cookieHeader;
  final String xsrfToken;

  Map<String, dynamic> get webSocketConnectHeaders {
    return <String, dynamic>{
      'Cookie': cookieHeader,
      if (xsrfToken.isNotEmpty)
        PatrolCookieJar.xsrfTokenHeaderName: xsrfToken,
    };
  }

  Map<String, String> get stompConnectHeaders {
    return <String, String>{
      'accept-version': '1.1,1.2',
      'heart-beat': '0,0',
      'Cookie': cookieHeader,
      if (xsrfToken.isNotEmpty)
        PatrolCookieJar.xsrfTokenHeaderName: xsrfToken,
    };
  }
}
