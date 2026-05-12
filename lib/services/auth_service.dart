import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

const _kAccessTokenKey = 'patrol_access_token';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Future<String?> getStoredAccessToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kAccessTokenKey);
  }

  Future<void> clearToken() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kAccessTokenKey);
  }

  /// POST `/api/accounts/login` — body `{ username, password }` như FE.
  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return LoginResult.failure(LoginFailure.configMissing);
    }

    final uri = Uri.parse('$base/api/accounts/login');
    try {
      final res = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username.trim(),
              'password': password.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final token = _extractAccessToken(res.body);
        if (token != null && token.isNotEmpty) {
          final p = await SharedPreferences.getInstance();
          await p.setString(_kAccessTokenKey, token);
          return LoginResult.success(token);
        }
        return LoginResult.failure(LoginFailure.badResponse);
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
            headers: const {'Content-Type': 'application/json'},
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

  /// ResponseDto: `{ "data": { accessToken: { accessToken, ... }, ... } }`
  static String? _extractAccessToken(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final data = (json['data'] ?? json) as Object?;
      if (data is! Map<String, dynamic>) return null;

      final at = data['accessToken'];
      if (at is Map<String, dynamic>) {
        final inner = at['accessToken'];
        if (inner is String) return inner;
      }
      if (at is String) return at;
      return null;
    } catch (_) {
      return null;
    }
  }
}

enum LoginFailure { configMissing, unauthorized, network, badResponse }

class LoginResult {
  LoginResult._({this.token, this.failure});

  final String? token;
  final LoginFailure? failure;

  bool get ok => token != null;

  factory LoginResult.success(String token) =>
      LoginResult._(token: token);

  factory LoginResult.failure(LoginFailure f) =>
      LoginResult._(failure: f);
}

enum ForgotFailure { configMissing, network, server }

class ForgotResult {
  ForgotResult._({this.failure});

  final ForgotFailure? failure;

  bool get ok => failure == null;

  factory ForgotResult.success() => ForgotResult._();

  factory ForgotResult.failure(ForgotFailure f) =>
      ForgotResult._(failure: f);
}
