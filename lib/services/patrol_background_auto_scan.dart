import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import '../models/check_point.dart';
import '../utils/check_point_proximity.dart';
import '../utils/device_location.dart';
import '../utils/super_gps_service.dart';
import '../utils/patrol_checkpoint_success_feedback.dart';
import 'patrol_active_round_cache.dart';
import 'patrol_active_round_sync.dart';
import 'patrol_background_isolate_flags.dart';
import 'patrol_background_service.dart';
import 'patrol_background_socket_emitter.dart';
import 'patrol_log_service.dart';

/// Background GPS auto-scan — shares one Super GPS stream with socket tracking.
class PatrolBackgroundAutoScan {
  PatrolBackgroundAutoScan(this._socketEmitter);

  final PatrolBackgroundSocketEmitter _socketEmitter;
  var _autoScanPaused = false;
  var _autoScanActive = false;
  Future<void>? _ensureWatchRunningFuture;
  /// Serializes stop / pause / resume / refresh (avoids GPS start-stop races).
  Future<void>? _lifecycleChain;
  /// Serializes GPS samples so only one submit runs at a time.
  Future<void>? _sampleProcessingChain;
  static const Duration _patrolLogSubmitTimeout = Duration(seconds: 20);
  /// Checkpoint ids with an in-flight patrol-log POST.
  final Set<int> _inFlightCheckpointIds = {};
  /// Checkpoints already submitted or optimistically marked this round (survives refresh/stop).
  final Set<int> _submittedCheckpointIds = {};
  /// Latest active-round snapshot for auto-scan (refreshed after verify).
  ({int roundId, List<CheckPoint> checkPoints})? _activeRoundSnapshot;

  /// `true` when auto-scan is attached to the shared background GPS stream.
  bool get isAutoScanActive => _autoScanActive;

  /// Stops auto-scan callbacks; keeps shared socket GPS only while patrol emit is on.
  Future<void> stop() => _enqueueLifecycle(_stopImpl);

  Future<void> pause() => _enqueueLifecycle(() async {
    _autoScanPaused = true;
    await _stopImpl();
  });

  Future<void> resume() => _enqueueLifecycle(() async {
    _autoScanPaused = false;
    await _ensureWatchRunning();
  });

  /// Re-reads prefs and (re)starts auto-scan when needed.
  ///
  /// Used by [PatrolBackgroundRunner.refreshTracking] (FGS invoke `refresh`, 45s poll).
  /// If auto-scan is already active, skips GPS handler reattach to avoid stop/start churn.
  Future<void> refresh() => _enqueueLifecycle(_refreshImpl);

  /// Re-reads cache after [PatrolActiveRoundSync.fetchAndPersist] (STOMP round sync).
  ///
  /// Unlike [refresh], always passes [forceReattach] so new checkpoints / round data
  /// are picked up even when `_autoScanActive` is already true.
  /// Do not call full [PatrolBackgroundRunner.refreshTracking] from STOMP — that also
  /// reconnects socket/token and can cause refresh loops.
  Future<void> reloadAfterRoundPersist() =>
      _enqueueLifecycle(_reloadAfterRoundPersistImpl);

  Future<void> _reloadAfterRoundPersistImpl() async {
    if (_autoScanPaused || await _isForegroundScanBusy()) {
      await _stopImpl();
      return;
    }
    await _ensureWatchRunning(forceReattach: true);
  }

  Future<void> _refreshImpl() async {
    if (_autoScanPaused || await _isForegroundScanBusy()) {
      await _stopImpl();
      return;
    }
    await _ensureWatchRunning();
  }

  Future<void> _enqueueLifecycle(Future<void> Function() action) {
    _lifecycleChain =
        (_lifecycleChain ?? Future<void>.value()).then((_) => action());
    return _lifecycleChain!;
  }

  Future<void> _stopImpl() async {
    _autoScanActive = false;
    // Keep _sampleProcessingChain, _inFlightCheckpointIds, _submittedCheckpointIds,
    // and _activeRoundSnapshot — refresh/stop must not unblock in-flight POSTs.

    final prefs = await SharedPreferences.getInstance();
    final emit = prefs.getBool(StorageKeys.patrolTrackEmitEnabled) ?? false;
    if (!emit) {
      await _socketEmitter.stop();
      return;
    }
    await _socketEmitter.start(enableBarometer: false);
  }

