import 'dart:async';

import '../models/check_point.dart';
import '../services/patrol_active_round_cache.dart';
import '../services/patrol_active_round_sync.dart';
import '../services/patrol_log_service.dart';
import '../services/patrol_tracking_config_store.dart';
import '../utils/check_point_proximity.dart';
import '../utils/device_location.dart';
import '../utils/patrol_checkpoint_success_feedback.dart';
import '../utils/super_gps_service.dart';
import 'patrol_background_gps_hub.dart';
import 'patrol_background_isolate_flags.dart';

/// Background checkpoint auto-scan — GPS via [PatrolBackgroundGpsHub] (shared with track).
class PatrolBackgroundAutoScan {
  PatrolBackgroundAutoScan(
    this._gpsHub, {
    void Function(CheckPoint point)? onCheckpointVerified,
  }) : _onCheckpointVerified = onCheckpointVerified;

  final PatrolBackgroundGpsHub _gpsHub;
  final void Function(CheckPoint point)? _onCheckpointVerified;
  var _autoScanPaused = false;
  var _autoScanActive = false;
  Future<void>? _ensureWatchRunningFuture;
  /// Serializes stop / resume detach-sync (reload/refresh run outside the chain).
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
  var _scanNeedsBaro = false;
  var _reloadInFlight = false;
  var _reloadAgain = false;

  /// `true` when auto-scan listener is attached on the shared GPS hub.
  bool get isAutoScanActive => _autoScanActive;

  /// Detaches auto-scan from the GPS hub (tracking may continue).
  Future<void> stop() => _enqueueLifecycle(_detachScan);

  Future<void> pause() async {
    if (_autoScanPaused) return;
    _autoScanPaused = true;
  }

  Future<void> resume() async {
    if (!_autoScanPaused) return;
    _autoScanPaused = false;
    if (!_autoScanActive) {
      await _enqueueLifecycle(_syncScanState);
    }
  }

  /// Re-reads prefs and (re)starts auto-scan when needed.
  Future<void> refresh() => _refreshImpl();

  /// Re-reads cache after [PatrolActiveRoundSync.fetchAndPersist] (STOMP round sync).
  /// Coalesces burst invokes; uses [_syncScanState] dedupe — not [_lifecycleChain].
  Future<void> reloadAfterRoundPersist() async {
    if (_reloadInFlight) {
      _reloadAgain = true;
      return;
    }
    _reloadInFlight = true;
    try {
      do {
        _reloadAgain = false;
        await _reloadAfterRoundPersistImpl();
      } while (_reloadAgain);
    } finally {
      _reloadInFlight = false;
    }
  }

  Future<void> _reloadAfterRoundPersistImpl() async {
    if (_autoScanPaused || await PatrolActiveRoundCache.isForegroundScanBusy()) {
      await _detachScan();
      return;
    }
    final cached = await PatrolActiveRoundCache.load();
    if (cached == null) {
      _resetAfterRoundFullyScanned();
      return;
    }
    _applyServerRoundSnapshot(cached);
    await _syncScanState();
  }

  Future<void> _refreshImpl() async {
    if (_autoScanPaused || await PatrolActiveRoundCache.isForegroundScanBusy()) {
      await _detachScan();
      return;
    }
    if (_autoScanActive) return;
    await _syncScanState();
  }

  /// Serializes stop / resume vs hub detach (reload/refresh bypass this chain).
  Future<void> _enqueueLifecycle(Future<void> Function() action) async {
    final wait = (_lifecycleChain ?? Future<void>.value()).catchError((_) {});
    final running = wait.then((_) async {
      try {
        await action();
      } catch (_) {
        // Keep the chain alive so later reload/refresh still runs.
      }
    });
    _lifecycleChain = running;
    await running;
  }

  Future<void> _detachScan() async {
    _autoScanActive = false;
    _gpsHub.autoScanHandler = null;
    _scanNeedsBaro = false;
    await _gpsHub.ensureRunning(scanWantsBarometer: false);
  }

  void _onGpsEvent(SuperGpsEvent event) {
    if (_autoScanPaused) return;
    final snapshot = _activeRoundSnapshot;
    if (snapshot == null) return;
    _enqueueAutoScanSample(
      needsBaroValidation: _scanNeedsBaro,
      sample: _sampleFromEvent(event),
      barometerListening:
          _scanNeedsBaro && event.barometerHardwareSupported,
    );
  }

  Future<void> _syncScanState() async {
    if (_ensureWatchRunningFuture != null) {
      return _ensureWatchRunningFuture;
    }
    final future = _syncScanStateImpl();
    _ensureWatchRunningFuture = future;
    try {
      await future;
    } finally {
      if (identical(_ensureWatchRunningFuture, future)) {
        _ensureWatchRunningFuture = null;
      }
    }
  }

