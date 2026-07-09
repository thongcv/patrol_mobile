import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../http/api_failure.dart';
import '../http/api_response.dart';
import '../http/api_result.dart';
import '../http/patrol_api_endpoints.dart';
import '../http/patrol_dio.dart';
import '../models/site.dart';

class SiteService {
  SiteService._();
  static final SiteService instance = SiteService._();

  Future<ApiResult<List<Site>>> fetchAccessibleSites() async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }

    try {
      final uri =
          AppConfig.resolveApiUri(PatrolApiEndpoints.sitesAccessiblePath);
      final res = await PatrolDio.instance.getUri<dynamic>(uri);
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
        final list = responseEnvelopeList(res.data);
        if (list == null) {
          return ApiResult.failure(ApiFailure.badResponse(res));
        }
        final sites = list
            .map(jsonMapCoerce)
            .whereType<Map<String, dynamic>>()
            .map(Site.fromJson)
            .where((s) => s.id > 0)
            .toList();
        return ApiResult.success(sites);
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
