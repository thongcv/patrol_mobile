import 'dart:convert';

/// Bóc `data` từ body JSON `ResponseDto` (hoặc map gốc nếu không có `data`).
Map<String, dynamic>? jsonObject(String body) {
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final data = json['data'] ?? json;
    if (data is Map<String, dynamic>) return data;
    return null;
  } catch (_) {
    return null;
  }
}

/// Bóc `data` khi API trả về mảng (ví dụ danh sách check-point).
List<Map<String, dynamic>>? jsonList(String body) {
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final data = json['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return null;
  } catch (_) {
    return null;
  }
}
