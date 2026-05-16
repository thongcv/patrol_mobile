import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../http/api_response.dart';
import 'storage_keys.dart';

/// Parse giá trị lưu trong prefs: JSON object `data` từ login/refresh (giống FE localStorage).
/// Hỗ trợ bản cũ lưu JWT thuần (một chuỗi).
abstract final class AccessTokenPayload {
  AccessTokenPayload._();

  /// Bearer JWT — FE: `newToken?.accessToken || newToken?.token`.
  static String? getAccessTokenStored(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (t.startsWith('{')) {
      try {
        final decoded = jsonDecode(t);
        final m = jsonMapCoerce(decoded);
        if (m != null) return bearerJwtFromAuthMap(m);
      } catch (_) {}
      return null;
    }
    return t;
  }

  static Map<String, dynamic>? mapFromStored(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty || !t.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(t);
      return jsonMapCoerce(decoded);
    } catch (_) {}
    return null;
  }

  /// Body `token` khi POST refresh — FE: `JSON.parse(localStorage.getItem(tokenKey))`.
  static Object? refreshTokenForRequestBody(String? raw) {
    final m = mapFromStored(raw);
    if (m != null && m.isNotEmpty) return m;
    final t = raw?.trim();
    if (t == null || t.isEmpty || t.startsWith('{')) return null;
    return t;
  }

  /// Lưu prefs sau login/refresh: cả object `data` (không chỉ nested map).
  static Map<String, dynamic>? persistableBlobFromApiEnvelope(
    Map<String, dynamic>? envelope,
  ) {
    if (envelope == null || envelope.isEmpty) return null;

    if (_looksLikeAuthPayload(envelope)) {
      return Map<String, dynamic>.from(envelope);
    }

    final nested = envelope['accessToken'];
    if (nested is Map<String, dynamic>) return nested;
    if (nested is Map) {
      try {
        return Map<String, dynamic>.from(nested);
      } catch (_) {}
    }
    return null;
  }

  static Map<String, dynamic>? persistableBlobAfterRefreshRoot(
    Map<String, dynamic> root,
  ) {
    final data = jsonObjectFromDecoded(root);
    return persistableBlobFromApiEnvelope(data);
  }

  static Future<void> clearStored() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(StorageKeys.accessToken);
  }

  static bool _looksLikeAuthPayload(Map<String, dynamic> m) {
    return m.containsKey('accessToken') ||
        m.containsKey('token') ||
        m.containsKey('refreshToken');
  }

  static String? bearerJwtFromAuthMap(Map<String, dynamic> m) {
    final at = m['accessToken'];
    if (at is String && at.isNotEmpty) return at;
    if (at is Map) {
      final inner = at['accessToken'] ?? at['token'];
      if (inner is String && inner.isNotEmpty) return inner;
    }
    final token = m['token'];
    if (token is String && token.isNotEmpty) return token;
    return null;
  }
}
