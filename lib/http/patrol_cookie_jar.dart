import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

/// When BE omits `Path` on `Set-Cookie`, [DefaultCookieJar] stores cookies under
/// `_curDir(uri.path)` (e.g. `/api/accounts` for login) so they are **not**
/// sent to `/api/patrol/...`. Default to `/` so all API paths receive auth cookies.
final class _PatrolCookieJarAdapter implements CookieJar {
  _PatrolCookieJarAdapter(this._persist);

  final PersistCookieJar _persist;

  @override
  bool get ignoreExpires => _persist.ignoreExpires;

  static void _defaultPathWhenMissing(List<Cookie> cookies) {
    for (final c in cookies) {
      final p = c.path;
      if (p == null || p.isEmpty) {
        c.path = '/';
      }
    }
  }

  @override
  Future<void> saveFromResponse(Uri uri, List<Cookie> cookies) {
    _defaultPathWhenMissing(cookies);
    return _persist.saveFromResponse(uri, cookies);
  }

  @override
  Future<List<Cookie>> loadForRequest(Uri uri) =>
      _persist.loadForRequest(uri);

  @override
  Future<void> delete(Uri uri, [bool withDomainSharedCookie = false]) =>
      _persist.delete(uri, withDomainSharedCookie);

  @override
  Future<void> deleteAll() => _persist.deleteAll();
}

/// Auth cookies for Dio REST and STOMP/SockJS (`Cookie` + `X-XSRF-TOKEN`).
abstract final class PatrolCookieJar {
  PatrolCookieJar._();

  static const accessTokenCookieName = 'access_token';
  static const refreshTokenCookieName = 'refresh_token';
  static const xsrfTokenCookieName = 'XSRF-TOKEN';
  static const xsrfTokenHeaderName = 'X-XSRF-TOKEN';

  static CookieJar? _jar;
  static Future<void>? _initFuture;

  static bool get isInitialized => _jar != null;

  static Future<void> ensureInitialized() {
    return _initFuture ??= _init();
  }

  static Future<void> _init() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    _jar = _PatrolCookieJarAdapter(
      PersistCookieJar(
        ignoreExpires: true,
        storage: FileStorage('${appDocDir.path}/.cookies/'),
      ),
    );
  }

  static CookieJar get jar {
    final j = _jar;
    if (j == null) {
      throw StateError('Call PatrolCookieJar.ensureInitialized() first');
    }
    return j;
  }

  /// Add after app interceptors so [CookieManager] saves `Set-Cookie` before 401 handling.
  static void attachTo(Dio dio) {
    dio.interceptors.add(CookieManager(jar));
  }

  /// Cookies that will be sent for [uri] (login: `access_token`/`refresh_token`;
  /// after `/accounts/me`: also `XSRF-TOKEN`).
  static Future<List<Cookie>> cookiesForRequest(Uri uri) async {
    await ensureInitialized();
    return jar.loadForRequest(uri);
  }

  /// REST: `Cookie` + `X-XSRF-TOKEN` (when present). BE auth is cookie-based.
  static Future<void> applyRestAuthHeaders(RequestOptions options) async {
    final cookies = await cookiesForRequest(options.uri);
    if (cookies.isEmpty) return;

    final headers = options.headers;
    headers[HttpHeaders.cookieHeader] = CookieManager.getCookies(cookies);

    for (final c in cookies) {
      if (c.name == xsrfTokenCookieName && c.value.isNotEmpty) {
        headers[xsrfTokenHeaderName] = c.value;
      }
    }
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
