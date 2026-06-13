import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../models/check_point.dart';
import 'device_location.dart';

/// Default radius (m) when checkpoint has no configured `radius`.
const double kDefaultCheckPointRadiusM = 3;

/// Incremental accuracy margin: [deviceM] minus accuracy saved at checkpoint [checkpointM].
///
/// Widens only when current GPS is worse than at save (`device > checkpoint`).
/// Delta ≤ 0 → `null` (strict distance vs [allowedRadiusM], no ε added).
double? netIncrementalAccuracyM(double? deviceM, double? checkpointM) {
  if (deviceM == null || !deviceM.isFinite || deviceM <= 0) return null;
  final cp = checkpointM;
  if (cp != null && cp.isFinite) {
    final net = deviceM - cp;
    return net > 0 ? net : null;
  }
  return deviceM;
}

/// North–south offset (m) along meridian; positive = checkpoint north of `from`.
double _signedGeodesicNorthM(
  double fromLat,
  double fromLng,
  double toLat,
  double toLng,
) {
  final d = Geolocator.distanceBetween(fromLat, fromLng, toLat, fromLng);
  return toLat >= fromLat ? d : -d;
}

/// East–west offset (m) along parallel; positive = checkpoint east of `from`.
double _signedGeodesicEastM(
  double fromLat,
  double fromLng,
  double toLat,
  double toLng,
) {
  final d = Geolocator.distanceBetween(fromLat, fromLng, fromLat, toLng);
  return toLng >= fromLng ? d : -d;
}

/// Horizontal distance (m) to checkpoint; `null` if checkpoint has no coordinates.
double? horizontalDistanceToCheckPoint(
  CheckPoint checkpoint,
  double latitude,
  double longitude,
) {
  if (!checkpoint.hasCoordinates) return null;
  return Geolocator.distanceBetween(
    checkpoint.latitude!,
    checkpoint.longitude!,
    latitude,
    longitude,
  );
}

enum CheckPointProximityIssue {
  noCheckpointCoordinates,
  horizontalOutOfRange,
  gpsAltitudeOutOfRange,
  baroAltitudeOutOfRange,
  baroAltitudePending,
}

class CheckPointProximityResult {
  const CheckPointProximityResult.ok()
    : ok = true,
      issue = null,
      distanceM = null,
      allowedRadiusM = null;

  const CheckPointProximityResult.failure({
    required this.issue,
    this.distanceM,
    this.allowedRadiusM,
  }) : ok = false;

  final bool ok;
  final CheckPointProximityIssue? issue;
  final double? distanceM;
  final double? allowedRadiusM;
}

/// Device vs checkpoint comparison details (navigation popup).
class CheckPointProximitySnapshot {
  const CheckPointProximitySnapshot({
    required this.checkpointLat,
    required this.checkpointLng,
    required this.deviceLat,
    required this.deviceLng,
    required this.signedNorthToCheckpointM,
    required this.signedEastToCheckpointM,
    required this.horizontalM,
    required this.allowedRadiusM,
    this.slantRangeM,
    this.horizontalAccuracyM,
    this.gpsAltitudeAccuracyM,
    this.checkpointAltitude,
    this.deviceAltitude,
    this.signedAltitudeDeltaM,
    this.usesBaroAltitude = false,
  });

  final double checkpointLat;
  final double checkpointLng;
  final double? checkpointAltitude;
  final double deviceLat;
  final double deviceLng;
  final double? deviceAltitude;

  /// Positive = need to move north (m) to reach checkpoint.
  final double signedNorthToCheckpointM;

  /// Positive = need to move east (m) to reach checkpoint.
  final double signedEastToCheckpointM;

  /// Geodesic horizontal distance (m) — ground line.
  final double horizontalM;

  /// Slant range √(horizontal² + altitude²) when altitude is available.
  final double? slantRangeM;

  /// Horizontal error from GPS (`Position.accuracy`), if any.
  final double? horizontalAccuracyM;

