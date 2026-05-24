import 'dart:math';

import 'super_gps_service.dart';

/// Converts pressure (hPa) to approximate altitude vs standard ISA sea level
/// (1013.25 hPa). Error depends on actual regional sea-level pressure.
double altitudeMetersFromPressureHpa(double pressureHpa) {
  if (!pressureHpa.isFinite || pressureHpa <= 0) return double.nan;
  const p0 = 1013.25;
  return 44330.0 * (1.0 - pow(pressureHpa / p0, 0.1902632));
}

/// `true` if the device has a pressure sensor (barometer).
Future<bool> isBarometerSupported() async {
  if (!SuperGpsService.isSupported) return false;
  return SuperGpsService.isBarometerHardwareSupported();
}

/// Barometer (if any) → GPS → [fallback].
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
