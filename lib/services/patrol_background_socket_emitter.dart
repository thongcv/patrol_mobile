import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../utils/device_location.dart';
import '../utils/super_gps_service.dart';
import 'patrol_realtime_track_service.dart';
import 'patrol_tracking_config_store.dart';

typedef PatrolBackgroundGpsHandler = void Function(SuperGpsEvent event);

/// Background GPS for socket + auto-scan (Geolocator + Super GPS filters).
class PatrolBackgroundSocketEmitter {
  PatrolBackgroundSocketEmitter();

  double _minMoveM = 5.0;

  StreamSubscription<SuperGpsEvent>? _gpsSub;
  Position? _anchor;
  PatrolBackgroundGpsHandler? _autoScanHandler;
  var _enableBarometer = false;
  var _listening = false;
  var _stopped = true;
  var _emitInFlight = false;
  Position? _pendingEmitPosition;

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

    final denied = await checkPatrolBackgroundLocationForTracking();
    if (denied != null) {
      return;
    }

    if (!SuperGpsService.isSupported) return;

    _minMoveM = await PatrolTrackingConfigStore.minMoveM();

    SuperGpsService.configureStream(
      SuperGpsStreamOptions(
        updateIntervalMs: 1000,
        minUpdateIntervalMs: 800,
        minUpdateDistanceMeters: _minMoveM.round(),
        enableBarometer: enableBarometer,
      ),
    );

    _gpsSub = SuperGpsService.instance.locationEventStream.listen(
      (event) => unawaited(_dispatchEvent(event)),
      onError: (Object error, StackTrace stack) {},
      cancelOnError: false,
    );

    _listening = true;
  }

  Future<void> stop() async {
    _stopped = true;
    _autoScanHandler = null;
    _enableBarometer = false;
    _pendingEmitPosition = null;
    await _cancelSubscription();
    await SuperGpsService.shutdown();
  }

  Future<void> _cancelSubscription() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
    _anchor = null;
    _emitInFlight = false;
    _pendingEmitPosition = null;
    _listening = false;
  }

  Future<void> _dispatchEvent(SuperGpsEvent event) async {
    if (_stopped) return;
    // Auto-scan only enqueues work; run before socket emit so a slow STOMP send
    // does not stall proximity checks.
    _autoScanHandler?.call(event);
    if (_stopped) return;
    _pendingEmitPosition = event.position;
    if (_emitInFlight) return;
    _emitInFlight = true;
    unawaited(_drainEmitQueue());
  }

  Future<void> _drainEmitQueue() async {
    try {
      while (!_stopped) {
        final pos = _pendingEmitPosition;
        _pendingEmitPosition = null;
        if (pos == null) break;
        await emitPosition(pos);
      }
    } finally {
      _emitInFlight = false;
      if (!_stopped && _pendingEmitPosition != null) {
        _emitInFlight = true;
        unawaited(_drainEmitQueue());
      }
    }
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
}
