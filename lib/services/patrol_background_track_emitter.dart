import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../utils/super_gps_service.dart';
import 'patrol_background_gps_hub.dart';
import 'patrol_background_service.dart';
import 'patrol_realtime_track_service.dart';
import 'patrol_tracking_config_store.dart';

/// STOMP location emit — subscribes to [PatrolBackgroundGpsHub] only (no auto-scan).
class PatrolBackgroundTrackEmitter {
  PatrolBackgroundTrackEmitter(this._hub);

  final PatrolBackgroundGpsHub _hub;

  Position? _anchor;
  var _active = false;
  var _emitInFlight = false;
  Position? _pendingEmitPosition;

  bool get isActive => _active;
  bool get isListening => _active && _hub.isListening;

  Future<void> start() async {
    _hub.trackHandler = _onGpsEvent;
    _active = true;
    await _hub.ensureRunning();
    // Re-bind if a concurrent hub shutdown ran between assignment and ensureRunning.
    if (_active && _hub.trackHandler != _onGpsEvent) {
      _hub.trackHandler = _onGpsEvent;
      await _hub.ensureRunning();
    }
  }

  Future<void> stop() async {
    if (!_active) return;
    _hub.trackHandler = null;
    _active = false;
    _pendingEmitPosition = null;
    _emitInFlight = false;
    _anchor = null;
    await _hub.ensureRunning();
  }

  void _onGpsEvent(SuperGpsEvent event) {
    if (!_active) return;
    _pendingEmitPosition = event.position;
    if (_emitInFlight) return;
    _emitInFlight = true;
    unawaited(_drainEmitQueue());
  }

  Future<void> _drainEmitQueue() async {
    try {
      while (_active) {
        final pos = _pendingEmitPosition;
        _pendingEmitPosition = null;
        if (pos == null) break;
        await _emitPosition(pos);
      }
    } finally {
      _emitInFlight = false;
      if (_active && _pendingEmitPosition != null) {
        _emitInFlight = true;
        unawaited(_drainEmitQueue());
      }
    }
  }

  Future<void> _emitPosition(Position pos) async {
    if (!_active) return;
    final minMoveM = await PatrolTrackingConfigStore.minMoveM();
    if (_anchor != null) {
      final moved = Geolocator.distanceBetween(
        _anchor!.latitude,
        _anchor!.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (moved < minMoveM) return;
    }
    _anchor = pos;
    PatrolBackgroundService.notifyPositionUpdateFromFgs(pos);
    await PatrolRealtimeTrackService.instance.handlePositionFromBackground(pos);
  }
}
