import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../http/api_failure.dart';
import '../http/api_request_headers.dart';
import '../http/api_response.dart';
import '../http/api_result.dart';
import '../models/check_point.dart';

extension MySiteCheckPointsApiResult on ApiResult<MySiteCheckPointsDto> {
  List<CheckPointDto>? get points => data?.checkPoints;
}

class CheckPointService {
  CheckPointService._();
  static final CheckPointService instance = CheckPointService._();

  /// GET `/api/check-points/me/site` — site + `checkPoints` (hoặc legacy: `data` là mảng).
  Future<ApiResult<MySiteCheckPointsDto>> fetchMySiteCheckPoints() async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }

    final uri = Uri.parse('$base/api/check-points/me/site');
    try {
      final res = await http
          .get(
            uri,
            headers: await ApiRequestHeaders.build(jsonBody: false),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 401 || res.statusCode == 403) {
        return ApiResult.failure(ApiFailure.unauthorized(res.body));
      }
      if (res.statusCode != 200) {
        return ApiResult.failure(
          apiFailureFromHttpResponse(statusCode: res.statusCode, body: res.body),
        );
      }

      try {
        final map = jsonObject(res.body);
        if (map != null && map['checkPoints'] is List) {
          final dto = MySiteCheckPointsDto.fromJson(map);
          return ApiResult.success(dto);
        }

        return ApiResult.failure(ApiFailure.badResponse(res.body));
      } catch (_) {
        return ApiResult.failure(ApiFailure.badResponse(res.body));
      }
    } catch (_) {
      return ApiResult.failure(ApiFailure.network());
    }
  }

  /// PUT `/api/check-points` — body đầy đủ theo DTO check-point.
  ///
  /// Trả về `CheckPointDto` khi body 200 parse được (vd. có `qrImage` mới); `null` khi 204 hoặc không có payload.
  Future<ApiResult<CheckPointDto?>> updateCheckPoint(CheckPointDto body) async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }

    final uri = Uri.parse('$base/api/check-points');
    try {
      final res = await http
          .put(
            uri,
            headers: await ApiRequestHeaders.build(jsonBody: true),
            body: jsonEncode(body.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 401 || res.statusCode == 403) {
        return ApiResult.failure(ApiFailure.unauthorized(res.body));
      }
      if (res.statusCode != 200 && res.statusCode != 204) {
        return ApiResult.failure(
          apiFailureFromHttpResponse(statusCode: res.statusCode, body: res.body),
        );
      }
      if (res.statusCode == 204 || res.body.trim().isEmpty) {
        return ApiResult.success(null);
      }
      final map = jsonObject(res.body);
      if (map == null) {
        return ApiResult.success(null);
      }
      try {
        final dto = CheckPointDto.fromJson(map);
        if (dto.id != body.id) {
          return ApiResult.success(null);
        }
        return ApiResult.success(dto);
      } catch (_) {
        return ApiResult.success(null);
      }
    } catch (_) {
      return ApiResult.failure(ApiFailure.network());
    }
  }
}
