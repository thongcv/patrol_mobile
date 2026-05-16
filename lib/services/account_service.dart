import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../http/api_failure.dart';
import '../http/api_response.dart';
import '../http/api_result.dart';
import '../http/patrol_dio.dart';
import '../models/account_me.dart';

class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();

  Future<ApiResult<AccountMeDto>> fetchMe() async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }
    PatrolDio.syncBaseUrls();

    try {
      final res = await PatrolDio.instance.get<dynamic>('/api/accounts/me');
      final status = res.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return ApiResult.failure(ApiFailure.unauthorized(res));
      }
      if (status != 200) {
        return ApiResult.failure(
          apiFailureFromHttpResponse(statusCode: status, body: res),
        );
      }

      final map = responseEnvelopeData(res.data);
      if (map == null) {
        return ApiResult.failure(ApiFailure.badResponse(res));
      }

      try {
        final me = AccountMeDto.fromJson(map);
        return ApiResult.success(me);
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
