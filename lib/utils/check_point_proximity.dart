import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../models/check_point.dart';

/// Bán kính mặc định (m) khi checkpoint chưa cấu hình `radius`.
const double kDefaultCheckPointRadiusM = 3;

/// Biên sai số “phần dư”: [deviceM] trừ sai số đã lưu tại mốc [checkpointM].
///
/// Chỉ nới khi GPS hiện tại kém hơn lúc lưu mốc (`device > checkpoint`).
/// Hiệu ≤ 0 → `null` (so khoảng cách chặt với [allowedRadiusM], không cộng ε).
double? netIncrementalAccuracyM(double? deviceM, double? checkpointM) {
  if (deviceM == null || !deviceM.isFinite || deviceM <= 0) return null;
  final cp = checkpointM;
  if (cp != null && cp.isFinite) {
    final net = deviceM - cp;
    return net > 0 ? net : null;
  }
  return deviceM;
}

/// Độ lệch bắc–nam (m) dọc kinh tuyến; dương = mốc nằm phía bắc `from`.
double _signedGeodesicNorthM(
  double fromLat,
  double fromLng,
  double toLat,
  double toLng,
) {
  final d = Geolocator.distanceBetween(fromLat, fromLng, toLat, fromLng);
  return toLat >= fromLat ? d : -d;
}

/// Độ lệch đông–tây (m) dọc vĩ tuyến; dương = mốc nằm phía đông `from`.
double _signedGeodesicEastM(
  double fromLat,
  double fromLng,
  double toLat,
  double toLng,
) {
  final d = Geolocator.distanceBetween(fromLat, fromLng, fromLat, toLng);
  return toLng >= fromLng ? d : -d;
}

/// Khoảng cách ngang (m) tới checkpoint; `null` nếu checkpoint chưa có tọa độ.
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

/// Chi tiết so sánh vị trí thiết bị với checkpoint (popup điều hướng).
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

  /// Dương = cần đi về phía bắc (m) để tới mốc.
  final double signedNorthToCheckpointM;

  /// Dương = cần đi về phía đông (m) để tới mốc.
  final double signedEastToCheckpointM;

  /// Khoảng cách geodesic ngang (m) — đường thẳng trên mặt đất.
  final double horizontalM;

  /// Khoảng cách không gian √(ngang² + độ cao²) khi có đủ độ cao.
  final double? slantRangeM;

  /// Sai số ngang từ GPS (`Position.accuracy`), nếu có.
  final double? horizontalAccuracyM;

  /// Sai số độ cao GPS (`Position.altitudeAccuracy`), nếu có.
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

/// Kiểm tra vị trí thiết bị so với checkpoint và trả về snapshot điều hướng.
///
/// Khoảng cách ngang dùng geodesic ([Geolocator.distanceBetween]).
/// Hướng bắc/đông: geodesic dọc kinh/vĩ tuyến (khớp [horizontalM] ở cự ly ngắn).
/// Khi có độ cao mốc, kiểm tra theo khoảng cách 3D.
///
/// [horizontalAccuracyM]: biên sai số ngang ε (m), thường từ
/// [netIncrementalAccuracyM] — chỉ cho khoảng cách ngang.
/// [gpsAltitudeAccuracyM]: biên sai số độ cao GPS ε, cùng cách tính.
///
/// Ngang (và độ cao GPS): so sánh có biên sai số ε —
/// đo rõ trong vùng (`d < R`) → pass (tránh kẹt popup khi GPS đã báo đủ gần);
/// đo ngoài vùng (`d > R`) nhưng `d − ε ≤ R` → pass (tránh fail khi GPS đẩy xa mốc).
/// Độ cao barometer: so sánh chặt `≤ radius` (không dùng ε).
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

/// `null` nếu trong phạm vi; ngược lại kết quả lỗi với khoảng cách hiển thị.
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

/// Có nên coi là **ngoài** phạm vi khi biết sai số đo ε (m).
///
/// - Đo `d < R`: GPS đã báo trong vùng → pass.
/// - Đo `d > R` nhưng `d − ε ≤ R`: có thể đứng đủ gần → pass.
/// - Không có ε: fail khi `d > R`.
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
