import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../http/api_failure.dart';
import '../http/api_response.dart';
import '../http/api_result.dart';
import '../http/patrol_api_endpoints.dart';
import '../http/patrol_dio.dart';
import '../models/account_me.dart';
import 'account_session_store.dart';

class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();

  Future<ApiResult<AccountMe>> fetchMe() async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }
    try {
      final meUri = AppConfig.resolveApiUri(PatrolApiEndpoints.accountsMePath);
      final res = await PatrolDio.instance.getUri<dynamic>(meUri);
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
        final me = AccountMe.fromJson(map);
        await AccountSessionStore.instance.applyFromAccountMe(me);
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

  /// `PUT /accounts/user-info` — payload only; caller should reload `/accounts/me`.
  Future<ApiResult<ApiUnit>> updateUserInfo({
    required int id,
    required String name,
    required String email,
    required String phone,
    required String address,
    required String note,
  }) async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }

    try {
      final uri =
          AppConfig.resolveApiUri(PatrolApiEndpoints.accountsUserInfoPath);
      final res = await PatrolDio.instance.putUri<dynamic>(
        uri,
        data: {
          'id': id,
          'name': name,
          'email': email,
          'phone': phone,
          'address': address,
          'note': note,
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
      return ApiResult.success(ApiUnit.instance);
    } on DioException catch (e) {
      return ApiResult.failure(apiFailureFromDioException(e));
    } catch (_) {
      return ApiResult.failure(ApiFailure.network());
    }
  }

  /// Avatar upload multipart field `file` — returns new `imageUrl`.
  Future<ApiResult<String>> uploadAvatar(String filePath) async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }
    final path = filePath.trim();
    if (path.isEmpty) {
      return ApiResult.failure(ApiFailure.badResponse(null));
    }

    final filename = path.split(RegExp(r'[/\\]')).last;
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        path,
        filename: filename.isNotEmpty ? filename : 'avatar.jpg',
      ),
    });

    try {
      final uri = AppConfig.resolveApiUri(PatrolApiEndpoints.accountsAvatarPath);
      final res = await PatrolDio.instance.putUri<dynamic>(uri, data: form);
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
      final imageUrl = jsonStr(map?['imageUrl']);
      if (imageUrl == null) {
        return ApiResult.failure(ApiFailure.badResponse(res));
      }
      return ApiResult.success(imageUrl);
    } on DioException catch (e) {
      return ApiResult.failure(apiFailureFromDioException(e));
    } catch (_) {
      return ApiResult.failure(ApiFailure.network());
    }
  }
}
