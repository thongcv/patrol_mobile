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
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );

    return (position: pos, messageKey: null);
  } catch (_) {
    return (position: null, messageKey: 'error');
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
      accuracy: LocationAccuracy.best,

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

  /// Lat/lng trung bình theo trọng số 1/accuracy² (ổn định hơn fix GPS đơn lẻ).
  double latitude,

  double longitude,

  double? gpsAltitude,

  double? baroAltitude,
});

/// `true` = đủ dữ liệu, dừng watch (không mở / hủy GPS stream).

typedef DeviceLocationOnSample = bool Function(DeviceLocationSample sample);

const int _kGpsSmoothSampleCap = 6;

/// GPS stream riêng; barometer stream riêng (chỉ khi [enableBarometer] và thiết bị hỗ trợ).

class DeviceLocationWatch {
  StreamSubscription<Position>? _positionSub;

  StreamSubscription<double>? _baroSub;

  Position? _lastPosition;

  final List<Position> _smoothBuffer = [];

  double? _barometricAltitude;

  bool _barometerSupported = false;

  bool _stopped = false;

  /// `true` khi đã bật listener barometer (checkpoint cần baro + thiết bị hỗ trợ).

  bool get barometerListening => _baroSub != null;

  bool get barometerSupported => _barometerSupported;

  Future<String?> start({
    bool enableBarometer = false,

    required DeviceLocationOnSample onSample,
  }) async {
    final denied = await _ensureLocationReady();

    if (denied != null) return denied;

    _stopped = false;

    _lastPosition = null;

    _smoothBuffer.clear();

    _barometricAltitude = null;

    _barometerSupported = false;

    if (enableBarometer) {
      _barometricAltitude = await readBarometricAltitudeOnce();

      _barometerSupported = _barometricAltitude != null;

      if (_barometerSupported) {
        if (!await _initCurrentPosition()) {
          await stop();

          return 'error';
        }

        if (_emitFromBarometer(onSample) || _stopped) {
          if (!_stopped) await stop();

          return null;
        }

        _baroSub = barometricAltitudeStream().listen(
          (alt) {
            if (_stopped) return;

            _barometricAltitude = alt.isFinite ? alt : null;

            if (_emitFromBarometer(onSample)) {
              unawaited(stop());
            }
          },

          onError: (_) {},

          cancelOnError: false,
        );
      } else {
        if (!await _initCurrentPosition()) {
          await stop();

          return 'error';
        }

        if (_emitFromGps(onSample) || _stopped) {
          if (!_stopped) await stop();

          return null;
        }
      }
    } else {
      if (!await _initCurrentPosition()) {
        await stop();

        return 'error';
      }

      if (_emitFromGps(onSample) || _stopped) {
        if (!_stopped) await stop();

        return null;
      }
    }

    if (_stopped) return null;

    _startPositionStream(onSample);

    return null;
  }

  void _startPositionStream(DeviceLocationOnSample onSample) {
    if (_stopped || _positionSub != null) return;

    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: devicePositionStreamSettings(),
        ).listen(
          (pos) {
            if (_stopped) return;

            _ingestPosition(pos);

            if (_emitFromGps(onSample)) {
              unawaited(stop());
            }
          },

          onError: (_) {},

          cancelOnError: false,
        );
  }

  /// `false` nếu không lấy được vị trí ban đầu.

  Future<bool> _initCurrentPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );

      _ingestPosition(pos);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// `true` khi [onSample] yêu cầu dừng watch.

  bool _emitFromGps(DeviceLocationOnSample onSample) {
    final pos = _lastPosition;

    if (_stopped || pos == null) return false;

    return onSample(_buildSample(pos));
  }

  /// `true` khi [onSample] yêu cầu dừng watch.

  bool _emitFromBarometer(DeviceLocationOnSample onSample) {
    final pos = _lastPosition;

    if (_stopped || pos == null) return false;

    return onSample(_buildSample(pos));
  }

  void _ingestPosition(Position pos) {
    _lastPosition = pos;

    _smoothBuffer.add(pos);

    if (_smoothBuffer.length > _kGpsSmoothSampleCap) {
      _smoothBuffer.removeAt(0);
    }
  }

  ({double lat, double lng}) _smoothedCoordinates(Position latest) {
    var weightSum = 0.0;

    var lat = 0.0;

    var lng = 0.0;

    var used = 0;

    for (final p in _smoothBuffer) {
      final acc = p.accuracy;

      if (!acc.isFinite || acc <= 0) continue;

      final w = 1.0 / (acc * acc);

      weightSum += w;

      lat += p.latitude * w;

      lng += p.longitude * w;

      used++;
    }

    if (weightSum == 0 || used == 0) {
      return (lat: latest.latitude, lng: latest.longitude);
    }

    return (lat: lat / weightSum, lng: lng / weightSum);
  }

  DeviceLocationSample _buildSample(Position pos) {
    final coords = _smoothedCoordinates(pos);

    final gpsAlt = pos.altitude.isFinite ? pos.altitude : null;

    return (
      position: pos,

      latitude: coords.lat,

      longitude: coords.lng,

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

    _smoothBuffer.clear();

    _barometricAltitude = null;

    _barometerSupported = false;
  }
}
