import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/access_token_payload.dart';
import '../config/app_config.dart';
import '../config/storage_keys.dart';
import '../navigation/patrol_session.dart';
import 'api_request_headers.dart';
import 'api_response.dart';
import 'patrol_api_endpoints.dart';

const _extraRetry = '__patrol_retry';

/// Dio dùng chung: interceptor gắn Bearer + locale/OS/offset và xử lý 401 → refresh + retry một lần.
/// Response mặc định là JSON đã deserialize (`Map` / `List`).
abstract final class PatrolDio {
  PatrolDio._();

  /// POST refresh không đi qua interceptor (tránh vòng 401).
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

  /// Các request đồng thời 401 chỉ chạy một lần refresh.
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

    SharedPreferences.getInstance()
        .then((p) {
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

          final raw = p.getString(StorageKeys.accessToken);
          final bearer = AccessTokenPayload.getAccessTokenStored(raw);
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
      await AccessTokenPayload.clearStored();
      PatrolSession.navigateToLoginReplaceAll();
      return handler.next(err);
    }

    PatrolSession.notifyAuthStored();

    final prefs = await SharedPreferences.getInstance();
    final bearer = AccessTokenPayload.getAccessTokenStored(
      prefs.getString(StorageKeys.accessToken),
    );
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

  final prefs = await SharedPreferences.getInstance();
  final tokenField = AccessTokenPayload.refreshTokenForRequestBody(
    prefs.getString(StorageKeys.accessToken),
  );
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

  await prefs.setString(StorageKeys.accessToken, jsonEncode(toStore));
  return true;
}
