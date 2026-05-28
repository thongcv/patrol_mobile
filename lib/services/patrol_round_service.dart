import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../http/api_failure.dart';
import '../http/api_response.dart';
import '../http/api_result.dart';
import '../http/patrol_dio.dart';
import '../models/active_patrol_round.dart';

class PatrolRoundService {
  PatrolRoundService._();
  static final PatrolRoundService instance = PatrolRoundService._();

  Future<ApiResult<ActivePatrolRound?>> fetchMyActivePatrolRound() async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }

    try {
      // Use absolute Uri to avoid any Dio baseUrl timing/resolution issues
      // (can happen right after app restart).
      final uri = AppConfig.resolveApiUri('/api/patrol-rounds/me/active');
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