  Future<void> _ensureWatchRunning({bool forceReattach = false}) async {
    if (_ensureWatchRunningFuture != null) {
      return _ensureWatchRunningFuture;
    }
    final future = _ensureWatchRunningImpl(forceReattach: forceReattach);
    _ensureWatchRunningFuture = future;
    try {
      await future;
    } finally {
      if (identical(_ensureWatchRunningFuture, future)) {
        _ensureWatchRunningFuture = null;
      }
    }
  }

  Future<void> _ensureWatchRunningImpl({bool forceReattach = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final emit = prefs.getBool(StorageKeys.patrolTrackEmitEnabled) ?? false;
    final autoScan =
        prefs.getBool(StorageKeys.patrolTrackBackgroundAutoScanEnabled) ??
            false;
    if (!emit || !autoScan || _autoScanPaused) {
      if (_autoScanActive) await _stopImpl();
      return;
    }
    if (await _isForegroundScanBusy()) {
      if (_autoScanActive) await _stopImpl();
      return;
    }
    final cached = await PatrolActiveRoundCache.load();
    if (cached == null) {
      _activeRoundSnapshot = null;
      _submittedCheckpointIds.clear();
      return;
    }
    if (_activeRoundSnapshot?.roundId != cached.roundId) {
      _submittedCheckpointIds.clear();
    }
    _activeRoundSnapshot = await _mergeSnapshotWithMemory(cached);

    var eligible = _eligibleCheckPoints(_activeRoundSnapshot!.checkPoints);
    if (eligible.isEmpty &&
        _hasUnverifiedWithoutCoordinates(_activeRoundSnapshot!.checkPoints)) {
      final enriched = await PatrolActiveRoundSync.enrichCheckPointsFromSite(
        _activeRoundSnapshot!.checkPoints,
      );
      await PatrolActiveRoundCache.patchCheckPoints(enriched);
      _activeRoundSnapshot = await _mergeSnapshotWithMemory(
        (roundId: _activeRoundSnapshot!.roundId, checkPoints: enriched),
      );
      eligible = _eligibleCheckPoints(_activeRoundSnapshot!.checkPoints);
    }
    if (eligible.isEmpty) {
      if (_autoScanActive) await _stopImpl();
      return;
    }

    // Normal refresh: skip when handler already attached. STOMP reload: always reattach.
    if (_autoScanActive && !forceReattach) return;

    // sensors_plus is not registered in the FGS isolate — GPS-only auto-scan there.
    final needsBaro = !PatrolBackgroundIsolateFlags.active &&
        eligible.any((p) => p.baroAltitude != null);

    await _socketEmitter.start(
      enableBarometer: needsBaro,
      onAutoScanEvent: (event) {
        if (_autoScanPaused) return;
        final snapshot = _activeRoundSnapshot;
        if (snapshot == null) return;
        _enqueueAutoScanSample(
          needsBaroValidation: needsBaro,
          sample: _sampleFromEvent(event),
          barometerListening: needsBaro && event.barometerHardwareSupported,
        );
      },
    );

    _autoScanActive =
        _socketEmitter.hasAutoScanHandler && _socketEmitter.isListening;
  }

  void _enqueueAutoScanSample({
    required bool needsBaroValidation,
    required DeviceLocationSample sample,
    required bool barometerListening,
  }) {
    _sampleProcessingChain =
        (_sampleProcessingChain ?? Future<void>.value()).then(
      (_) => _handleAutoScanSample(
        needsBaroValidation: needsBaroValidation,
        sample: sample,
        barometerListening: barometerListening,
      ),
      onError: (Object error, StackTrace stack) {},
    );
  }

  Future<void> _handleAutoScanSample({
    required bool needsBaroValidation,
    required bool barometerListening,
    required DeviceLocationSample sample,
  }) async {
    if (_autoScanPaused) return;
    if (await _isForegroundScanBusy()) return;

    final active = await _currentActiveSnapshot();
    if (active == null) return;

    final unverified = _eligibleCheckPoints(active.checkPoints);
    if (unverified.isEmpty) {
      await stop();
      return;
    }

    final pending = unverified
        .where(
          (p) =>
              !_inFlightCheckpointIds.contains(p.id) &&
              !_submittedCheckpointIds.contains(p.id),
        )
        .toList();
    // All remaining checkpoints are in-flight — wait for API, keep auto-scan on.
    if (pending.isEmpty) return;

    final validateBaro = needsBaroValidation && barometerListening;
    final matched = _matchFirstEligible(pending, sample, validateBaro);
    if (matched == null) return;

    if (!_inFlightCheckpointIds.add(matched.id)) return;

    if (await PatrolActiveRoundCache.isCheckpointVerified(matched.id) ||
        _isCheckpointVerifiedInSnapshot(matched.id)) {
      _markSnapshotCheckpointVerified(matched.id);
      _submittedCheckpointIds.add(matched.id);
      _inFlightCheckpointIds.remove(matched.id);
      return;
    }

    _submittedCheckpointIds.add(matched.id);
    _markSnapshotCheckpointVerified(matched.id);

    try {
      final pos = sample.position;
      final gpsAlt = pos.altitude.isFinite ? pos.altitude : null;
      final result = await PatrolLogService.instance
          .createPatrolLog(
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
          )
          .timeout(_patrolLogSubmitTimeout);
      if (result.ok) {
        await PatrolActiveRoundCache.markCheckpointVerified(matched.id);
        PatrolBackgroundService.notifyActiveRoundChangedFromFgs();
        await PatrolCheckpointSuccessFeedback.notify(
          checkpointName: matched.name,
        );
      } else if (!await PatrolActiveRoundCache.isCheckpointVerified(matched.id)) {
        _revertSnapshotCheckpointVerified(matched.id);
        _submittedCheckpointIds.remove(matched.id);
      }
    } on TimeoutException {
      if (!await PatrolActiveRoundCache.isCheckpointVerified(matched.id)) {
        _revertSnapshotCheckpointVerified(matched.id);
        _submittedCheckpointIds.remove(matched.id);
      }
    } catch (_) {
      if (!await PatrolActiveRoundCache.isCheckpointVerified(matched.id)) {
        _revertSnapshotCheckpointVerified(matched.id);
        _submittedCheckpointIds.remove(matched.id);
      }
    } finally {
      _inFlightCheckpointIds.remove(matched.id);
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

  /// Merges in-memory `verified` flags into prefs snapshot (cache may lag behind POST).
  Future<({int roundId, List<CheckPoint> checkPoints})> _mergeSnapshotWithMemory(
    ({int roundId, List<CheckPoint> checkPoints}) loaded,
  ) async {
    final mem = _activeRoundSnapshot;
    final verifiedIds = <int>{
      if (mem != null && mem.roundId == loaded.roundId)
        for (final p in mem.checkPoints)
          if (p.verified == true) p.id,
    };
    if (verifiedIds.isEmpty) return loaded;
    return (
      roundId: loaded.roundId,
      checkPoints: [
        for (final p in loaded.checkPoints)
          verifiedIds.contains(p.id) ? p.copyWith(verified: true) : p,
      ],
    );
  }

  Future<({int roundId, List<CheckPoint> checkPoints})?> _currentActiveSnapshot() async {
    final loaded = await PatrolActiveRoundCache.load();
    if (loaded == null) {
      _activeRoundSnapshot = null;
      return null;
    }
    if (_activeRoundSnapshot?.roundId != loaded.roundId) {
      _submittedCheckpointIds.clear();
    }
    final merged = await _mergeSnapshotWithMemory(loaded);
    _activeRoundSnapshot = merged;
    return merged;
  }

  bool _isCheckpointVerifiedInSnapshot(int checkpointId) {
    final snapshot = _activeRoundSnapshot;
    if (snapshot == null) return false;
    return snapshot.checkPoints.any(
      (p) => p.id == checkpointId && p.verified == true,
    );
  }

  void _markSnapshotCheckpointVerified(int checkpointId) {
    final snapshot = _activeRoundSnapshot;
    if (snapshot == null) return;
    _activeRoundSnapshot = (
      roundId: snapshot.roundId,
      checkPoints: [
        for (final p in snapshot.checkPoints)
          p.id == checkpointId ? p.copyWith(verified: true) : p,
      ],
    );
  }

  void _revertSnapshotCheckpointVerified(int checkpointId) {
    final snapshot = _activeRoundSnapshot;
    if (snapshot == null) return;
    _activeRoundSnapshot = (
      roundId: snapshot.roundId,
      checkPoints: [
        for (final p in snapshot.checkPoints)
          p.id == checkpointId ? p.copyWith(verified: false) : p,
      ],
    );
  }

  static bool _hasUnverifiedWithoutCoordinates(List<CheckPoint> points) {
    return points.any((p) => p.verified != true && !p.hasCoordinates);
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
    // Barometer altitude is optional: validate it only when the checkpoint
    // requires baroAltitude and the device is actually listening to barometer.
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
