import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../http/api_failure.dart';
import '../http/api_result.dart';
import '../http/patrol_dio.dart';

class PatrolLogSubmit {
  PatrolLogSubmit({
    required this.roundId,
    required this.checkpointId,
    this.siteId,
    this.accountId,
    required this.scanTime,
    required this.latitude,
    required this.longitude,
    this.gpsAltitude,
    this.baroAltitude,
    this.note,
    this.verified,
    this.photoPaths = const [],
  });

  final int roundId;
  final int checkpointId;
  final int? siteId;
  final String? accountId;
  final DateTime scanTime;
  final double latitude;
  final double longitude;
  final double? gpsAltitude;
  final double? baroAltitude;
  final String? note;
  final bool? verified;
  final List<String> photoPaths;
}

class PatrolLogService {
  PatrolLogService._();
  static final PatrolLogService instance = PatrolLogService._();

  Future<ApiResult<void>> createPatrolLog(PatrolLogSubmit body) async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return ApiResult.failure(ApiFailure.configMissing);
    }
    PatrolDio.syncBaseUrls();

    final fields = <String, dynamic>{
      'roundId': body.roundId,
      'checkpointId': body.checkpointId,
      'siteId': body.siteId,
      'scanTime': body.scanTime.toUtc().toIso8601String(),
      'latitude': body.latitude,
      'longitude': body.longitude,
    };
    final accountId = body.accountId?.trim();
    if (accountId != null && accountId.isNotEmpty) {
      fields['accountId'] = accountId;
    }
    if (body.gpsAltitude != null && body.gpsAltitude!.isFinite) {
      fields['gpsAltitude'] = body.gpsAltitude;
    }
    if (body.baroAltitude != null && body.baroAltitude!.isFinite) {
      fields['baroAltitude'] = body.baroAltitude;
    }
    if (body.note != null && body.note!.trim().isNotEmpty) {
      fields['note'] = body.note!.trim();
    }
    if (body.verified != null) {
      fields['verified'] = body.verified;
    }

    final files = <MultipartFile>[];
    for (var i = 0; i < body.photoPaths.length; i++) {
      final path = body.photoPaths[i];
      files.add(
        await MultipartFile.fromFile(
          path,
          filename: '${body.roundId}_scan_$i.jpg',
        ),
      );
    }

    final form = FormData.fromMap({
      ...fields,
      if (files.isNotEmpty) 'files': files,
    });

    try {
      final res = await PatrolDio.instance.post<dynamic>(
        '/api/patrol-logs',
        data: form,
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
      return ApiResult.success(null);
    } on DioException catch (e) {
      return ApiResult.failure(apiFailureFromDioException(e));
    } catch (_) {
      return ApiResult.failure(ApiFailure.network());
    }
  }
}
