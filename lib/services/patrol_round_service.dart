import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../http/api_failure.dart';
import '../http/api_response.dart';
import '../http/api_result.dart';
import '../http/patrol_api_endpoints.dart';
import '../http/patrol_dio.dart';
import '../models/active_patrol_round.dart';
import '../models/patrol_round_history.dart';

class PatrolRoundService {
  PatrolRoundService._();
  static final PatrolRoundService instance = PatrolRoundService._();

  Future<ApiResult<PatrolRoundHistoryPage>> searchPatrolRounds({
    int page = 0,
    int size = 12,
  }) async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }

    try {
      final uri = AppConfig.resolveApiUri(
        PatrolApiEndpoints.patrolRoundsSearchViewPath,
      );
      final res = await PatrolDio.instance.postUri<dynamic>(
        uri,
        data: {
          'orders': <dynamic>[],
          'paged': true,
          'page': page,
          'size': size,
        },
      );
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
        if (map == null) {
          return ApiResult.failure(ApiFailure.badResponse(res));
        }
        return ApiResult.success(PatrolRoundHistoryPage.fromJson(map));
      } catch (_) {
        return ApiResult.failure(ApiFailure.badResponse(res));
      }
    } on DioException catch (e) {
      return ApiResult.failure(apiFailureFromDioException(e));
    } catch (_) {
      return ApiResult.failure(ApiFailure.network());
    }
  }

  Future<ApiResult<ActivePatrolRound?>> fetchMyActivePatrolRound() async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }

    try {
      // Use absolute Uri to avoid any Dio baseUrl timing/resolution issues
      // (can happen right after app restart).
      final uri = AppConfig.resolveApiUri('/patrol-rounds/me/active');
      final res = await PatrolDio.instance.getUri<dynamic>(uri);
      final status = res.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return ApiResult.failure(ApiFailure.unauthorized(res));
      }
      if (status == 404) {
        return ApiResult.success(null);
      }
      if (status != 200) {
        return ApiResult.failure(
          apiFailureFromHttpResponse(statusCode: status, body: res),
        );
      }

      try {
        final map = responseEnvelopeData(res.data);
        if (map == null) {
          return ApiResult.success(null);
        }
        return ApiResult.success(ActivePatrolRound.fromJson(map));
      } catch (_) {
        return ApiResult.failure(ApiFailure.badResponse(res));
      }
    } on DioException catch (e) {
      return ApiResult.failure(apiFailureFromDioException(e));
    } catch (_) {
      return ApiResult.failure(ApiFailure.network());
    }
  }
}