  /// GPS altitude error (`Position.altitudeAccuracy`), if any.
  final double? gpsAltitudeAccuracyM;
  final double? signedAltitudeDeltaM;
  final double allowedRadiusM;
  final bool usesBaroAltitude;
}

/// Within this distance (m), north/east/altitude hints read as on-target.
const double kCheckPointOnTargetThresholdM = 0.05;

/// Formats distance (m) for UI and TTS — one decimal, no rounding to integer.
String formatPatrolDistanceM(double absM) {
  if (absM < kCheckPointOnTargetThresholdM) return '0';
  return absM.toStringAsFixed(1);
}

/// Move direction toward checkpoint (UI maps to localized labels).
enum CheckPointMoveDirection {
  onTarget,
  north,
  south,
  east,
  west,
  up,
  down,
}

CheckPointMoveDirection checkPointNorthSouthMove(double signedNorthM) {
  if (signedNorthM.abs() < kCheckPointOnTargetThresholdM) {
    return CheckPointMoveDirection.onTarget;
  }
  return signedNorthM > 0
      ? CheckPointMoveDirection.north
      : CheckPointMoveDirection.south;
}

CheckPointMoveDirection checkPointEastWestMove(double signedEastM) {
  if (signedEastM.abs() < kCheckPointOnTargetThresholdM) {
    return CheckPointMoveDirection.onTarget;
  }
  return signedEastM > 0
      ? CheckPointMoveDirection.east
      : CheckPointMoveDirection.west;
}

CheckPointMoveDirection checkPointAltitudeMove(double signedAltDeltaM) {
  if (signedAltDeltaM.abs() < kCheckPointOnTargetThresholdM) {
    return CheckPointMoveDirection.onTarget;
  }
  return signedAltDeltaM > 0
      ? CheckPointMoveDirection.down
      : CheckPointMoveDirection.up;
}

/// Slant range when available, otherwise geodesic horizontal distance.
double checkPointDisplayDistanceM(CheckPointProximitySnapshot snapshot) {
  final slant = snapshot.slantRangeM;
  if (slant != null && slant.isFinite) return slant;
  return snapshot.horizontalM;
}

/// Remaining distance (m) after subtracting [allowedRadiusM] from a scalar delta.
double navigationRemainingM(double absDeltaM, double allowedRadiusM) {
  final remaining = absDeltaM - allowedRadiusM;
  return remaining > 0 ? remaining : 0;
}

CheckPointMoveDirection _navigationAxisMove(
  double signedDeltaM,
  double allowedRadiusM,
  CheckPointMoveDirection Function(double) axisMove,
) {
  final remaining = navigationRemainingM(signedDeltaM.abs(), allowedRadiusM);
  if (remaining < kCheckPointOnTargetThresholdM) {
    return CheckPointMoveDirection.onTarget;
  }
  return axisMove(signedDeltaM);
}

/// Axis deltas and move directions derived from [CheckPointProximitySnapshot].
///
/// Distances are measured to the edge of [CheckPointProximitySnapshot.allowedRadiusM],
/// not the checkpoint center.
class CheckPointProximityNavigationHints {
  const CheckPointProximityNavigationHints({
    required this.northAbsDeltaM,
    required this.northMove,
    required this.eastAbsDeltaM,
    required this.eastMove,
    required this.horizontalDistanceM,
    this.altitudeAbsDeltaM,
    this.altitudeMove,
  });

  final double northAbsDeltaM;
  final CheckPointMoveDirection northMove;
  final double eastAbsDeltaM;
  final CheckPointMoveDirection eastMove;
  final double horizontalDistanceM;
  final double? altitudeAbsDeltaM;
  final CheckPointMoveDirection? altitudeMove;

