import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../http/api_response.dart';
import 'storage_keys.dart';

/// Parses prefs value: JSON `data` object from login/refresh (same as FE localStorage).
/// Supports legacy plain JWT string storage.
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

  /// Body `token` for POST refresh — FE: `JSON.parse(localStorage.getItem(tokenKey))`.
  static Object? refreshTokenForRequestBody(String? raw) {
    final m = mapFromStored(raw);
    if (m != null && m.isNotEmpty) return m;
    final t = raw?.trim();
    if (t == null || t.isEmpty || t.startsWith('{')) return null;
    return t;
  }

  /// Persists prefs after login/refresh — like FE `storeAuth(data.accessToken, …)`:
  /// prefers nested token in `data.accessToken`, not the full envelope (`path`, …).
  static Map<String, dynamic>? persistableBlobFromApiEnvelope(
    Map<String, dynamic>? envelope,
  ) {
    if (envelope == null || envelope.isEmpty) return null;

    final nestedAccess = jsonMapCoerce(envelope['accessToken']);
    if (nestedAccess != null && _looksLikeAuthPayload(nestedAccess)) {
      return nestedAccess;
    }

    if (_looksLikeAuthPayload(envelope)) {
      return Map<String, dynamic>.from(envelope);
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

  /// `accountId` from JWT claim (payload segment).
  static String? accountIdFromJwt(String jwt) {
    final parts = jwt.trim().split('.');
    if (parts.length < 2) return null;
    try {
      var segment = parts[1];
      final mod = segment.length % 4;
      if (mod == 1) return null;
      if (mod > 0) segment = segment.padRight(segment.length + (4 - mod), '=');
      final claims = jsonMapCoerce(jsonDecode(utf8.decode(base64Url.decode(segment))));
      if (claims == null) return null;
      return jsonStr(claims['accountId']);
    } catch (_) {
      return null;
    }
  }
}
