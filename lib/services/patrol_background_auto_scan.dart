import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import '../models/check_point.dart';
import '../utils/check_point_proximity.dart';
import '../utils/device_location.dart';
import '../utils/super_gps_service.dart';
import '../utils/patrol_checkpoint_success_feedback.dart';
import 'patrol_active_round_cache.dart';
import 'patrol_background_socket_emitter.dart';
import 'patrol_log_service.dart';

/// Background GPS auto-scan — shares one Super GPS stream with socket tracking.
class PatrolBackgroundAutoScan {
  PatrolBackgroundAutoScan(this._socketEmitter);

  final PatrolBackgroundSocketEmitter _socketEmitter;
  bool _submitting = false;
  var _autoScanPaused = false;
  var _autoScanActive = false;
  Future<void>? _ensureWatchRunningFuture;

  /// `true` when auto-scan is attached to the shared background GPS stream.
  bool get isAutoScanActive => _autoScanActive;

  /// Stops auto-scan callbacks; keeps shared socket GPS when patrol emit is still on.
  Future<void> stop() async {
    _autoScanActive = false;
    _submitting = false;
    await _socketEmitter.start(enableBarometer: false);
  }

  void pause() {
    _autoScanPaused = true;
    unawaited(stop());
  }

  Future<void> resume() async {
    _autoScanPaused = false;
    await _ensureWatchRunning();
  }

  Future<void> refresh() async {
    if (_autoScanPaused || await _isForegroundScanBusy()) {
      await stop();
      return;
    }
    await _ensureWatchRunning();
  }

  Future<void> _ensureWatchRunning() async {
    if (_ensureWatchRunningFuture != null) {
      return _ensureWatchRunningFuture;
    }
    final future = _ensureWatchRunningImpl();
    _ensureWatchRunningFuture = future;
    try {
      await future;
    } finally {
      if (identical(_ensureWatchRunningFuture, future)) {
        _ensureWatchRunningFuture = null;
      }
    }
  }

  Future<void> _ensureWatchRunningImpl() async {
    final prefs = await SharedPreferences.getInstance();
    final emit = prefs.getBool(StorageKeys.patrolTrackEmitEnabled) ?? false;
    final autoScan =
        prefs.getBool(StorageKeys.patrolTrackBackgroundAutoScanEnabled) ??
            false;
    if (!emit || !autoScan || _autoScanPaused) {
      if (_autoScanActive) await stop();
      return;
    }
    if (await _isForegroundScanBusy()) {
      if (_autoScanActive) await stop();
      return;
    }
    if (_autoScanActive) return;

    final cached = await PatrolActiveRoundCache.load();
    if (cached == null) return;

    final eligible = _eligibleCheckPoints(cached.checkPoints);
    if (eligible.isEmpty) return;

    final needsBaro = eligible.any((p) => p.baroAltitude != null);
    final roundId = cached.roundId;

    await _socketEmitter.start(
      enableBarometer: needsBaro,
      onAutoScanEvent: (event) {
        if (_autoScanPaused || _submitting) return;
        unawaited(
          _handleAutoScanSample(
            roundId: roundId,
            needsBaroValidation: needsBaro,
            sample: _sampleFromEvent(event),
            barometerListening:
                needsBaro && event.barometerHardwareSupported,
          ),
        );
      },
    );

    _autoScanActive =
        _socketEmitter.hasAutoScanHandler && _socketEmitter.isListening;
    if (!_autoScanActive && kDebugMode) {
      debugPrint('PatrolBackgroundAutoScan: failed to attach to GPS stream');
    }
  }

  Future<void> _handleAutoScanSample({
    required int roundId,
    required bool needsBaroValidation,
    required bool barometerListening,
    required DeviceLocationSample sample,
  }) async {
    if (_autoScanPaused || _submitting) return;
    if (await _isForegroundScanBusy()) {
      pause();
      return;
    }

    final cached = await PatrolActiveRoundCache.load();
    if (cached == null || cached.roundId != roundId) return;

    final pending = _eligibleCheckPoints(cached.checkPoints);
    if (pending.isEmpty) {
      await stop();
      return;
    }

    final validateBaro = needsBaroValidation && barometerListening;
    final matched = _matchFirstEligible(pending, sample, validateBaro);
    if (matched == null) return;

    _submitting = true;
    try {
      final pos = sample.position;
      final gpsAlt = pos.altitude.isFinite ? pos.altitude : null;
      final result = await PatrolLogService.instance.createPatrolLog(
        PatrolLogSubmit(
          roundId: roundId,
          checkpointId: matched.id,
          siteId: matched.siteId,
          scanTime: DateTime.now(),
          latitude: sample.latitude,
          longitude: sample.longitude,
          gpsAltitude: gpsAlt,
          baroAltitude: sample.baroAltitude,
          verified: true,
        ),
      );
      if (result.ok) {
        await PatrolCheckpointSuccessFeedback.notify(
          checkpointName: matched.name,
        );
        await PatrolActiveRoundCache.markCheckpointVerified(matched.id);
      }
    } finally {
      _submitting = false;
    }
  }

  static DeviceLocationSample _sampleFromEvent(SuperGpsEvent event) {
    final pos = event.position;
    final gpsAlt = pos.altitude.isFinite ? pos.altitude : null;
    return (
      position: pos,
      latitude: pos.latitude,
      longitude: pos.longitude,
      gpsAltitude: gpsAlt,
      baroAltitude: event.barometricAltitude,
    );
  }

  static List<CheckPoint> _eligibleCheckPoints(List<CheckPoint> points) {
    final out = <CheckPoint>[];
    for (final p in points) {
      if (p.verified == true) continue;
      if (!p.hasCoordinates) continue;
      out.add(p);
    }
    out.sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));
    return out;
  }

  static CheckPoint? _matchFirstEligible(
    List<CheckPoint> points,
    DeviceLocationSample sample,
    bool baroListening,
  ) {
    if (points.isEmpty) return null;
    final point = points.first;
    final pos = sample.position;
    final validateBaro = point.baroAltitude != null && baroListening;
    final gpsAlt = pos.altitude.isFinite ? pos.altitude : null;
    final evaluation = evaluateCheckPointProximity(
      checkpoint: point,
      latitude: sample.latitude,
      longitude: sample.longitude,
      gpsAltitude: gpsAlt,
      baroAltitude: sample.baroAltitude,
      validateBaroAltitude: validateBaro,
      horizontalAccuracyM: pos.accuracy,
      gpsAltitudeAccuracyM: pos.altitudeAccuracy,
    );
    return evaluation.result.ok ? point : null;
  }

  static Future<bool> _isForegroundScanBusy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageKeys.patrolTrackForegroundScanBusy) ?? false;
  }
}
