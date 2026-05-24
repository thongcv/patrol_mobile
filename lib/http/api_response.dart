/// Coerces a JSON object (including Dio `Map<dynamic, dynamic>`) to [Map<String, dynamic>].
Map<String, dynamic>? jsonMapCoerce(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    try {
      return Map<String, dynamic>.from(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}

int? jsonInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

bool? jsonBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final s = value.trim().toUpperCase();
    if (s == 'Y' || s == 'TRUE' || s == '1') return true;
    if (s == 'N' || s == 'FALSE' || s == '0' || s.isEmpty) return false;
  }
  return null;
}

String? jsonStr(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

/// `data` from API envelope (JSON string or parsed map).
Map<String, dynamic>? responseEnvelopeData(dynamic data) {
  final root = jsonMapCoerce(data);
  if (root == null) return null;
  return jsonObjectFromDecoded(root);
}

/// `data` from API envelope (decoded root map).
Map<String, dynamic>? jsonObjectFromDecoded(Map<String, dynamic> json) {
  return jsonMapCoerce(json['data'] ?? json);
}
