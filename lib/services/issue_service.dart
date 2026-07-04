import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../http/api_failure.dart';
import '../http/api_response.dart';
import '../http/api_result.dart';
import '../http/patrol_api_endpoints.dart';
import '../http/patrol_dio.dart';
import '../models/issue.dart';

class IssueService {
  IssueService._();
  static final IssueService instance = IssueService._();

  Future<ApiResult<IssuePage>> fetchMyPostedIssues({
    int page = 0,
    int size = 10,
  }) async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }

    try {
      final uri =
          AppConfig.resolveApiUri(PatrolApiEndpoints.issuesMyPostedViewPath);
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
        return ApiResult.success(IssuePage.fromJson(map));
      } catch (_) {
        return ApiResult.failure(ApiFailure.badResponse(res));
      }
    } on DioException catch (e) {
      return ApiResult.failure(apiFailureFromDioException(e));
    } catch (_) {
      return ApiResult.failure(ApiFailure.network());
    }
  }

  Future<ApiResult<Issue>> createIssue(IssueCreateRequest body) async {
    return _submitMultipart(
      method: 'POST',
      fields: {
        'title': body.title.trim(),
        'assigneeId': body.assigneeId.trim(),
        if (body.description?.trim().isNotEmpty == true)
          'description': body.description!.trim(),
        if (body.note?.trim().isNotEmpty == true) 'note': body.note!.trim(),
        if (body.siteId != null) 'siteId': body.siteId,
      },
      filePaths: body.filePaths,
    );
  }

  Future<ApiResult<Issue>> updateIssue(IssueUpdateRequest body) async {
    return _submitMultipart(
      method: 'PUT',
      fields: {
        'id': body.id,
        'title': body.title.trim(),
        'assigneeId': body.assigneeId.trim(),
        if (body.description?.trim().isNotEmpty == true)
          'description': body.description!.trim(),
        if (body.note?.trim().isNotEmpty == true) 'note': body.note!.trim(),
        if (body.siteId != null) 'siteId': body.siteId,
      },
      filePaths: body.filePaths,
    );
  }

  Future<ApiResult<Issue>> _submitMultipart({
    required String method,
    required Map<String, dynamic> fields,
    required List<String> filePaths,
  }) async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }

    final files = <MultipartFile>[];
    for (var i = 0; i < filePaths.length; i++) {
      final path = filePaths[i];
      final filename = path.split(RegExp(r'[/\\]')).last;
      files.add(
        await MultipartFile.fromFile(
          path,
          filename: filename.isNotEmpty ? filename : 'issue_$i.jpg',
        ),
      );
    }

    final form = FormData.fromMap({
      ...fields,
      if (files.isNotEmpty) 'files': files,
    });

    try {
      final uri = AppConfig.resolveApiUri(PatrolApiEndpoints.issuesPath);
      final res = method == 'PUT'
          ? await PatrolDio.instance.putUri<dynamic>(uri, data: form)
          : await PatrolDio.instance.postUri<dynamic>(uri, data: form);
      final status = res.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return ApiResult.failure(ApiFailure.unauthorized(res));
      }
      if (status != 200 && status != 201) {
        return ApiResult.failure(
          apiFailureFromHttpResponse(statusCode: status, body: res),
        );
      }

      try {
        final map = responseEnvelopeData(res.data);
        if (map == null) {
          return ApiResult.failure(ApiFailure.badResponse(res));
        }
        return ApiResult.success(Issue.fromJson(map));
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
