import 'package:flutter_test/flutter_test.dart';
import 'package:sps/http/api_response.dart';
import 'package:sps/models/patrol_tracking_config.dart';
import 'package:sps/utils/check_point_proximity.dart';

void main() {
  test('login envelope parses data.config.autoScanMatchOrder nearest', () {
    final body = <String, dynamic>{
      'transactionTime': '2026-06-02T10:50:02.782Z',
      'status': 'OK',
      'data': <String, dynamic>{
        'accessToken': <String, dynamic>{
          'accessToken': 'jwt',
          'refreshToken': 'jwt',
        },
        'config': <String, dynamic>{
          'background': true,
          'socket': true,
          'minMoveM': 0.0,
          'backgroundAutoScan': true,
          'updateIntervalMs': 1000,
          'minUpdateIntervalMs': 800,
          'autoScanMatchOrder': 'nearest',
        },
      },
    };

    final data = responseEnvelopeData(body);
    expect(data, isNotNull);

    final cfg = PatrolTrackingConfig.fromLoginEnvelope(data);
    expect(cfg.autoScanMatchOrder, 'nearest');
    expect(cfg.checkPointMatchOrder, CheckPointMatchOrder.nearest);
    expect(
      cfg.shiftWindowGraceMinutes,
      PatrolTrackingConfig.defaultShiftWindowGraceMinutes,
    );
  });

  test('login envelope parses shiftWindowGraceMinutes', () {
    final body = <String, dynamic>{
      'data': <String, dynamic>{
        'config': <String, dynamic>{
          'shiftWindowGraceMinutes': 20,
        },
      },
    };

    final cfg = PatrolTrackingConfig.fromLoginEnvelope(
      Map<String, dynamic>.from(body['data'] as Map),
    );
    expect(cfg.shiftWindowGraceMinutes, 20);
  });
}
