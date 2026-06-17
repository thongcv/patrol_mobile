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
      cfg.shiftWindowStartGraceMinutes,
      PatrolTrackingConfig.defaultShiftWindowStartGraceMinutes,
    );
    expect(
      cfg.shiftWindowEndGraceMinutes,
      PatrolTrackingConfig.defaultShiftWindowEndGraceMinutes,
    );
    expect(
      cfg.overdueGraceMinutes,
      PatrolTrackingConfig.defaultOverdueGraceMinutes,
    );
  });

  test('login envelope parses overdueGraceMinutes', () {
    final body = <String, dynamic>{
      'data': <String, dynamic>{
        'config': <String, dynamic>{
          'overdueGraceMinutes': 30,
        },
      },
    };

    final cfg = PatrolTrackingConfig.fromLoginEnvelope(
      Map<String, dynamic>.from(body['data'] as Map),
    );
    expect(cfg.overdueGraceMinutes, 30);
  });

  test('login envelope parses shift window start/end grace minutes', () {
    final body = <String, dynamic>{
      'data': <String, dynamic>{
        'config': <String, dynamic>{
          'shiftWindowStartGraceMinutes': 10,
          'shiftWindowEndGraceMinutes': 20,
        },
      },
    };

    final cfg = PatrolTrackingConfig.fromLoginEnvelope(
      Map<String, dynamic>.from(body['data'] as Map),
    );
    expect(cfg.shiftWindowStartGraceMinutes, 10);
    expect(cfg.shiftWindowEndGraceMinutes, 20);
  });

  test('login envelope legacy shiftWindowGraceMinutes applies to both sides', () {
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
    expect(cfg.shiftWindowStartGraceMinutes, 20);
    expect(cfg.shiftWindowEndGraceMinutes, 20);
  });
}