  Future<void> _syncScanStateImpl() async {
    final emit = await PatrolActiveRoundCache.isTrackEmitEnabled();
    if (!emit ||
        !await PatrolTrackingConfigStore.backgroundAutoScanEnabled()) {
      if (_autoScanActive) await _detachScan();
      return;
    }
    final armed = await PatrolActiveRoundCache.isBackgroundAutoScanArmed();
    if (!armed || _autoScanPaused) {
      if (_autoScanActive) await _detachScan();
      return;
    }
    if (await PatrolActiveRoundCache.isForegroundScanBusy()) {
      if (_autoScanActive) await _detachScan();
      return;
    }
    final cached = await PatrolActiveRoundCache.load();
    if (cached == null) {
      _activeRoundSnapshot = null;
      _submittedCheckpointIds.clear();
      if (_autoScanActive) await _detachScan();
      return;
    }
    _applyServerRoundSnapshot(cached);

    final eligible = _eligibleCheckPoints(_activeRoundSnapshot!.checkPoints);
    if (eligible.isEmpty) {
      if (_autoScanActive) await _detachScan();
      await _maybeCompleteRoundIfFullyScanned();
      return;
    }

    _scanNeedsBaro = !PatrolBackgroundIsolateFlags.active &&
        eligible.any((p) => p.baroAltitude != null);

    _gpsHub.autoScanHandler = _onGpsEvent;
    await _gpsHub.ensureRunning(scanWantsBarometer: _scanNeedsBaro);
    _autoScanActive =
        _gpsHub.hasAutoScanHandler && _gpsHub.isListening;
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
    if (await PatrolActiveRoundCache.isForegroundScanBusy()) return;

    final active = await _currentActiveSnapshot();
    if (active == null) return;

    final unverified = _eligibleCheckPoints(active.checkPoints);
    if (unverified.isEmpty) {
      await _maybeCompleteRoundIfFullyScanned();
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
      _relayCheckpointVerified(matched.copyWith(verified: true));
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
        _relayCheckpointVerified(matched.copyWith(verified: true));
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
      await _maybeCompleteRoundIfFullyScanned();
    }
  }

  Future<void> _maybeCompleteRoundIfFullyScanned() async {
    if (_inFlightCheckpointIds.isNotEmpty) return;
    final snapshot = _activeRoundSnapshot;
    if (snapshot == null) return;
    if (_eligibleCheckPoints(snapshot.checkPoints).isNotEmpty) return;
    _resetAfterRoundFullyScanned();
    await PatrolActiveRoundSync.clearBackgroundAutoScanArmed();
    await stop();
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

  /// Clears optimistic auto-scan state after every checkpoint in the round is done.
  void _resetAfterRoundFullyScanned() {
    _submittedCheckpointIds.clear();
    _inFlightCheckpointIds.clear();
    _activeRoundSnapshot = null;
  }

  /// Trust server/cache on (re)start — do not overlay in-memory verified flags.
  void _applyServerRoundSnapshot(
    ({int roundId, List<CheckPoint> checkPoints}) loaded,
  ) {
    final idsInRound = {for (final p in loaded.checkPoints) p.id};
    _submittedCheckpointIds.removeWhere((id) => !idsInRound.contains(id));
    _inFlightCheckpointIds.removeWhere((id) => !idsInRound.contains(id));
    for (final p in loaded.checkPoints) {
      if (p.verified == true) {
        _submittedCheckpointIds.remove(p.id);
        _inFlightCheckpointIds.remove(p.id);
      }
    }
    _activeRoundSnapshot = loaded;
  }

  /// During GPS auto-scan only — overlay in-flight / submitted ids onto cache reads.
  ({int roundId, List<CheckPoint> checkPoints}) _mergeSnapshotWithMemory(
    ({int roundId, List<CheckPoint> checkPoints}) loaded,
  ) {
    final optimistic = <int>{
      ..._submittedCheckpointIds,
      ..._inFlightCheckpointIds,
    };
    if (optimistic.isEmpty) return loaded;
    return (
      roundId: loaded.roundId,
      checkPoints: [
        for (final p in loaded.checkPoints)
          optimistic.contains(p.id) ? p.copyWith(verified: true) : p,
      ],
    );
  }

  Future<({int roundId, List<CheckPoint> checkPoints})?> _currentActiveSnapshot() async {
    final loaded = await PatrolActiveRoundCache.load();
    if (loaded == null) {
      _activeRoundSnapshot = null;
      return null;
    }
    final merged = _mergeSnapshotWithMemory(loaded);
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

  void _relayCheckpointVerified(CheckPoint point) {
    _onCheckpointVerified?.call(point);
  }
}
