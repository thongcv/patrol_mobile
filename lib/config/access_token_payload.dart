import 'dart:convert';

/// Parse giá trị lưu trong prefs: JSON object `{ accessToken, … }`.
/// Hỗ trợ bản cũ lưu JWT thuần (một chuỗi).
abstract final class AccessTokenPayload {
  AccessTokenPayload._();

  static String? getAccessTokenStored(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (t.startsWith('{')) {
      try {
        final decoded = jsonDecode(t);
        if (decoded is Map<String, dynamic>) {
          final inner = decoded['accessToken'];
          if (inner is String && inner.isNotEmpty) return inner;
        }
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
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }
}
