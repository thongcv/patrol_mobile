import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../models/check_point.dart';

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
  if (horizontalM < 0.05) {
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
