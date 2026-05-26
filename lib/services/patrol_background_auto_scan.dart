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
  var _autoScanPaused = false;
  var _autoScanActive = false;
  Future<void>? _ensureWatchRunningFuture;
  /// Serializes GPS samples so only one submit runs at a time.
  Future<void>? _sampleProcessingChain;
  /// Checkpoint ids with an in-flight patrol-log POST.
  final Set<int> _inFlightCheckpointIds = {};
  /// Latest active-round snapshot for auto-scan (refreshed after verify).
  ({int roundId, List<CheckPoint> checkPoints})? _activeRoundSnapshot;

  /// `true` when auto-scan is attached to the shared background GPS stream.
  bool get isAutoScanActive => _autoScanActive;

  /// Stops auto-scan callbacks; keeps shared socket GPS only while patrol emit is on.
  Future<void> stop() async {
    _autoScanActive = false;
    _sampleProcessingChain = null;
    _inFlightCheckpointIds.clear();
    _activeRoundSnapshot = null;

    final prefs = await SharedPreferences.getInstance();
    final emit = prefs.getBool(StorageKeys.patrolTrackEmitEnabled) ?? false;
    if (!emit) {
      await _socketEmitter.stop();
      return;
    }
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
    _activeRoundSnapshot = cached;

    final eligible = _eligibleCheckPoints(cached.checkPoints);
    if (eligible.isEmpty) return;

    final needsBaro = eligible.any((p) => p.baroAltitude != null);

    await _socketEmitter.start(
      enableBarometer: needsBaro,
      onAutoScanEvent: (event) {
        if (_autoScanPaused) return;
        final snapshot = _activeRoundSnapshot;
        if (snapshot == null) return;
        _enqueueAutoScanSample(
          cached: snapshot,
          needsBaroValidation: needsBaro,
          sample: _sampleFromEvent(event),
          barometerListening: needsBaro && event.barometerHardwareSupported,
        );
      },
    );

    _autoScanActive =
        _socketEmitter.hasAutoScanHandler && _socketEmitter.isListening;
    if (!_autoScanActive && kDebugMode) {
      debugPrint('PatrolBackgroundAutoScan: failed to attach to GPS stream');
    }
  }

  void _enqueueAutoScanSample({
    required ({int roundId, List<CheckPoint> checkPoints}) cached,
    required bool needsBaroValidation,
    required DeviceLocationSample sample,
    required bool barometerListening,
  }) {
    _sampleProcessingChain =
        (_sampleProcessingChain ?? Future<void>.value()).then(
      (_) => _handleAutoScanSample(
        cached: cached,
        needsBaroValidation: needsBaroValidation,
        sample: sample,
        barometerListening: barometerListening,
      ),
      onError: (Object error, StackTrace stack) {
        if (kDebugMode) {
          debugPrint('PatrolBackgroundAutoScan sample error: $error\n$stack');
        }
      },
    );
  }

  Future<void> _handleAutoScanSample({
    required ({int roundId, List<CheckPoint> checkPoints}) cached,
    required bool needsBaroValidation,
    required bool barometerListening,
    required DeviceLocationSample sample,
  }) async {
    if (_autoScanPaused) return;
    if (await _isForegroundScanBusy()) {
      pause();
      return;
    }

    final active = _activeRoundSnapshot != null &&
            _activeRoundSnapshot!.roundId == cached.roundId
        ? _activeRoundSnapshot!
        : cached;

    final unverified = _eligibleCheckPoints(active.checkPoints);
    if (unverified.isEmpty) {
      await stop();
      return;
    }

    final pending = unverified
        .where((p) => !_inFlightCheckpointIds.contains(p.id))
        .toList();
    // All remaining checkpoints are in-flight — wait for API, keep auto-scan on.
    if (pending.isEmpty) return;

    final validateBaro = needsBaroValidation && barometerListening;
    final matched = _matchFirstEligible(pending, sample, validateBaro);
    if (matched == null) return;

    if (!_inFlightCheckpointIds.add(matched.id)) return;

    try {
      final pos = sample.position;
      final gpsAlt = pos.altitude.isFinite ? pos.altitude : null;
      final result = await PatrolLogService.instance.createPatrolLog(
        PatrolLogSubmit(
          roundId: active.roundId,
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
        await PatrolActiveRoundCache.markCheckpointVerified(matched.id);
        _activeRoundSnapshot = await PatrolActiveRoundCache.load();
        _inFlightCheckpointIds.remove(matched.id);
        await PatrolCheckpointSuccessFeedback.notify(
          checkpointName: matched.name,
        );
      } else {
        _inFlightCheckpointIds.remove(matched.id);
      }
    } catch (e, st) {
      _inFlightCheckpointIds.remove(matched.id);
      if (kDebugMode) {
        debugPrint('PatrolBackgroundAutoScan submit error: $e\n$st');
      }
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
