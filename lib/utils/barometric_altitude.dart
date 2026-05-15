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

// Hàm kiểm tra xem cảm biến có hoạt động không
Future<bool> hasBarometer() async {
  try {
    // Thử lắng nghe stream trong một khoảng thời gian ngắn (ví dụ 1 giây)
    final stream = barometerEventStream();
    await stream.first.timeout(
      const Duration(seconds: 1),
      onTimeout: () => throw TimeoutException('No sensor found'),
    );
    return true;
  } catch (e) {
    return false; 
  }
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
