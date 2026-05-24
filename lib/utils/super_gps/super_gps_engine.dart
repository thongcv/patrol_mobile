import 'dart:async';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'super_gps_barometer.dart';
import 'super_gps_fix_quality_gate.dart';
import 'super_gps_kalman_filter.dart';

/// Geolocator-backed GPS with Kalman filter + fix quality gate (ported from native).
class SuperGpsStreamOptions {
  const SuperGpsStreamOptions({
    this.updateIntervalMs = 700,
    this.minUpdateIntervalMs = 500,
    this.minUpdateDistanceMeters = 0,
    this.enableBarometer = false,
  });

  final int updateIntervalMs;
  final int minUpdateIntervalMs;
  final int minUpdateDistanceMeters;
  final bool enableBarometer;

  static const SuperGpsStreamOptions defaults = SuperGpsStreamOptions();

  LocationSettings toLocationSettings() {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: minUpdateDistanceMeters,
        intervalDuration: Duration(milliseconds: updateIntervalMs),
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: minUpdateDistanceMeters,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: minUpdateDistanceMeters,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SuperGpsStreamOptions &&
        other.updateIntervalMs == updateIntervalMs &&
        other.minUpdateIntervalMs == minUpdateIntervalMs &&
        other.minUpdateDistanceMeters == minUpdateDistanceMeters &&
        other.enableBarometer == enableBarometer;
  }

  @override
  int get hashCode => Object.hash(
    updateIntervalMs,
    minUpdateIntervalMs,
    minUpdateDistanceMeters,
    enableBarometer,
  );
}

class SuperGpsEvent {
  const SuperGpsEvent({
    required this.position,
    this.barometricAltitude,
    this.barometerHardwareSupported = false,
  });

  final Position position;
  final double? barometricAltitude;
  final bool barometerHardwareSupported;
}

class SuperGpsEngine {
  SuperGpsEngine._();

  static final SuperGpsEngine instance = SuperGpsEngine._();

  static const Duration _fastCacheMaxAge = Duration(minutes: 2);
  static const Duration _currentLocMaxWait = Duration(milliseconds: 1500);
  static const double _oneShotBestAccuracyM = 4;

  final SuperGpsKalmanFilter _kalman = SuperGpsKalmanFilter();
  final SuperGpsFixQualityGate _fixGate = SuperGpsFixQualityGate();
  final SuperGpsBarometer _barometer = SuperGpsBarometer();

  final List<void Function(SuperGpsEvent)> _listeners = [];
  StreamSubscription<Position>? _positionSub;
  Timer? _fallbackTimer;
  var _running = false;
  SuperGpsStreamOptions _streamOptions = SuperGpsStreamOptions.defaults;
  var _streamGeneration = 0;

  SuperGpsStreamOptions get streamOptions => _streamOptions;

  void configureStream(SuperGpsStreamOptions options) {
    final changed = _streamOptions != options;
    _streamOptions = options;
    if (changed && _running) {
      unawaited(_restartStream());
    }
  }

  /// Broadcast stream for multiple subscribers.
  Stream<SuperGpsEvent> events({SuperGpsStreamOptions? options}) {
    if (options != null) configureStream(options);
    late final StreamController<SuperGpsEvent> controller;
    void listener(SuperGpsEvent event) {
      if (!controller.isClosed) controller.add(event);
    }

    controller = StreamController<SuperGpsEvent>.broadcast(
      onListen: () {
        _listeners.add(listener);
        if (!_running) {
          unawaited(_startStream());
        }
      },
      onCancel: () {
        _listeners.remove(listener);
        if (_listeners.isEmpty) {
          unawaited(_stopStream());
        }
      },
    );
    return controller.stream;
  }

  Future<bool> isBarometerHardwareSupported() async {
    return _barometer.isHardwareSupportedProbe();
  }

  Future<SuperGpsEvent?> getCurrentPosition({bool enableBarometer = false}) async {
    if (!_running) {
      _kalman.reset();
      _fixGate.reset();
    }

    final shouldRunBaro = enableBarometer && await isBarometerHardwareSupported();
    if (shouldRunBaro) {
      await _barometer.start();
      await _barometer.awaitFirstReading();
    }

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          _isLocationFresh(last, _fastCacheMaxAge) &&
          last.accuracy <= _oneShotBestAccuracyM) {
        final event = _buildOneShotEventIfAccepted(
          last,
          includeBarometer: shouldRunBaro,
        );
        if (event != null) return event;
      }

