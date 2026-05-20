import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sps/models/check_point.dart';
import 'package:sps/utils/check_point_proximity.dart';

CheckPoint _checkpoint({
  double lat = 21.0285,
  double lng = 105.8542,
  double radius = 3,
}) {
  return CheckPoint(
    id: 1,
    siteId: 1,
    qrCode: 'CP1',
    name: 'Test',
    sequenceOrder: 1,
    active: true,
    latitude: lat,
    longitude: lng,
    radius: radius,
  );
}

void main() {
  group('netIncrementalAccuracyM', () {
    test('returns device when checkpoint accuracy missing', () {
      expect(netIncrementalAccuracyM(5, null), 5);
    });

    test('returns net when device worse than checkpoint', () {
      expect(netIncrementalAccuracyM(10, 6), 4);
    });

    test('returns null when device not worse than checkpoint', () {
      expect(netIncrementalAccuracyM(5, 8), isNull);
      expect(netIncrementalAccuracyM(5, 5), isNull);
    });
  });

  test('incremental margin: strict when GPS improved since save', () {
    final cp = _checkpoint(radius: 3);
    const deviceLat = 21.028535;
    const deviceLng = 105.854235;
    final evaluation = evaluateCheckPointProximity(
      checkpoint: cp,
      latitude: deviceLat,
      longitude: deviceLng,
      horizontalAccuracyM: netIncrementalAccuracyM(5, 8),
    );
    expect(evaluation.snapshot!.horizontalM, greaterThan(3));
    expect(evaluation.result.ok, isFalse);
  });

  test('same coordinates yield ~0 m horizontal distance', () {
    final cp = _checkpoint();
    final evaluation = evaluateCheckPointProximity(
      checkpoint: cp,
      latitude: cp.latitude!,
      longitude: cp.longitude!,
    );
    final snapshot = evaluation.snapshot!;
    expect(snapshot.horizontalM, lessThan(0.05));
    expect(snapshot.signedNorthToCheckpointM.abs(), lessThan(0.05));
    expect(snapshot.signedEastToCheckpointM.abs(), lessThan(0.05));
    expect(evaluation.result.ok, isTrue);
  });

  test('measured inside passes despite poor horizontal accuracy', () {
    final cp = _checkpoint(radius: 3);
    final evaluation = evaluateCheckPointProximity(
      checkpoint: cp,
      latitude: cp.latitude!,
      longitude: cp.longitude!,
      horizontalAccuracyM: 5,
    );
    expect(evaluation.snapshot!.horizontalM, lessThan(3));
    expect(evaluation.result.ok, isTrue);
  });

  test('measured outside but accuracy suggests possibly inside passes', () {
    final cp = _checkpoint(lat: 21.0285, lng: 105.8542, radius: 3);
    const deviceLat = 21.028535;
    const deviceLng = 105.854235;
    final evaluation = evaluateCheckPointProximity(
      checkpoint: cp,
      latitude: deviceLat,
      longitude: deviceLng,
      horizontalAccuracyM: 8,
    );
    final snapshot = evaluation.snapshot!;
    expect(snapshot.horizontalM, greaterThan(3));
    expect(evaluation.result.ok, isTrue);
  });

  test('measured outside beyond accuracy band fails', () {
    final cp = _checkpoint(radius: 3);
    const deviceLat = 21.0287;
    const deviceLng = 105.8544;
    final evaluation = evaluateCheckPointProximity(
      checkpoint: cp,
      latitude: deviceLat,
      longitude: deviceLng,
      horizontalAccuracyM: 2,
    );
    expect(evaluation.result.ok, isFalse);
    expect(
      evaluation.result.issue,
      CheckPointProximityIssue.horizontalOutOfRange,
    );
  });

  test('axis deltas match geodesic horizontal distance at short range', () {
    final cp = _checkpoint();
    const deviceLat = 21.0287;
    const deviceLng = 105.8544;
    final evaluation = evaluateCheckPointProximity(
      checkpoint: cp,
      latitude: deviceLat,
      longitude: deviceLng,
    );
    final s = evaluation.snapshot!;
    final fromAxes = math.sqrt(
      s.signedNorthToCheckpointM * s.signedNorthToCheckpointM +
          s.signedEastToCheckpointM * s.signedEastToCheckpointM,
    );
    expect(s.horizontalM, closeTo(fromAxes, 2.0));
  });
}
