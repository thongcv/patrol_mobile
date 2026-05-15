import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../http/api_failure.dart';
import '../http/api_request_headers.dart';
import '../http/api_response.dart';
import '../http/api_result.dart';
import '../models/active_patrol_round.dart';

class PatrolRoundService {
  PatrolRoundService._();
  static final PatrolRoundService instance = PatrolRoundService._();

  /// GET `/api/patrol-rounds/me/active` — ca + vòng + danh sách điểm.
  Future<ApiResult<ActivePatrolRoundDto?>> fetchMyActivePatrolRound() async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }

    final uri = Uri.parse('$base/api/patrol-rounds/me/active');
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
      if (res.statusCode == 404) {
        return ApiResult.success(null);
      }
      if (res.statusCode != 200) {
        return ApiResult.failure(
          apiFailureFromHttpResponse(statusCode: res.statusCode, body: res.body),
        );
      }

      try {
        final map = jsonObject(res.body);
        if (map == null) {
          return ApiResult.success(null);
        }
        return ApiResult.success(ActivePatrolRoundDto.fromJson(map));
      } catch (_) {
        return ApiResult.failure(ApiFailure.badResponse(res.body));
      }
    } catch (_) {
      return ApiResult.failure(ApiFailure.network());
    }
  }
}
