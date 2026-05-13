import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/access_token_payload.dart';
import '../config/app_config.dart';
import '../config/storage_keys.dart';
import '../http/api_request_headers.dart';
import '../http/api_response.dart';

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
  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return LoginResult.failure(LoginFailure.configMissing);
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
        final data = parseApiResponseData(res.body);
        if (data == null) {
          return LoginResult.failure(LoginFailure.badResponse);
        }
        final accessToken = _accessTokenObjectFromData(data);
        if (accessToken != null) {
          final p = await SharedPreferences.getInstance();
          await p.setString(StorageKeys.accessToken, jsonEncode(accessToken));
          return LoginResult.success("OK", accessToken: accessToken);
        } else {
          return LoginResult.failure(LoginFailure.badResponse);
        }
      }
      return LoginResult.failure(LoginFailure.unauthorized);
    } catch (_) {
      return LoginResult.failure(LoginFailure.network);
    }
  }

  /// POST `/api/accounts/forget-password`
  Future<ForgotResult> forgotPassword({
    required String email,
    required String usernameOrPhone,
  }) async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ForgotResult.failure(ForgotFailure.configMissing);
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
        return ForgotResult.success();
      }
      return ForgotResult.failure(ForgotFailure.server);
    } catch (_) {
      return ForgotResult.failure(ForgotFailure.network);
    }
  }

  /// POST `/api/accounts/logout` — Bearer từ store; [LogoutResult.ok] khi HTTP 200 hoặc 204.
  Future<LogoutResult> logout() async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return LogoutResult.failure(LogoutFailure.configMissing);
    }

    final uri = Uri.parse('$base/api/accounts/logout');
    try {
      final res = await http
          .get(
            uri,
            headers: await ApiRequestHeaders.build()
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200 || res.statusCode == 204) {
        return LogoutResult.success();
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return LogoutResult.failure(LogoutFailure.unauthorized);
      }
      return LogoutResult.failure(LogoutFailure.server);
    } catch (_) {
      return LogoutResult.failure(LogoutFailure.network);
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

enum LoginFailure { configMissing, unauthorized, network, badResponse }

class LoginResult {
  LoginResult._({this.token, this.accessToken, this.failure});

  final String? token;

  /// Payload đầy đủ từ API tại `data.accessToken` (khi là object).
  final Map<String, dynamic>? accessToken;

  final LoginFailure? failure;

  bool get ok => token != null;

  factory LoginResult.success(
    String token, {
    Map<String, dynamic>? accessToken,
  }) => LoginResult._(token: token, accessToken: accessToken);

  factory LoginResult.failure(LoginFailure f) => LoginResult._(failure: f);
}

enum ForgotFailure { configMissing, network, server }

class ForgotResult {
  ForgotResult._({this.failure});

  final ForgotFailure? failure;

  bool get ok => failure == null;

  factory ForgotResult.success() => ForgotResult._();

  factory ForgotResult.failure(ForgotFailure f) => ForgotResult._(failure: f);
}

enum LogoutFailure { configMissing, network, unauthorized, server }

class LogoutResult {
  LogoutResult._({this.failure});

  final LogoutFailure? failure;

  bool get ok => failure == null;

  factory LogoutResult.success() => LogoutResult._();

  factory LogoutResult.failure(LogoutFailure f) => LogoutResult._(failure: f);
}
