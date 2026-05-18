import 'dart:math';

import 'gps_native_service.dart';

/// Quy đổi áp suất (hPa) sang độ cao gần đúng so với mực nước biển chuẩn ISA
/// (1013.25 hPa). Sai số phụ thuộc áp suất thực tế tại mực nước biển khu vực.
double altitudeMetersFromPressureHpa(double pressureHpa) {
  if (!pressureHpa.isFinite || pressureHpa <= 0) return double.nan;
  const p0 = 1013.25;
  return 44330.0 * (1.0 - pow(pressureHpa / p0, 0.1902632));
}

/// `true` nếu thiết bị có cảm biến áp suất (barometer).
Future<bool> isBarometerSupported() async {
  if (!GpsNativeService.isSupported) return false;
  return GpsNativeService.isBarometerHardwareSupported();
}

/// Barometer (nếu có) → GPS → [fallback].
double? resolveAltitudeMeters({
  double? barometricMeters,
  required double gpsMeters,
  double? fallbackMeters,
}) {
  if (barometricMeters != null && barometricMeters.isFinite) {
    return barometricMeters;
  }
  if (gpsMeters.isFinite) return gpsMeters;
  return fallbackMeters;
}
