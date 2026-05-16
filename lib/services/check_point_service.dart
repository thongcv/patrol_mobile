import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../http/api_failure.dart';
import '../http/api_response.dart';
import '../http/api_result.dart';
import '../http/patrol_dio.dart';
import '../models/check_point.dart';

extension MySiteCheckPointsApiResult on ApiResult<MySiteCheckPointsDto> {
  List<CheckPoint>? get points => data?.checkPoints;
}

class CheckPointService {
  CheckPointService._();
  static final CheckPointService instance = CheckPointService._();

  Future<ApiResult<MySiteCheckPointsDto>> fetchMySiteCheckPoints() async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }
    PatrolDio.syncBaseUrls();

    try {
      final res =
          await PatrolDio.instance.get<dynamic>('/api/check-points/me/site');
      final status = res.statusCode ?? 0;

      if (status == 401 || status == 403) {
        return ApiResult.failure(ApiFailure.unauthorized(res));
      }
      if (status != 200) {
        return ApiResult.failure(
          apiFailureFromHttpResponse(statusCode: status, body: res),
        );
      }

      try {
        final map = responseEnvelopeData(res.data);
        if (map != null && map['checkPoints'] is List) {
          final dto = MySiteCheckPointsDto.fromJson(map);
          return ApiResult.success(dto);
        }

        return ApiResult.failure(ApiFailure.badResponse(res));
      } catch (_) {
        return ApiResult.failure(ApiFailure.badResponse(res));
      }
    } on DioException catch (e) {
      return ApiResult.failure(apiFailureFromDioException(e));
    } catch (_) {
      return ApiResult.failure(ApiFailure.network());
    }
  }

  Future<ApiResult<CheckPoint?>> updateCheckPoint(CheckPoint body) async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }
    PatrolDio.syncBaseUrls();

    try {
      final res = await PatrolDio.instance.put<dynamic>(
        '/api/check-points',
        data: body.toJson(),
      );

      final status = res.statusCode ?? 0;

      if (status == 401 || status == 403) {
        return ApiResult.failure(ApiFailure.unauthorized(res));
      }
      if (status != 200 && status != 204) {
        return ApiResult.failure(
          apiFailureFromHttpResponse(statusCode: status, body: res),
        );
      }

      final d = res.data;
      final noPayload = status == 204 ||
          d == null ||
          (d is String && d.trim().isEmpty) ||
          (d is Map && d.isEmpty);
      if (noPayload) {
        return ApiResult.success(null);
      }

      final map = responseEnvelopeData(d);
      if (map == null) {
        return ApiResult.success(null);
      }
      try {
        final dto = CheckPoint.fromJson(map);
        if (dto.id != body.id) {
          return ApiResult.success(null);
        }
        return ApiResult.success(dto);
      } catch (_) {
        return ApiResult.success(null);
      }
    } on DioException catch (e) {
      return ApiResult.failure(apiFailureFromDioException(e));
    } catch (_) {
      return ApiResult.failure(ApiFailure.network());
    }
  }
}
