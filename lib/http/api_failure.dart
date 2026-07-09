import 'package:dio/dio.dart';

import 'api_response.dart';

/// Shared error classification for all API calls in the app.
enum ApiFailureKind {
  configMissing,
  network,
  unauthorized,
  badResponse,
  server,
}

/// Unified API error: [kind] + backend message (`data.errors[].message`) when present.
class ApiFailure {
  const ApiFailure(this.kind, {this.serverMessage});

  final ApiFailureKind kind;

  /// Joined `message` values from `data.errors` (backend response).
  final String? serverMessage;

  static const ApiFailure configMissing =
      ApiFailure(ApiFailureKind.configMissing);

  static ApiFailure network({String? serverMessage}) =>
      ApiFailure(ApiFailureKind.network, serverMessage: serverMessage);

  static ApiFailure unauthorized(dynamic body) => ApiFailure(
        ApiFailureKind.unauthorized,
        serverMessage: parseBackendErrorMessages(body),
      );

  static ApiFailure badResponse(dynamic body) => ApiFailure(
        ApiFailureKind.badResponse,
        serverMessage: parseBackendErrorMessages(body),
      );

  /// Unsuccessful HTTP error (excludes 401/403 — use [unauthorized]).
  static ApiFailure fromHttpError(dynamic body) => ApiFailure(
        ApiFailureKind.server,
        serverMessage: parseBackendErrorMessages(body),
      );

  /// Prefers backend message; otherwise fallback string by [kind].
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

/// Extracts `data.errors[].message` — [body] is JSON string or parsed map.
String? parseBackendErrorMessages(dynamic body) {
  try {
    final data = responseEnvelopeData(body);
    if (data == null) return null;
    final errors = data['errors'];
    if (errors is! List<dynamic>) return null;
    final out = <String>[];
    for (final e in errors) {
      final em = jsonMapCoerce(e);
      if (em == null) continue;
      final m = em['message']?.toString().trim();
      if (m != null && m.isNotEmpty) out.add(m);
    }
    if (out.isEmpty) return null;
    return out.join('\n');
  } catch (_) {
    return null;
  }
}

/// Classifies error from HTTP status + body (backend message extracted when present).
ApiFailure apiFailureFromDioException(DioException e) {
  final response = e.response;
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return ApiFailure.network(serverMessage: e.message);
    default:
      break;
  }

  final res = response;
  if (res == null) {
    return ApiFailure.network(serverMessage: e.message);
  }
  final code = res.statusCode ?? 0;
  return apiFailureFromHttpResponse(statusCode: code, body: res.data);
}

ApiFailure apiFailureFromHttpResponse({
  required int statusCode,
  required dynamic body,
}) {
  if (statusCode == 401 || statusCode == 403) {
    return ApiFailure.unauthorized(body);
  }
  if (statusCode < 200 || statusCode >= 300) {
    return ApiFailure.fromHttpError(body);
  }
  return ApiFailure.badResponse(body);
}