  factory CheckPointProximityNavigationHints.fromSnapshot(
    CheckPointProximitySnapshot snapshot,
  ) {
    final radius = snapshot.allowedRadiusM;
    final horizontalM = snapshot.horizontalM;

    var signedNorthM = snapshot.signedNorthToCheckpointM;
    var signedEastM = snapshot.signedEastToCheckpointM;
    if (horizontalM > radius && horizontalM.isFinite) {
      final factor = (horizontalM - radius) / horizontalM;
      signedNorthM *= factor;
      signedEastM *= factor;
    } else {
      signedNorthM = 0;
      signedEastM = 0;
    }

    final altDelta = snapshot.signedAltitudeDeltaM;
    CheckPointMoveDirection? altitudeMove;
    double? altitudeAbsDeltaM;
    if (snapshot.checkpointAltitude != null &&
        altDelta != null &&
        altDelta.isFinite) {
      altitudeAbsDeltaM = navigationRemainingM(altDelta.abs(), radius);
      altitudeMove = _navigationAxisMove(
        altDelta,
        radius,
        checkPointAltitudeMove,
      );
    }

    return CheckPointProximityNavigationHints(
      northAbsDeltaM: signedNorthM.abs(),
      northMove: checkPointNorthSouthMove(signedNorthM),
      eastAbsDeltaM: signedEastM.abs(),
      eastMove: checkPointEastWestMove(signedEastM),
      horizontalDistanceM: navigationRemainingM(
        checkPointDisplayDistanceM(snapshot),
        radius,
      ),
      altitudeAbsDeltaM: altitudeAbsDeltaM,
      altitudeMove: altitudeMove,
    );
  }
}

class CheckPointProximityEvaluation {
  const CheckPointProximityEvaluation({required this.result, this.snapshot});

  final CheckPointProximityResult result;
  final CheckPointProximitySnapshot? snapshot;
}