      Position? fresh;
      try {
        fresh = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            timeLimit: _currentLocMaxWait,
          ),
        );
      } catch (_) {
        fresh = null;
      }

      final best = _pickBestPosition(fresh, last);
      if (best != null) {
        final event = _buildOneShotEventIfAccepted(
          best,
          includeBarometer: shouldRunBaro,
        );
        if (event != null) return event;
      }
      return null;
    } finally {
      if (shouldRunBaro && !_running) {
        await _barometer.stop();
      }
    }
  }

  Future<void> _startStream() async {
    if (_running) return;
    _streamGeneration++;
    final generation = _streamGeneration;
    _kalman.reset();
    _fixGate.reset();

    final wantBaro =
        _streamOptions.enableBarometer && await isBarometerHardwareSupported();
    if (wantBaro) {
      await _barometer.reset();
      await _barometer.start();
      await _barometer.awaitFirstReading();
      if (generation != _streamGeneration || _listeners.isEmpty) return;
    } else {
      await _barometer.stop();
    }

    await _seedCachedPositions();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: _streamOptions.toLocationSettings(),
    ).listen(
      (position) => _tryEmitLocation(position, SuperGpsFixSource.stream),
      onError: (Object error, StackTrace stack) {
        if (kDebugMode) {
          debugPrint('SuperGpsEngine stream error: $error');
        }
      },
      cancelOnError: false,
    );

    _running = true;
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(milliseconds: 4500), () {
      final fallback = _fixGate.peekStreamFallbackLocation();
      if (fallback != null) {
        _fixGate.noteAccepted(fallback);
        _emitFiltered(fallback);
      }
    });
  }

  Future<void> _restartStream() async {
    await _stopStream();
    if (_listeners.isNotEmpty) {
      await _startStream();
    }
  }

  /// Stops Geolocator stream, barometer, and timers (e.g. before background engine detach).
  Future<void> forceStop() async {
    _listeners.clear();
    await _stopStream();
  }

  Future<void> _stopStream() async {
    _streamGeneration++;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    await _positionSub?.cancel();
    _positionSub = null;
    _running = false;
    await _barometer.stop();
    _kalman.reset();
    _fixGate.reset();
  }

  Future<void> _seedCachedPositions() async {
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      _tryEmitLocation(last, SuperGpsFixSource.seedCache);
    }
    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 30),
        ),
      );
      _tryEmitLocation(current, SuperGpsFixSource.seedCache);
    } catch (_) {
      // Ignore seed timeout.
    }
  }

  void _tryEmitLocation(Position location, SuperGpsFixSource source) {
    if (_fixGate.shouldAccept(location, source)) {
      _fixGate.noteAccepted(location);
      _emitFiltered(location);
      return;
    }
    final fallback = _fixGate.peekStreamFallbackLocation();
    if (fallback == null) return;
    _fixGate.noteAccepted(fallback);
    _emitFiltered(fallback);
  }

  SuperGpsEvent? _buildOneShotEventIfAccepted(
    Position location, {
    required bool includeBarometer,
  }) {
    if (!_fixGate.shouldAccept(location, SuperGpsFixSource.oneShot)) {
      return null;
    }
    _fixGate.noteAccepted(location);
    return _buildEvent(location, includeBarometer: includeBarometer);
  }

  void _emitFiltered(Position location) {
    final event = _buildEvent(
      location,
      includeBarometer:
          _streamOptions.enableBarometer && _barometer.hasHardwareSupport,
    );
    for (final listener in List<void Function(SuperGpsEvent)>.from(_listeners)) {
      listener(event);
    }
  }

  SuperGpsEvent _buildEvent(
    Position location, {
    required bool includeBarometer,
  }) {
    final filtered = _kalman.process(
      latitude: location.latitude,
      longitude: location.longitude,
      accuracyM: location.accuracy.isFinite && location.accuracy > 0
          ? location.accuracy
          : _oneShotBestAccuracyM,
      speedMps: location.speed >= 0 ? location.speed : 0,
      timestampMs: location.timestamp.millisecondsSinceEpoch,
    );

    return SuperGpsEvent(
      position: _filteredPosition(location, filtered.lat, filtered.lng),
      barometricAltitude:
          includeBarometer ? _barometer.latestAltitudeM : null,
      barometerHardwareSupported: _barometer.hasHardwareSupport,
    );
  }

  static Position _filteredPosition(
    Position raw,
    double lat,
    double lng,
  ) {
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: raw.timestamp,
      accuracy: raw.accuracy,
      altitude: raw.altitude,
      altitudeAccuracy: raw.altitudeAccuracy,
      heading: raw.heading,
      headingAccuracy: raw.headingAccuracy,
      speed: raw.speed,
      speedAccuracy: raw.speedAccuracy,
      floor: raw.floor,
      isMocked: raw.isMocked,
    );
  }

  static bool _isLocationFresh(Position location, Duration maxAge) {
    final age = DateTime.now().difference(location.timestamp);
    return !age.isNegative && age <= maxAge;
  }

  static Position? _pickBestPosition(Position? a, Position? b) {
    final candidates = [a, b].whereType<Position>().toList();
    if (candidates.isEmpty) return null;
    candidates.sort((x, y) => x.accuracy.compareTo(y.accuracy));
    return candidates.first;
  }
}
