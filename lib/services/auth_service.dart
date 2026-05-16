import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/access_token_payload.dart';
import '../config/app_config.dart';
import '../config/storage_keys.dart';
import '../http/api_failure.dart';
import '../http/api_response.dart';
import '../http/api_result.dart';
import '../http/patrol_api_endpoints.dart';
import '../http/patrol_dio.dart';
import '../navigation/patrol_session.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Future<String?> getStoredAccessToken() async {
    final p = await SharedPreferences.getInstance();
    return AccessTokenPayload.getAccessTokenStored(
      p.getString(StorageKeys.accessToken),
    );
  }

  Future<Map<String, dynamic>?> getStoredAccessTokenObject() async {
    final p = await SharedPreferences.getInstance();
    return AccessTokenPayload.mapFromStored(
      p.getString(StorageKeys.accessToken),
    );
  }

  Future<void> clearToken() async {
    await AccessTokenPayload.clearStored();
  }

  Future<void> cacheDevicePushToken(String? token) async {
    final p = await SharedPreferences.getInstance();
    final t = token?.trim();
    if (t == null || t.isEmpty) {
      await p.remove(StorageKeys.devicePushToken);
    } else {
      await p.setString(StorageKeys.devicePushToken, t);
    }
  }

  Future<ApiResult<LoginSuccess>> login({
    required String username,
    required String password,
  }) async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }

    PatrolDio.syncBaseUrls();
    final fcmToken = await _fcmTokenForLogin();
    final loginUri = AppConfig.resolveApiUri(PatrolApiEndpoints.accountsLoginPath);

    try {
      final body = <String, dynamic>{
        'username': username.trim(),
        'password': password.trim(),
        if (fcmToken != null && fcmToken.isNotEmpty) 'deviceToken': fcmToken,
      };
      final res = await PatrolDio.instance.postUri<dynamic>(
        loginUri,
        data: body,
      );

      final status = res.statusCode ?? 0;

      if (status == 200) {
        final data = responseEnvelopeData(res.data);
        if (data == null) {
          return ApiResult.failure(ApiFailure.badResponse(res));
        }
        final accessToken = AccessTokenPayload.persistableBlobFromApiEnvelope(data);
        final bearer = accessToken != null
            ? AccessTokenPayload.bearerJwtFromAuthMap(accessToken)
            : null;
        if (accessToken != null && bearer != null && bearer.isNotEmpty) {
          final p = await SharedPreferences.getInstance();
          await p.setString(StorageKeys.accessToken, jsonEncode(accessToken));
          PatrolSession.notifyAuthStored();
          return ApiResult.success(
            LoginSuccess(token: bearer, accessToken: accessToken),
          );
        }
        return ApiResult.failure(ApiFailure.badResponse(res));
      }
      return ApiResult.failure(
        apiFailureFromHttpResponse(statusCode: status, body: res),
      );
    } on DioException catch (e) {
      return ApiResult.failure(apiFailureFromDioException(e));
    } catch (_) {
      return ApiResult.failure(ApiFailure.network());
    }
  }

  Future<ApiResult<ApiUnit>> forgotPassword({
    required String email,
    required String usernameOrPhone,
  }) async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }
    PatrolDio.syncBaseUrls();
    try {
      final res = await PatrolDio.instance.post<dynamic>(
        '/api/accounts/forget-password',
        data: <String, dynamic>{
          'email': email.trim(),
          'username': usernameOrPhone.trim(),
        },
      );

      final status = res.statusCode ?? 0;
      if (status == 200) {
        return ApiResult.success(ApiUnit.instance);
      }
      return ApiResult.failure(
        apiFailureFromHttpResponse(statusCode: status, body: res),
      );
    } on DioException catch (e) {
      return ApiResult.failure(apiFailureFromDioException(e));
    } catch (_) {
      return ApiResult.failure(ApiFailure.network());
    }
  }

  Future<ApiResult<ApiUnit>> logout() async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }

    PatrolDio.syncBaseUrls();
    try {
      final res = await PatrolDio.instance.get<dynamic>('/api/accounts/logout');
      final status = res.statusCode ?? 0;
      
      if (status == 200 || status == 204) {
        return ApiResult.success(ApiUnit.instance);
      }
      return ApiResult.failure(
        apiFailureFromHttpResponse(statusCode: status, body: res),
      );
    } on DioException catch (e) {
      return ApiResult.failure(apiFailureFromDioException(e));
    } catch (_) {
      return ApiResult.failure(ApiFailure.network());
    }
  }

  Future<String?> _fcmTokenForLogin() async {
    if (Firebase.apps.isEmpty) {
      final p = await SharedPreferences.getInstance();
      return p.getString(StorageKeys.devicePushToken)?.trim();
    }
    try {
      final t = await FirebaseMessaging.instance.getToken();
      final s = t?.trim();
      if (s != null && s.isNotEmpty) {
        await cacheDevicePushToken(s);
        return s;
      }
    } catch (_) {
      //
    }
    final p = await SharedPreferences.getInstance();
    return p.getString(StorageKeys.devicePushToken)?.trim();
  }
}

class LoginSuccess {
  const LoginSuccess({required this.token, this.accessToken});

  final String token;
  final Map<String, dynamic>? accessToken;
}
