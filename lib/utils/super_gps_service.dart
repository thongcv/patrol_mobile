import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'super_gps/super_gps_engine.dart';

export 'super_gps/super_gps_engine.dart' show SuperGpsEvent, SuperGpsStreamOptions;

/// High-accuracy GPS via Geolocator + Kalman filter + fix quality gate.
class SuperGpsService {
  SuperGpsService._();

  static final SuperGpsService instance = SuperGpsService._();

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static SuperGpsStreamOptions _streamOptions = SuperGpsStreamOptions.defaults;

  static void configureStream(SuperGpsStreamOptions options) {
    _streamOptions = options;
    SuperGpsEngine.instance.configureStream(options);
    _resetStreamCache();
  }

  static SuperGpsStreamOptions get streamOptions => _streamOptions;

  static Stream<SuperGpsEvent>? _locationEventBroadcast;

  static void _resetStreamCache() {
    _locationEventBroadcast = null;
  }

  /// Tears down the shared engine stream (background isolate shutdown).
  static Future<void> shutdown() async {
    await SuperGpsEngine.instance.forceStop();
    _resetStreamCache();
  }

  Stream<SuperGpsEvent> get locationEventStream {
    _locationEventBroadcast ??= SuperGpsEngine.instance
        .events(options: _streamOptions)
        .asBroadcastStream();
    return _locationEventBroadcast!;
  }

  Stream<Position> get positionStream =>
      locationEventStream.map((e) => e.position);

  static Future<SuperGpsEvent?> getCurrentLocation({
    bool enableBarometer = false,
  }) {
    if (!isSupported) return Future.value();
    return SuperGpsEngine.instance.getCurrentPosition(
      enableBarometer: enableBarometer,
    );
  }

  static Future<bool> isBarometerHardwareSupported() {
    if (!isSupported) return Future.value(false);
    return SuperGpsEngine.instance.isBarometerHardwareSupported();
  }
}

/// Backward-compatible aliases (prefer [SuperGps*] names in new code).
typedef NativeGpsEvent = SuperGpsEvent;
typedef GpsNativeStreamOptions = SuperGpsStreamOptions;
typedef GpsNativeService = SuperGpsService;