/// Checks device position against checkpoint and returns navigation snapshot.
///
/// Horizontal distance uses geodesic ([Geolocator.distanceBetween]).
/// North/east: geodesic along meridian/parallel (matches [horizontalM] at short range).
/// When checkpoint altitude exists, checks 3D distance.
///
/// [horizontalAccuracyM]: horizontal ε margin (m), usually from
/// [netIncrementalAccuracyM] — horizontal distance only.
/// [gpsAltitudeAccuracyM]: GPS altitude ε margin, same rules.
///
/// Horizontal (and GPS altitude): compare with ε margin —
/// clearly inside (`d < R`) → pass (avoid stuck popup when GPS already reports near);
/// outside (`d > R`) but `d − ε ≤ R` → pass (avoid fail when GPS drifts away).
/// Barometer altitude: strict `≤ radius` (no ε).
CheckPointProximityEvaluation evaluateCheckPointProximity({
  required CheckPoint checkpoint,
  required double latitude,
  required double longitude,
  double? gpsAltitude,
  double? baroAltitude,
  bool validateBaroAltitude = false,
  double? horizontalAccuracyM,
  double? gpsAltitudeAccuracyM,
}) {
  if (!checkpoint.hasCoordinates) {
    return const CheckPointProximityEvaluation(
      result: CheckPointProximityResult.failure(
        issue: CheckPointProximityIssue.noCheckpointCoordinates,
      ),
    );
  }

  final snapshot = _buildSnapshot(
    checkpoint: checkpoint,
    latitude: latitude,
    longitude: longitude,
    gpsAltitude: gpsAltitude,
    baroAltitude: baroAltitude,
    usesBaroAltitude: validateBaroAltitude,
    horizontalAccuracyM: horizontalAccuracyM,
    gpsAltitudeAccuracyM: gpsAltitudeAccuracyM,
  );

  final horizontalMargin = _accuracyMargin(horizontalAccuracyM);
  final gpsAltitudeMargin = _accuracyMargin(gpsAltitudeAccuracyM);
  final allowed = snapshot.allowedRadiusM;

  final cpBaroAlt = checkpoint.baroAltitude;
  if (validateBaroAltitude && cpBaroAlt != null) {
    final deviceBaro = snapshot.deviceAltitude;
    if (deviceBaro == null || !deviceBaro.isFinite) {
      return CheckPointProximityEvaluation(
        result: CheckPointProximityResult.failure(
          issue: CheckPointProximityIssue.baroAltitudePending,
          allowedRadiusM: allowed,
        ),
        snapshot: snapshot,
      );
    }

    final fail = _proximityFailure(
      snapshot: snapshot,
      horizontalAccuracyMargin: horizontalMargin,
      altitudeAccuracyMargin: 0,
      altitudeIssue: CheckPointProximityIssue.baroAltitudeOutOfRange,
      checkAltitude: true,
    );
    if (fail != null) {
      return CheckPointProximityEvaluation(result: fail, snapshot: snapshot);
    }
    return CheckPointProximityEvaluation(
      result: const CheckPointProximityResult.ok(),
      snapshot: snapshot,
    );
  }

  final cpGpsAlt = checkpoint.gpsAltitude;
  if (cpGpsAlt != null) {
    final deviceGps = gpsAltitude;
    if (deviceGps == null || !deviceGps.isFinite) {
      return CheckPointProximityEvaluation(
        result: CheckPointProximityResult.failure(
          issue: CheckPointProximityIssue.gpsAltitudeOutOfRange,
          allowedRadiusM: allowed,
        ),
        snapshot: snapshot,
      );
    }

    final fail = _proximityFailure(
      snapshot: snapshot,
      horizontalAccuracyMargin: horizontalMargin,
      altitudeAccuracyMargin: gpsAltitudeMargin,
      altitudeIssue: CheckPointProximityIssue.gpsAltitudeOutOfRange,
      checkAltitude: true,
    );
    if (fail != null) {
      return CheckPointProximityEvaluation(result: fail, snapshot: snapshot);
    }
  } else {
    final fail = _proximityFailure(
      snapshot: snapshot,
      horizontalAccuracyMargin: horizontalMargin,
      altitudeIssue: CheckPointProximityIssue.horizontalOutOfRange,
    );
    if (fail != null) {
      return CheckPointProximityEvaluation(result: fail, snapshot: snapshot);
    }
  }

  return CheckPointProximityEvaluation(
    result: const CheckPointProximityResult.ok(),
    snapshot: snapshot,
  );
}

double _accuracyMargin(double? accuracyM) => _positiveAccuracy(accuracyM) ?? 0;

double? _positiveAccuracy(double? accuracyM) {
  if (accuracyM == null || !accuracyM.isFinite || accuracyM <= 0) {
    return null;
  }
  return accuracyM;
}

/// `null` if in range; otherwise failure with display distance.
CheckPointProximityResult? _proximityFailure({
  required CheckPointProximitySnapshot snapshot,
  required double horizontalAccuracyMargin,
  double altitudeAccuracyMargin = 0,
  required CheckPointProximityIssue altitudeIssue,
  bool checkAltitude = false,
}) {
  final radius = snapshot.allowedRadiusM;
  final horizontalFail = _distanceFailsWithAccuracyMargin(
    distanceM: snapshot.horizontalM,
    allowedRadiusM: radius,
    accuracyMarginM: horizontalAccuracyMargin,
  );
  if (horizontalFail) {
    return CheckPointProximityResult.failure(
      issue: CheckPointProximityIssue.horizontalOutOfRange,
      distanceM: snapshot.horizontalM,
      allowedRadiusM: radius,
    );
  }

  if (checkAltitude) {
    final altDelta = snapshot.signedAltitudeDeltaM?.abs();
    if (altDelta != null && altDelta.isFinite) {
      final altitudeFail = altitudeAccuracyMargin > 0
          ? _distanceFailsWithAccuracyMargin(
              distanceM: altDelta,
              allowedRadiusM: radius,
              accuracyMarginM: altitudeAccuracyMargin,
            )
          : altDelta > radius;
      if (altitudeFail) {
        return CheckPointProximityResult.failure(
          issue: altitudeIssue,
          distanceM: altDelta,
          allowedRadiusM: radius,
        );
      }
    }
  }

  return null;
}

