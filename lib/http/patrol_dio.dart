import 'package:dio/dio.dart';

import '../config/access_token_payload.dart';
import '../config/app_config.dart';
import '../navigation/patrol_session.dart';
import '../services/account_session_store.dart';
import 'api_request_headers.dart';
import 'api_response.dart';
import 'patrol_api_endpoints.dart';

const _extraRetry = '__patrol_retry';

/// Shared Dio: interceptor attaches Bearer + locale/OS/offset and handles 401 → refresh + one retry.
/// Default response is deserialized JSON (`Map` / `List`).
abstract final class PatrolDio {
  PatrolDio._();

  /// POST refresh bypasses interceptor (avoids 401 loop).
  static final Dio refreshClient = Dio(
    BaseOptions(
      responseType: ResponseType.json,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (s) => s != null && s < 600,
    ),
  );

  static Dio? _api;

  static Future<bool>? _refreshFut;

  static Dio get instance => _api ??= _createApi();

  static void syncBaseUrls() {
    final b = AppConfig.effectiveBaseUrl;
    refreshClient.options.baseUrl = b;
    if (_api != null) _api!.options.baseUrl = b;
  }

  static Dio _createApi() {
    final dio = Dio(
      BaseOptions(
        responseType: ResponseType.json,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (s) => s != null && s < 600,
      ),
    );
    dio.interceptors.add(_PatrolInterceptors());
    syncBaseUrls();
    return dio;
  }

  /// Concurrent 401 requests share a single refresh run.
  static Future<bool> refreshTokensShared() {
    _refreshFut ??= () async {
      try {
        return await _performRefreshOnce();
      } finally {
        _refreshFut = null;
      }
    }();
    return _refreshFut!;
  }
}

class _PatrolInterceptors extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    PatrolDio.syncBaseUrls();
    final headers = options.headers;

    AccountSessionStore.instance
        .getStoredAccessToken()
        .then((bearer) {
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

          if (!headers.containsKey('Authorization') &&
              bearer != null &&
              bearer.isNotEmpty) {
            headers['Authorization'] = 'Bearer $bearer';
          }
          handler.next(options);
        })
        .catchError((Object e, StackTrace st) {
          handler.reject(
            DioException(requestOptions: options, error: e, stackTrace: st),
            true,
          );
        });
  }

  bool _skip401Retry(RequestOptions options) {
    if (options.extra[_extraRetry] == true) return true;
    final path = options.uri.path.toLowerCase();
    return path.contains('/accounts/login') ||
        path.contains('/accounts/refreshtoken');
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) return handler.next(err);

    final ro = err.requestOptions;
    if (_skip401Retry(ro)) return handler.next(err);

    final refreshed = await PatrolDio.refreshTokensShared();
    if (!refreshed) {
      await AccountSessionStore.instance.clearToken();
      PatrolSession.navigateToLoginReplaceAll();
      return handler.reject(
        DioException(
          requestOptions: ro,
          response: err.response,
          type: DioExceptionType.cancel,
          error: 'session_expired',
        ),
      );
    }

    final bearer = await AccountSessionStore.instance.getStoredAccessToken();
    try {
      ro.extra[_extraRetry] = true;
      if (bearer != null && bearer.isNotEmpty) {
        ro.headers['Authorization'] = 'Bearer $bearer';
      } else {
        ro.headers.remove('Authorization');
      }
      final rep = await PatrolDio.instance.fetch<dynamic>(ro);
      handler.resolve(rep);
    } catch (e, st) {
      if (e is DioException) {
        handler.next(e);
      } else {
        handler.next(
          DioException(
            requestOptions: err.requestOptions,
            error: e,
            stackTrace: st,
          ),
        );
      }
    }
  }
}

Future<bool> _performRefreshOnce() async {
  final base = AppConfig.effectiveBaseUrl.trim();
  if (base.isEmpty) return false;

  final tokenField =
      await AccountSessionStore.instance.refreshTokenForRequestBody();
  if (tokenField == null) return false;

  PatrolDio.refreshClient.options.baseUrl = base;
  final uri = AppConfig.resolveApiUri(PatrolApiEndpoints.accountsRefreshPath);
  Response<dynamic> res;
  try {
    res = await PatrolDio.refreshClient.postUri<dynamic>(
      uri,
      data: <String, dynamic>{'token': tokenField},
      options: Options(headers: ApiRequestHeaders.jsonOnlyHeaders()),
    );
  } catch (_) {
    return false;
  }

  if (res.statusCode != 200) return false;

  final root = jsonMapCoerce(res.data);
  if (root == null) return false;

  final toStore = AccessTokenPayload.persistableBlobAfterRefreshRoot(root);
  if (toStore == null) return false;

  await AccountSessionStore.instance.storeAccessToken(toStore);
  return true;
}
