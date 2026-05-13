import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../http/api_request_headers.dart';
import '../http/api_response.dart';
import '../models/check_point.dart';

enum CheckPointsMeSiteFailure {
  configMissing,
  unauthorized,
  network,
  badResponse,
}

class CheckPointsMeSiteResult {
  CheckPointsMeSiteResult._({this.data, this.failure});

  final MySiteCheckPointsDto? data;
  final CheckPointsMeSiteFailure? failure;

  bool get ok => data != null;

  List<CheckPointDto>? get points => data?.checkPoints;

  factory CheckPointsMeSiteResult.success(MySiteCheckPointsDto data) =>
      CheckPointsMeSiteResult._(data: data);

  factory CheckPointsMeSiteResult.failure(CheckPointsMeSiteFailure f) =>
      CheckPointsMeSiteResult._(failure: f);
}

enum CheckPointUpdateFailure {
  configMissing,
  unauthorized,
  network,
  badResponse,
}

class CheckPointUpdateResult {
  CheckPointUpdateResult._({this.failure});

  final CheckPointUpdateFailure? failure;

  bool get ok => failure == null;

  factory CheckPointUpdateResult.success() => CheckPointUpdateResult._();

  factory CheckPointUpdateResult.failure(CheckPointUpdateFailure f) =>
      CheckPointUpdateResult._(failure: f);
}

class CheckPointService {
  CheckPointService._();
  static final CheckPointService instance = CheckPointService._();

  /// GET `/api/check-points/me/site` — site + `checkPoints` (hoặc legacy: `data` là mảng).
  Future<CheckPointsMeSiteResult> fetchMySiteCheckPoints() async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return CheckPointsMeSiteResult.failure(CheckPointsMeSiteFailure.configMissing);
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
        return CheckPointsMeSiteResult.failure(CheckPointsMeSiteFailure.unauthorized);
      }
      if (res.statusCode != 200) {
        return CheckPointsMeSiteResult.failure(CheckPointsMeSiteFailure.badResponse);
      }

      try {
        final map = parseApiResponseData(res.body);
        if (map != null && map['checkPoints'] is List) {
          final dto = MySiteCheckPointsDto.fromJson(map);
          return CheckPointsMeSiteResult.success(dto);
        }

        final legacyList = parseApiResponseDataList(res.body);
        if (legacyList != null) {
          if (legacyList.isEmpty) {
            return CheckPointsMeSiteResult.success(
              MySiteCheckPointsDto(siteId: 0, checkPoints: []),
            );
          }
          final points = legacyList.map(CheckPointDto.fromJson).toList()
            ..sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));
          return CheckPointsMeSiteResult.success(
            MySiteCheckPointsDto(
              siteId: points.first.siteId,
              checkPoints: points,
            ),
          );
        }

        return CheckPointsMeSiteResult.failure(CheckPointsMeSiteFailure.badResponse);
      } catch (_) {
        return CheckPointsMeSiteResult.failure(CheckPointsMeSiteFailure.badResponse);
      }
    } catch (_) {
      return CheckPointsMeSiteResult.failure(CheckPointsMeSiteFailure.network);
    }
  }

  /// PUT `/api/check-points` — body đầy đủ theo DTO check-point.
  Future<CheckPointUpdateResult> updateCheckPoint(CheckPointDto body) async {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) {
      return CheckPointUpdateResult.failure(CheckPointUpdateFailure.configMissing);
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
        return CheckPointUpdateResult.failure(CheckPointUpdateFailure.unauthorized);
      }
      if (res.statusCode != 200 && res.statusCode != 204) {
        return CheckPointUpdateResult.failure(CheckPointUpdateFailure.badResponse);
      }
      return CheckPointUpdateResult.success();
    } catch (_) {
      return CheckPointUpdateResult.failure(CheckPointUpdateFailure.network);
    }
  }
}