/// Whether to treat as **out of** range when measurement error ε (m) is known.
///
/// - Measured `d < R`: GPS reports inside → pass.
/// - Measured `d > R` but `d − ε ≤ R`: may be close enough → pass.
/// - No ε: fail when `d > R`.
bool _distanceFailsWithAccuracyMargin({
  required double distanceM,
  required double allowedRadiusM,
  required double accuracyMarginM,
}) {
  if (accuracyMarginM <= 0) {
    return distanceM > allowedRadiusM;
  }
  if (distanceM <= allowedRadiusM) {
    return false;
  }
  return distanceM - accuracyMarginM > allowedRadiusM;
}

CheckPointProximitySnapshot _buildSnapshot({
  required CheckPoint checkpoint,
  required double latitude,
  required double longitude,
  double? gpsAltitude,
  double? baroAltitude,
  bool usesBaroAltitude = false,
  double? horizontalAccuracyM,
  double? gpsAltitudeAccuracyM,
}) {
  final cpLat = checkpoint.latitude!;
  final cpLng = checkpoint.longitude!;
  final allowedRadiusM = checkpoint.radius ?? kDefaultCheckPointRadiusM;

  final horizontalM = Geolocator.distanceBetween(
    cpLat,
    cpLng,
    latitude,
    longitude,
  );

  double signedNorthToCheckpointM;
  double signedEastToCheckpointM;
  if (horizontalM < kCheckPointOnTargetThresholdM) {
    signedNorthToCheckpointM = 0;
    signedEastToCheckpointM = 0;
  } else {
    signedNorthToCheckpointM = _signedGeodesicNorthM(
      latitude,
      longitude,
      cpLat,
      cpLng,
    );
    signedEastToCheckpointM = _signedGeodesicEastM(
      latitude,
      longitude,
      cpLat,
      cpLng,
    );
  }

  double? checkpointAltitude;
  double? deviceAltitude;
  double? signedAltitudeDeltaM;

  if (usesBaroAltitude && checkpoint.baroAltitude != null) {
    checkpointAltitude = checkpoint.baroAltitude;
    deviceAltitude = baroAltitude;
    if (baroAltitude != null && baroAltitude.isFinite) {
      signedAltitudeDeltaM = baroAltitude - checkpoint.baroAltitude!;
    }
  } else if (checkpoint.gpsAltitude != null) {
    checkpointAltitude = checkpoint.gpsAltitude;
    deviceAltitude = gpsAltitude;
    if (gpsAltitude != null && gpsAltitude.isFinite) {
      signedAltitudeDeltaM = gpsAltitude - checkpoint.gpsAltitude!;
    }
  }

  double? slantRangeM;
  if (signedAltitudeDeltaM != null && signedAltitudeDeltaM.isFinite) {
    slantRangeM = math.sqrt(
      horizontalM * horizontalM + signedAltitudeDeltaM * signedAltitudeDeltaM,
    );
  }

  final horizontalAcc = _positiveAccuracy(horizontalAccuracyM);
  final gpsAltAcc = _positiveAccuracy(gpsAltitudeAccuracyM);

  return CheckPointProximitySnapshot(
    checkpointLat: cpLat,
    checkpointLng: cpLng,
    checkpointAltitude: checkpointAltitude,
    deviceLat: latitude,
    deviceLng: longitude,
    deviceAltitude: deviceAltitude,
    signedNorthToCheckpointM: signedNorthToCheckpointM,
    signedEastToCheckpointM: signedEastToCheckpointM,
    horizontalM: horizontalM,
    slantRangeM: slantRangeM,
    horizontalAccuracyM: horizontalAcc,
    gpsAltitudeAccuracyM: gpsAltAcc,
    signedAltitudeDeltaM: signedAltitudeDeltaM,
    allowedRadiusM: allowedRadiusM,
    usesBaroAltitude: usesBaroAltitude,
  );
}

