import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/access_token_payload.dart';
import '../config/app_config.dart';
import '../config/storage_keys.dart';
import '../http/api_failure.dart';
import '../http/api_request_headers.dart';
import '../http/api_response.dart';
import '../http/api_result.dart';

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
    final p = await SharedPreferences.getInstance();
    await p.remove(StorageKeys.accessToken);
  }

  /// Lưu FCM / push token để gửi kèm [login]; gọi khi có token (ví dụ sau khi cấu hình Firebase).
  Future<void> cacheDevicePushToken(String? token) async {
    final p = await SharedPreferences.getInstance();
    final t = token?.trim();
    if (t == null || t.isEmpty) {
      await p.remove(StorageKeys.devicePushToken);
    } else {
      await p.setString(StorageKeys.devicePushToken, t);
    }
  }

  /// POST `/api/accounts/login` — body `{ username, password, deviceToken? }` như [Credential] API.
  /// `deviceToken` là FCM ([FirebaseMessaging.getToken]); cache qua [cacheDevicePushToken].
  Future<ApiResult<LoginSuccess>> login({
    required String username,
    required String password,
  }) async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }

    final fcmToken = await _fcmTokenForLogin();

    final uri = Uri.parse('$base/api/accounts/login');
    try {
      final body = <String, dynamic>{
        'username': username.trim(),
        'password': password.trim(),
        if (fcmToken != null && fcmToken.isNotEmpty) 'deviceToken': fcmToken,
      };
      final res = await http
          .post(
            uri,
            headers: await ApiRequestHeaders.build(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonObject(res.body);
        if (data == null) {
          return ApiResult.failure(ApiFailure.badResponse(res.body));
        }
        final accessToken = _accessTokenObjectFromData(data);
        if (accessToken != null) {
          final p = await SharedPreferences.getInstance();
          await p.setString(StorageKeys.accessToken, jsonEncode(accessToken));
          return ApiResult.success(
            LoginSuccess(token: 'OK', accessToken: accessToken),
          );
        } else {
          return ApiResult.failure(ApiFailure.badResponse(res.body));
        }
      }
      return ApiResult.failure(
        apiFailureFromHttpResponse(statusCode: res.statusCode, body: res.body),
      );
    } catch (_) {
      return ApiResult.failure(ApiFailure.network());
    }
  }

  /// POST `/api/accounts/forget-password`
  Future<ApiResult<ApiUnit>> forgotPassword({
    required String email,
    required String usernameOrPhone,
  }) async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }
    final uri = Uri.parse('$base/api/accounts/forget-password');
    try {
      final res = await http
          .post(
            uri,
            headers: await ApiRequestHeaders.build(),
            body: jsonEncode({
              'email': email.trim(),
              'username': usernameOrPhone.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        return ApiResult.success(ApiUnit.instance);
      }
      return ApiResult.failure(
        apiFailureFromHttpResponse(statusCode: res.statusCode, body: res.body),
      );
    } catch (_) {
      return ApiResult.failure(ApiFailure.network());
    }
  }

  /// GET `/api/accounts/logout` — Bearer từ store; thành công khi HTTP 200 hoặc 204.
  Future<ApiResult<ApiUnit>> logout() async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }

    final uri = Uri.parse('$base/api/accounts/logout');
    try {
      final res = await http
          .get(
            uri,
            headers: await ApiRequestHeaders.build(),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200 || res.statusCode == 204) {
        return ApiResult.success(ApiUnit.instance);
      }
      return ApiResult.failure(
        apiFailureFromHttpResponse(statusCode: res.statusCode, body: res.body),
      );
    } catch (_) {
      return ApiResult.failure(ApiFailure.network());
    }
  }

  /// Token đăng ký FCM; lưu prefs khi lấy được để dùng lại nếu [getToken] tạm lỗi.
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
      // Thiếu cấu hình Firebase / quyền — fallback token đã cache (onTokenRefresh).
    }
    final p = await SharedPreferences.getInstance();
    return p.getString(StorageKeys.devicePushToken)?.trim();
  }

  /// Object JSON tại `accessToken` khi server trả map (`{ accessToken, refreshToken?, … }`).
  static Map<String, dynamic>? _accessTokenObjectFromData(
    Map<String, dynamic> data,
  ) {
    final at = data['accessToken'];
    if (at is Map<String, dynamic>) return at;
    return null;
  }
}

/// Payload đăng nhập thành công (`data.accessToken` dạng object).
class LoginSuccess {
  const LoginSuccess({required this.token, this.accessToken});

  final String token;
  final Map<String, dynamic>? accessToken;
}