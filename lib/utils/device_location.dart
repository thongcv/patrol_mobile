import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'barometric_altitude.dart';

/// Đọc GPS một lần (quyền + dịch vụ vị trí).
Future<({Position? position, String? messageKey})> readDeviceGpsOnce() async {
  final denied = await _ensureLocationReady();
  if (denied != null) {
    return (position: null, messageKey: denied);
  }

  try {
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
      ),
    );
    return (position: pos, messageKey: null);
  } catch (_) {
    return (position: null, messageKey: 'error');
  }
}

/// Lấy một mẫu độ cao barometer (nếu có), tối đa [timeout].
Future<double?> readBarometricAltitudeOnce({
  Duration timeout = const Duration(seconds: 2),
}) async {
  try {
    final alt = await barometricAltitudeStream().first.timeout(timeout);
    return alt.isFinite ? alt : null;
  } catch (_) {
    return null;
  }
}

/// `null` nếu sẵn sàng; ngược lại mã lỗi `service` | `denied` | `error`.
Future<String?> _ensureLocationReady() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return 'service';

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return 'denied';
  }
  return null;
}

LocationSettings devicePositionStreamSettings() {
  if (kIsWeb) {
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 500),
      );
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
      );
    default:
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
  }
}

typedef DeviceLocationSample = ({
  Position position,
  double? gpsAltitude,
  double? baroAltitude,
});

/// GPS stream riêng; barometer stream riêng (chỉ khi [enableBarometer] và thiết bị hỗ trợ).
class DeviceLocationWatch {
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<double>? _baroSub;
  Position? _lastPosition;
  double? _barometricAltitude;
  bool _stopped = false;
  bool _barometerSupported = false;

  /// `true` khi đã bật listener barometer (checkpoint cần baro + thiết bị hỗ trợ).
  bool get barometerListening => _baroSub != null;

  bool get barometerSupported => _barometerSupported;

  Future<String?> start({
    bool enableBarometer = false,
    required void Function(DeviceLocationSample sample) onSample,
  }) async {
    final denied = await _ensureLocationReady();
    if (denied != null) return denied;

    _stopped = false;
    _lastPosition = null;
    _barometricAltitude = null;
    _barometerSupported = false;

    if (enableBarometer) {
      _barometerSupported = await hasBarometer();
      if (_barometerSupported) {
        _baroSub = barometricAltitudeStream().listen(
          (alt) {
            if (_stopped) return;
            _barometricAltitude = alt.isFinite ? alt : null;
            _emitFromBarometer(onSample);
          },
          onError: (_) {},
          cancelOnError: false,
        );
      }
    }

    try {
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      _lastPosition = initial;
      _emitFromGps(onSample);
    } catch (_) {
      await stop();
      return 'error';
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: devicePositionStreamSettings(),
    ).listen(
      (pos) {
        if (_stopped) return;
        _lastPosition = pos;
        _emitFromGps(onSample);
      },
      onError: (_) {},
      cancelOnError: false,
    );
    return null;
  }

  void _emitFromGps(void Function(DeviceLocationSample sample) onSample) {
    final pos = _lastPosition;
    if (_stopped || pos == null) return;
    onSample(_buildSample(pos));
  }

  void _emitFromBarometer(void Function(DeviceLocationSample sample) onSample) {
    final pos = _lastPosition;
    if (_stopped || pos == null) return;
    onSample(_buildSample(pos));
  }

  DeviceLocationSample _buildSample(Position pos) {
    final gpsAlt = pos.altitude.isFinite ? pos.altitude : null;
    return (
      position: pos,
      gpsAltitude: gpsAlt,
      baroAltitude: _barometricAltitude,
    );
  }

  Future<void> stop() async {
    _stopped = true;
    await _positionSub?.cancel();
    await _baroSub?.cancel();
    _positionSub = null;
    _baroSub = null;
    _lastPosition = null;
    _barometricAltitude = null;
    _barometerSupported = false;
  }
}
