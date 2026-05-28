import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../barometric_altitude.dart';

/// Pressure sensor → barometric altitude (ISA sea level 1013.25 hPa).
class SuperGpsBarometer {
  StreamSubscription<BarometerEvent>? _sub;
  double? _latestAltitudeM;
  bool _active = false;
  Completer<void>? _firstReadingCompleter;
  var _firstReadingSignaled = false;
  var _hardwareChecked = false;
  var _hardwareSupported = false;

  double? get latestAltitudeM => _latestAltitudeM;

  bool get hasHardwareSupport {
    if (!_hardwareChecked) {
      _hardwareChecked = true;
      _hardwareSupported = !kIsWeb;
    }
    return _hardwareSupported;
  }

  bool get isActive => _active;

  Future<bool> isHardwareSupportedProbe() async {
    if (kIsWeb) return false;
    StreamSubscription<BarometerEvent>? probe;
    final firstReading = Completer<void>();
    try {
      probe = barometerEventStream().listen((_) {
        if (!firstReading.isCompleted) firstReading.complete();
      });
      await firstReading.future.timeout(const Duration(milliseconds: 400));
      _hardwareSupported = true;
    } on MissingPluginException {
      _hardwareSupported = false;
    } on PlatformException {
      _hardwareSupported = false;
    } catch (_) {
      _hardwareSupported = false;
    } finally {
      await probe?.cancel();
    }
    _hardwareChecked = true;
    return _hardwareSupported;
  }

  Future<void> start() async {
    if (_active) return;
    _firstReadingCompleter = Completer<void>();
    _firstReadingSignaled = false;

    try {
      _sub = barometerEventStream().listen((event) {
        final altitude = altitudeMetersFromPressureHpa(event.pressure);
        if (altitude.isFinite) {
          _latestAltitudeM = altitude;
          _signalFirstReading();
        }
      });
      _active = true;
      _hardwareSupported = true;
      _hardwareChecked = true;
    } on MissingPluginException {
      _hardwareSupported = false;
      _hardwareChecked = true;
      _active = false;
    } on PlatformException {
      _hardwareSupported = false;
      _hardwareChecked = true;
      _active = false;
    } catch (_) {
      _hardwareSupported = false;
      _hardwareChecked = true;
      _active = false;
    }
  }

  Future<bool> awaitFirstReading({
    Duration timeout = const Duration(milliseconds: 800),
  }) async {
    if (_latestAltitudeM != null) return true;
    final completer = _firstReadingCompleter;
    if (completer == null) return false;
    try {
      await completer.future.timeout(timeout);
    } catch (_) {
      // Timed out.
    }
    return _latestAltitudeM != null;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _active = false;
    _firstReadingCompleter = null;
  }

  Future<void> reset() async {
    await stop();
    _latestAltitudeM = null;
    _firstReadingSignaled = false;
  }

  void _signalFirstReading() {
    if (_firstReadingSignaled) return;
    _firstReadingSignaled = true;
    final completer = _firstReadingCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }
}
