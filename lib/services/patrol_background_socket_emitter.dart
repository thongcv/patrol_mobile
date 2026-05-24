import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/super_gps_service.dart';
import 'patrol_realtime_track_service.dart';

typedef PatrolBackgroundGpsHandler = void Function(SuperGpsEvent event);

/// Background GPS for socket + auto-scan (Geolocator + Super GPS filters).
class PatrolBackgroundSocketEmitter {
  PatrolBackgroundSocketEmitter();

  static const double _minMoveM = 0;

  StreamSubscription<SuperGpsEvent>? _gpsSub;
  Position? _anchor;
  PatrolBackgroundGpsHandler? _autoScanHandler;
  var _enableBarometer = false;
  var _listening = false;
  var _stopped = true;

  bool get isListening => _listening;
  bool get hasAutoScanHandler => _autoScanHandler != null;

  Future<void> start({
    bool enableBarometer = false,
    PatrolBackgroundGpsHandler? onAutoScanEvent,
  }) async {
    final optionsChanged =
        _listening && _enableBarometer != enableBarometer;
    _autoScanHandler = onAutoScanEvent;
    _enableBarometer = enableBarometer;

    if (_listening && !optionsChanged) return;

    _stopped = false;
    await _cancelSubscription();

    final denied = await _ensureBackgroundLocationReady();
    if (denied != null) {
      if (kDebugMode) {
        debugPrint('PatrolBackgroundSocketEmitter: location not ready ($denied)');
      }
      return;
    }

    if (!SuperGpsService.isSupported) return;

    SuperGpsService.configureStream(
      SuperGpsStreamOptions(
        updateIntervalMs: 1000,
        minUpdateIntervalMs: 800,
        minUpdateDistanceMeters: 0,
        enableBarometer: enableBarometer,
      ),
    );

    _gpsSub = SuperGpsService.instance.locationEventStream.listen(
      (event) => unawaited(_dispatchEvent(event)),
      onError: (Object error, StackTrace stack) {
        if (kDebugMode) {
          debugPrint('PatrolBackgroundSocketEmitter GPS error: $error');
        }
      },
      cancelOnError: false,
    );

    _listening = true;
    if (kDebugMode) {
      debugPrint('PatrolBackgroundSocketEmitter: Super GPS stream active');
    }
  }

  Future<void> stop() async {
    _stopped = true;
    _autoScanHandler = null;
    _enableBarometer = false;
    await _cancelSubscription();
    await SuperGpsService.shutdown();
  }

  Future<void> _cancelSubscription() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
    _anchor = null;
    _listening = false;
  }

  Future<void> _dispatchEvent(SuperGpsEvent event) async {
    if (_stopped) return;
    await emitPosition(event.position);
    if (_stopped) return;
    _autoScanHandler?.call(event);
  }

  Future<void> emitPosition(Position pos) async {
    if (_stopped) return;
    if (_anchor != null) {
      final moved = Geolocator.distanceBetween(
        _anchor!.latitude,
        _anchor!.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (moved < _minMoveM) return;
    }
    _anchor = pos;
    await PatrolRealtimeTrackService.instance.handlePositionFromBackground(pos);
  }

  static Future<String?> _ensureBackgroundLocationReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return 'service';

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return 'denied';
    }

    return null;
  }
}
