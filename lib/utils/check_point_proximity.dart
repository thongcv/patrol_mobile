import 'package:geolocator/geolocator.dart';

import '../models/check_point.dart';

/// Bán kính mặc định (m) khi checkpoint chưa cấu hình `radius`.
const double kDefaultCheckPointRadiusM = 3;

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
  })  : ok = false;

  final bool ok;
  final CheckPointProximityIssue? issue;
  final double? distanceM;
  final double? allowedRadiusM;
}

/// Kiểm tra vị trí thiết bị so với tọa độ/độ cao đã lưu của checkpoint.
///
/// Độ cao: ưu tiên barometer khi [validateBaroAltitude] (thiết bị hỗ trợ +
/// checkpoint có `baroAltitude`); không hỗ trợ barometer mới so `gpsAltitude`.
CheckPointProximityResult validateCheckPointProximity({
  required CheckPoint checkpoint,
  required double latitude,
  required double longitude,
  double? gpsAltitude,
  double? baroAltitude,
  bool validateBaroAltitude = false,
}) {
  if (!checkpoint.hasCoordinates) {
    return const CheckPointProximityResult.failure(
      issue: CheckPointProximityIssue.noCheckpointCoordinates,
    );
  }

  final allowedRadiusM = checkpoint.radius ?? kDefaultCheckPointRadiusM;

  final horizontalM = Geolocator.distanceBetween(
    checkpoint.latitude!,
    checkpoint.longitude!,
    latitude,
    longitude,
  );
  if (horizontalM > allowedRadiusM) {
    return CheckPointProximityResult.failure(
      issue: CheckPointProximityIssue.horizontalOutOfRange,
      distanceM: horizontalM,
      allowedRadiusM: allowedRadiusM,
    );
  }

  final cpBaroAlt = checkpoint.baroAltitude;
  if (validateBaroAltitude && cpBaroAlt != null) {
    if (baroAltitude == null || !baroAltitude.isFinite) {
      return CheckPointProximityResult.failure(
        issue: CheckPointProximityIssue.baroAltitudePending,
        allowedRadiusM: allowedRadiusM,
      );
    }
    final baroDelta = (baroAltitude - cpBaroAlt).abs();
    if (baroDelta > allowedRadiusM) {
      return CheckPointProximityResult.failure(
        issue: CheckPointProximityIssue.baroAltitudeOutOfRange,
        distanceM: baroDelta,
        allowedRadiusM: allowedRadiusM,
      );
    }
    return const CheckPointProximityResult.ok();
  }

  final cpGpsAlt = checkpoint.gpsAltitude;
  if (cpGpsAlt != null) {
    if (gpsAltitude == null || !gpsAltitude.isFinite) {
      return CheckPointProximityResult.failure(
        issue: CheckPointProximityIssue.gpsAltitudeOutOfRange,
        allowedRadiusM: allowedRadiusM,
      );
    }
    final gpsDelta = (gpsAltitude - cpGpsAlt).abs();
    if (gpsDelta > allowedRadiusM) {
      return CheckPointProximityResult.failure(
        issue: CheckPointProximityIssue.gpsAltitudeOutOfRange,
        distanceM: gpsDelta,
        allowedRadiusM: allowedRadiusM,
      );
    }
  }

  return const CheckPointProximityResult.ok();
}