/// How auto-scan picks among eligible checkpoints (sorted by `sequenceOrder`).
enum CheckPointMatchOrder {
  /// Only [points.first]; returns on match.
  sequenceOrder,

  /// Among matches, pick smallest horizontal distance.
  nearest,
}

/// Proximity scan result: matched checkpoint for log and/or UI feedback.
class CheckPointProximityScan {
  const CheckPointProximityScan({this.matched, this.feedback});

  final CheckPoint? matched;
  final CheckPointProximityEvaluation? feedback;
}

CheckPointMatchOrder checkPointMatchOrderFromConfig(String rawOrder) {
  return switch (rawOrder.trim().toLowerCase()) {
    'nearest' => CheckPointMatchOrder.nearest,
    _ => CheckPointMatchOrder.sequenceOrder,
  };
}

CheckPointProximityEvaluation evaluateCheckPointProximityForSample({
  required CheckPoint checkpoint,
  required DeviceLocationSample sample,
  required bool baroListening,
}) {
  final pos = sample.position;
  final validateBaro = checkpoint.baroAltitude != null && baroListening;
  return evaluateCheckPointProximity(
    checkpoint: checkpoint,
    latitude: sample.latitude,
    longitude: sample.longitude,
    gpsAltitude: sample.gpsAltitude,
    baroAltitude: sample.baroAltitude,
    validateBaroAltitude: validateBaro,
    horizontalAccuracyM: netIncrementalAccuracyM(
      pos.accuracy,
      checkpoint.accuracy,
    ),
    gpsAltitudeAccuracyM: netIncrementalAccuracyM(
      pos.altitudeAccuracy,
      checkpoint.altitudeAccuracy,
    ),
  );
}

/// Scans [points] (expected sorted by `sequenceOrder`) for a proximity match.
CheckPointProximityScan scanCheckPointsProximity(
  List<CheckPoint> points,
  DeviceLocationSample sample,
  bool baroListening, {
  CheckPointMatchOrder matchOrder = CheckPointMatchOrder.sequenceOrder,
}) {
  if (points.isEmpty) return const CheckPointProximityScan();

  if (matchOrder == CheckPointMatchOrder.sequenceOrder) {
    final evaluation = evaluateCheckPointProximityForSample(
      checkpoint: points.first,
      sample: sample,
      baroListening: baroListening,
    );
    if (evaluation.result.ok) {
      return CheckPointProximityScan(matched: points.first);
    }
    return CheckPointProximityScan(feedback: evaluation);
  }

  CheckPoint? bestMatch;
  double? bestMatchDistanceM;
  CheckPointProximityEvaluation? nearestFeedback;
  double? nearestFeedbackDistanceM;

  for (final point in points) {
    final evaluation = evaluateCheckPointProximityForSample(
      checkpoint: point,
      sample: sample,
      baroListening: baroListening,
    );
    if (evaluation.result.ok) {
      final distanceM = evaluation.snapshot?.horizontalM;
      if (distanceM == null) {
        bestMatch ??= point;
        continue;
      }
      if (bestMatchDistanceM == null || distanceM < bestMatchDistanceM) {
        bestMatchDistanceM = distanceM;
        bestMatch = point;
      }
    } else {
      final distanceM = evaluation.result.distanceM;
      if (distanceM == null) continue;
      if (nearestFeedbackDistanceM == null ||
          distanceM < nearestFeedbackDistanceM) {
        nearestFeedbackDistanceM = distanceM;
        nearestFeedback = evaluation;
      }
    }
  }

  if (bestMatch != null) {
    return CheckPointProximityScan(matched: bestMatch);
  }
  return CheckPointProximityScan(feedback: nearestFeedback);
}
