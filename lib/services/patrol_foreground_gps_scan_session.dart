import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../background/patrol_background_service.dart';
import '../services/patrol_tracking_config_store.dart';
import '../utils/barometric_altitude.dart';
import '../utils/device_location.dart';

/// Foreground auto-scan GPS — uses FGS relay when background tracking owns GPS,
/// otherwise falls back to [DeviceLocationWatch].
class PatrolForegroundGpsScanSession {
  PatrolForegroundGpsScanSession._({
    required bool useFgsRelay,
    required bool barometerSupported,
  })  : _useFgsRelay = useFgsRelay,
        _barometerSupported = barometerSupported;

  static PatrolForegroundGpsScanSession? _active;

  final bool _useFgsRelay;
  final bool _barometerSupported;
  DeviceLocationWatch? _localWatch;
  var _trackBarometer = false;
  var _stopped = true;
  DeviceLocationOnSample? _onSample;

  bool get barometerListening => _trackBarometer;

  static Future<PatrolForegroundGpsScanSession> create() async {
    var baroSupported = false;
    try {
      baroSupported = await isBarometerSupported();
    } on Object {
      baroSupported = false;
    }
    final useFgsRelay = await _fgsOwnsGps();
    return PatrolForegroundGpsScanSession._(
      useFgsRelay: useFgsRelay,
      barometerSupported: baroSupported,
    );
  }

  static Future<bool> _fgsOwnsGps() async {
    if (!await PatrolTrackingConfigStore.backgroundEnabled()) return false;
    return PatrolBackgroundService.isRunningSafe();
  }

  /// Delivers FGS relay payloads to the active session ([PatrolFgsMainRelay]).
  static void deliverFgsSample(dynamic payload) {
    _active?._ingestFgsSample(payload);
  }

  Future<String?> start({
    bool enableBarometer = false,
    bool requestLocationPermission = true,
    required DeviceLocationOnSample onSample,
  }) async {
    final denied = await ensurePatrolDeviceLocationReady(
      requestIfDenied: requestLocationPermission,
    );
    if (denied != null) return denied;

    _stopped = false;
    _trackBarometer = enableBarometer && _barometerSupported;
    _onSample = onSample;

    if (_useFgsRelay) {
      _active = this;
      await PatrolBackgroundService.setForegroundScanRelay(
        enabled: true,
        enableBarometer: _trackBarometer,
      );
      return null;
    }

    final watch = await DeviceLocationWatch.create();
    _localWatch = watch;
    return watch.start(
      enableBarometer: enableBarometer,
      requestLocationPermission: false,
      onSample: onSample,
    );
  }

  Future<void> stop() async {
    _stopped = true;
    _onSample = null;

    if (_useFgsRelay) {
      if (_active == this) _active = null;
      await PatrolBackgroundService.setForegroundScanRelay(enabled: false);
      return;
    }

    await _localWatch?.stop();
    _localWatch = null;
    _trackBarometer = false;
  }

  void _ingestFgsSample(dynamic payload) {
    if (_stopped || _onSample == null) return;
    if (payload is! Map) return;

    final map = Map<Object?, Object?>.from(payload);
    final lat = (map['latitude'] as num?)?.toDouble();
    final lng = (map['longitude'] as num?)?.toDouble();
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite) {
      return;
    }

    final tsMs = (map['timestamp'] as num?)?.toInt();
    final accuracy = (map['accuracy'] as num?)?.toDouble();
    final altitude = (map['altitude'] as num?)?.toDouble();
    final altitudeAccuracy = (map['altitudeAccuracy'] as num?)?.toDouble();
    final barometricAltitude = (map['barometricAltitude'] as num?)?.toDouble();

    final position = Position(
      latitude: lat,
      longitude: lng,
      timestamp: tsMs != null
          ? DateTime.fromMillisecondsSinceEpoch(tsMs)
          : DateTime.now(),
      accuracy: accuracy != null && accuracy.isFinite
          ? accuracy
          : double.maxFinite,
      altitude: altitude != null && altitude.isFinite ? altitude : 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: altitudeAccuracy != null && altitudeAccuracy.isFinite
          ? altitudeAccuracy
          : 0,
      headingAccuracy: 0,
    );

    final gpsAlt = position.altitude.isFinite ? position.altitude : null;
    final baroAlt = barometricAltitude != null && barometricAltitude.isFinite
        ? barometricAltitude
        : null;

    final sample = (
      position: position,
      latitude: lat,
      longitude: lng,
      gpsAltitude: gpsAlt,
      baroAltitude: baroAlt,
    );

    if (_onSample!(sample)) {
      unawaited(stop());
    }
  }
}

/// Live GPS on the patrol **point** screen — always uses main-isolate
/// [DeviceLocationWatch], independent of FGS GPS hub / shift window.
/// Stops when the screen is disposed.
class PatrolForegroundGpsLiveTracker extends ChangeNotifier {
  PatrolForegroundGpsLiveTracker._(
    this._barometerSupported, {
    required bool Function() isActive,
  }) : _isActive = isActive;

  final bool _barometerSupported;
  final bool Function() _isActive;

  DeviceLocationWatch? _watch;
  var _generation = 0;

  bool busy = false;
  Position? position;
  String? messageKey;
  double? barometricAltitude;

  bool get barometerSupported => _barometerSupported;

  static Future<PatrolForegroundGpsLiveTracker> create({
    bool Function()? isActive,
  }) async {
    var supported = false;
    try {
      supported = await isBarometerSupported();
    } on Object {
      supported = false;
    }
    return PatrolForegroundGpsLiveTracker._(
      supported,
      isActive: isActive ?? (() => true),
    );
  }

  double? altitudeForDisplay(Position pos) {
    return resolveAltitudeMeters(
      barometricMeters: barometerSupported ? barometricAltitude : null,
      gpsMeters: pos.altitude,
    );
  }

  void applyGpsReading({
    required Position position,
    double? freshBarometricAltitude,
  }) {
    this.position = position;
    messageKey = null;
    if (freshBarometricAltitude != null) {
      barometricAltitude = freshBarometricAltitude;
    }
    _notify();
  }

  Future<void> start({bool userInitiated = false}) async {
    final generation = ++_generation;

    await _watch?.stop();
    _watch = null;

    if (!_isActive() || generation != _generation) return;
    busy = true;
    if (userInitiated) messageKey = null;
    _notify();

    final watch = await DeviceLocationWatch.create();
    if (!_isActive() || generation != _generation) {
      await watch.stop();
      return;
    }
    _watch = watch;

    final error = await watch.start(
      enableBarometer: _barometerSupported,
      onSample: (sample) {
        if (!_isActive() || generation != _generation) return false;
        position = sample.position;
        if (sample.baroAltitude != null) {
          barometricAltitude = sample.baroAltitude;
        }
        messageKey = null;
        busy = false;
        _notify();
        return false;
      },
    );

    if (!_isActive() || generation != _generation) return;

    if (error != null) {
      busy = false;
      messageKey = error;
      _notify();
    }
  }

  @override
  void dispose() {
    ++_generation;
    final watch = _watch;
    _watch = null;
    if (watch != null) unawaited(watch.stop());
    super.dispose();
  }

  void _notify() {
    if (_isActive()) notifyListeners();
  }
}
