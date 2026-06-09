import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../navigation/patrol_session.dart';
import 'api_request_headers.dart';
import 'patrol_cookie_jar.dart';

/// Shared Dio: cookies carry auth; locale/OS/offset headers; any API 401 → login
/// ([onResponse] — 401 is not a Dio error because validateStatus accepts status < 600).
/// Default response is deserialized JSON (`Map` / `List`).
abstract final class PatrolDio {
  PatrolDio._();

  static Dio? _api;
  static Future<void>? _readyFuture;

  static Future<void> ensureReady() {
    return _readyFuture ??= _bootstrap();
  }

  static Future<void> _bootstrap() async {
    await PatrolCookieJar.ensureInitialized();
    _api ??= _createApi();
    syncBaseUrls();
  }

  static Dio get instance {
    final dio = _api;
    if (dio == null) {
      throw StateError('Call PatrolDio.ensureReady() before using PatrolDio.instance');
    }
    return dio;
  }

  static void syncBaseUrls({Dio? dio}) {
    final b = AppConfig.effectiveBaseUrl;
    if (dio != null) {
      dio.options.baseUrl = b;
    } else if (_api != null) {
      _api!.options.baseUrl = b;
    }
  }

  static Dio _newDio() {
    return Dio(
      BaseOptions(
        responseType: ResponseType.json,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (s) => s != null && s < 600,
      ),
    );
  }

  static Dio _createApi() {
    final dio = _newDio();
    PatrolCookieJar.attachTo(dio);
    dio.interceptors.add(_PatrolInterceptors());
    syncBaseUrls(dio: dio);
    return dio;
  }
}

class _PatrolInterceptors extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final headers = options.headers;

    headers.putIfAbsent(
      'Accept-Language',
      () => ApiRequestHeaders.defaultAcceptLanguage,
    );
    headers.putIfAbsent(
      ApiRequestHeaders.xClientOs,
      () => ApiRequestHeaders.defaultClientOs,
    );
    headers.putIfAbsent(
      ApiRequestHeaders.xOffSet,
      () => ApiRequestHeaders.getClientOffset(),
    );
    headers.putIfAbsent(
      ApiRequestHeaders.xClientPlatform,
      () => ApiRequestHeaders.defaultClientPlatform,
    );

    handler.next(options);
  }

  /// Login 401 = wrong credentials — stay on login screen, do not clear session.
  bool _isLoginRequest(RequestOptions options) {
    return options.uri.path.toLowerCase().contains('/accounts/login');
  }

  Future<void> _endSessionOn401(RequestOptions options) async {
    if (_isLoginRequest(options)) return;
    await PatrolSession.endSessionAndNavigateToLogin();
  }

  DioException _sessionExpiredException({
    required RequestOptions requestOptions,
    required Response<dynamic>? response,
  }) {
    return DioException(
      requestOptions: requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      error: 'session_expired',
    );
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    if (response.statusCode == 401) {
      await _endSessionOn401(response.requestOptions);
      if (!_isLoginRequest(response.requestOptions)) {
        return handler.reject(
          _sessionExpiredException(
            requestOptions: response.requestOptions,
            response: response,
          ),
        );
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      await _endSessionOn401(err.requestOptions);
      if (!_isLoginRequest(err.requestOptions)) {
        return handler.reject(
          _sessionExpiredException(
            requestOptions: err.requestOptions,
            response: err.response,
          ),
        );
      }
    }
    handler.next(err);
  }
}
