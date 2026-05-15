import 'dart:convert';

/// Phân loại lỗi chung cho mọi gọi API trong app.
enum ApiFailureKind {
  configMissing,
  network,
  unauthorized,
  badResponse,
  server,
}

/// Lỗi API thống nhất: [kind] + thông điệp từ BE (`data.errors[].message`) nếu có.
class ApiFailure {
  const ApiFailure(this.kind, {this.serverMessage});

  final ApiFailureKind kind;

  /// Ghép các `message` trong `data.errors` (BE trả về).
  final String? serverMessage;

  static const ApiFailure configMissing = ApiFailure(ApiFailureKind.configMissing);

  static ApiFailure network({String? serverMessage}) =>
      ApiFailure(ApiFailureKind.network, serverMessage: serverMessage);

  static ApiFailure unauthorized(String body) => ApiFailure(
        ApiFailureKind.unauthorized,
        serverMessage: parseBackendErrorMessages(body),
      );

  static ApiFailure badResponse(String body) => ApiFailure(
        ApiFailureKind.badResponse,
        serverMessage: parseBackendErrorMessages(body),
      );

  /// Lỗi HTTP không thành công (không gồm 401/403 — dùng [unauthorized]).
  static ApiFailure fromHttpError(String body) => ApiFailure(
        ApiFailureKind.server,
        serverMessage: parseBackendErrorMessages(body),
      );

  /// Ưu tiên thông điệp BE; không có thì dùng chuỗi fallback theo [kind].
  String userMessage({
    required String configMissing,
    required String network,
    required String unauthorized,
    required String badResponse,
    required String server,
  }) {
    final m = serverMessage?.trim();
    if (m != null && m.isNotEmpty) return m;
    return switch (kind) {
      ApiFailureKind.configMissing => configMissing,
      ApiFailureKind.network => network,
      ApiFailureKind.unauthorized => unauthorized,
      ApiFailureKind.badResponse => badResponse,
      ApiFailureKind.server => server,
    };
  }
}

/// Bóc `data.errors[].message` từ body JSON (ResponseDto lỗi).
String? parseBackendErrorMessages(String body) {
  if (body.isEmpty) return null;
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final data = json['data'];
    if (data is! Map<String, dynamic>) return null;
    final errors = data['errors'];
    if (errors is! List<dynamic>) return null;
    final out = <String>[];
    for (final e in errors) {
      if (e is Map<String, dynamic>) {
        final m = e['message']?.toString().trim();
        if (m != null && m.isNotEmpty) out.add(m);
      }
    }
    if (out.isEmpty) return null;
    return out.join('\n');
  } catch (_) {
    return null;
  }
}

/// Phân loại lỗi từ HTTP status + body (đã bóc message BE khi có).
ApiFailure apiFailureFromHttpResponse({
  required int statusCode,
  required String body,
}) {
  if (statusCode == 401 || statusCode == 403) {
    return ApiFailure.unauthorized(body);
  }
  if (statusCode < 200 || statusCode >= 300) {
    return ApiFailure.fromHttpError(body);
  }
  return ApiFailure.badResponse(body);
}
