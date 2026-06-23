import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../config/storage_keys.dart';
import '../http/api_failure.dart';
import '../http/api_response.dart';
import '../http/api_result.dart';
import '../http/patrol_api_endpoints.dart';
import '../http/patrol_dio.dart';
import '../models/patrol_tracking_config.dart';
import 'account_service.dart';
import 'account_session_store.dart';
import 'beacon_device_password_store.dart';
import 'patrol_tracking_config_store.dart';
import 'patrol_active_round_sync.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Future<ApiResult<LoginSuccess>> login({
    required String username,
    required String password,
  }) async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }

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
        if (!await AccountSessionStore.instance.hasStoredSession()) {
          return ApiResult.failure(ApiFailure.badResponse(res));
        }
        await PatrolTrackingConfigStore.save(
          PatrolTrackingConfig.fromLoginEnvelope(data),
        );
        await BeaconDevicePasswordStore.saveFromLoginEnvelope(data);
        await PatrolActiveRoundSync.clearBackgroundAutoScanArmed();
        // BE sets `XSRF-TOKEN` on GET /accounts/me — bootstrap before STOMP/patrol APIs.
        final me = await AccountService.instance.fetchMe();
        if (!me.ok) {
          final failure = me.failure;
          if (failure?.kind == ApiFailureKind.unauthorized) {
            return ApiResult.failure(failure!);
          }
        }
        await AccountSessionStore.instance.notifySessionAuthenticated();
        final bearer = await AccountSessionStore.instance.getStoredAccessToken();
        return ApiResult.success(
          LoginSuccess(token: bearer ?? ''),
        );
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
    final uri = AppConfig.resolveApiUri('/accounts/forget-password');
    try {
      final res = await PatrolDio.instance.postUri<dynamic>(
        uri,
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

    final uri = AppConfig.resolveApiUri('/accounts/logout');
    try {
      final res = await PatrolDio.instance.getUri<dynamic>(uri);
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
        await AccountSessionStore.instance.cacheDevicePushToken(s);
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
  const LoginSuccess({required this.token});

  final String token;
}
