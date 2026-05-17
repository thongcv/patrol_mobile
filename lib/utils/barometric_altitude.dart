import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

/// Quy đổi áp suất (hPa) sang độ cao gần đúng so với mực nước biển chuẩn ISA
/// (1013.25 hPa). Sai số phụ thuộc áp suất thực tế tại mực nước biển khu vực.
double altitudeMetersFromPressureHpa(double pressureHpa) {
  if (!pressureHpa.isFinite || pressureHpa <= 0) return double.nan;
  const p0 = 1013.25;
  return 44330.0 * (1.0 - pow(pressureHpa / p0, 0.1902632));
}

/// Stream độ cao (m) từ barometer; chỉ phát giá trị hợp lệ.
Stream<double> barometricAltitudeStream({
  Duration samplingPeriod = SensorInterval.normalInterval,
}) {
  return barometerEventStream(samplingPeriod: samplingPeriod)
      .map((e) => altitudeMetersFromPressureHpa(e.pressure))
      .where((m) => m.isFinite);
}

/// Lấy một mẫu độ cao barometer (m); `null` nếu không có cảm biến hoặc hết [timeout].
Future<double?> readBarometricAltitudeOnce({
  Duration timeout = const Duration(seconds: 1),
}) async {
  try {
    final alt = await barometricAltitudeStream().first.timeout(timeout);
    return alt.isFinite ? alt : null;
  } catch (_) {
    return null;
  }
}

/// `true` nếu thiết bị trả về được ít nhất một mẫu độ cao hợp lệ.
Future<bool> hasBarometer({
  Duration timeout = const Duration(seconds: 1),
}) async {
  return (await readBarometricAltitudeOnce(timeout: timeout)) != null;
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
