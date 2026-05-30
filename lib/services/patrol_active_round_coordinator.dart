import 'dart:async';

import '../models/active_patrol_round.dart';
import '../models/check_point.dart';
import '../navigation/patrol_session.dart';
import 'patrol_active_round_cache.dart';
import 'patrol_active_round_sync.dart';
import 'patrol_realtime_track_coordinator.dart';
import 'patrol_realtime_track_service.dart';
import 'patrol_session_listen.dart';
import 'patrol_track_socket_client.dart';
import 'patrol_track_socket_dispatch.dart';
import 'patrol_tracking_config_store.dart';

/// Đồng bộ vòng tuần tra đang active — GET khi STOMP push / socket connect.
abstract final class PatrolActiveRoundCoordinator {
  PatrolActiveRoundCoordinator._();

  static final PatrolSessionListen _session = PatrolSessionListen(
    onAuthenticated: _onAuthenticated,
    onSessionEnded: onSessionEnded,
  );

  static final StreamController<ActivePatrolRound?> _activeRoundChanges =
      StreamController<ActivePatrolRound?>.broadcast();

  static final StreamController<CheckPoint> _checkpointVerifiedChanges =
      StreamController<CheckPoint>.broadcast();

  static ActivePatrolRound? _lastEmitted;

  /// Full round thay đổi — GET `/me/active`, session end, STOMP full sync.
  static Stream<ActivePatrolRound?> get activeRoundChanges =>
      _activeRoundChanges.stream;

  /// FGS auto-scan verified một checkpoint (nguyên [CheckPoint], không kèm round).
  static Stream<CheckPoint> get checkpointVerifiedChanges =>
      _checkpointVerifiedChanges.stream;

  static void attach() {
    _bindSocketHandlers();
  }

  static void _bindSocketHandlers() {
    PatrolTrackSocketDispatch.onActiveRoundChanged =
        _requestSyncAfterRoundPush;
    PatrolTrackSocketDispatch.onSocketConnected = _requestSyncOnSocketConnect;
  }

  static void detach() {
    PatrolTrackSocketDispatch.onActiveRoundChanged = null;
    PatrolTrackSocketDispatch.onSocketConnected = null;
  }

  static void _requestSyncAfterRoundPush() {
    unawaited(syncFromServer(armAutoScan: true));
  }

  static void _requestSyncOnSocketConnect() {
    unawaited(syncFromServer());
  }

  /// FGS đã cập nhật cache (auto-scan / STOMP).
  ///
  /// [payload] `checkPoint` — auto-scan verified one point → [checkpointVerifiedChanges].
  /// [payload] `fullSync: true` — FGS đã [PatrolActiveRoundSync.fetchAndPersist]; main đọc cache.
  static Future<void> applyFgsRoundUpdate({Map<Object?, Object?>? payload}) async {
    final point = _checkPointFromPayload(payload);
    final fullSync = payload?['fullSync'] == true;

    if (fullSync) {
      unawaited(applyFromFgsCache());
      return;
    }

    if (point != null) {
      _emitCheckpointVerified(point);
      return;
    }

    var last = _lastEmitted;
    if (last == null) {
      final cached = await PatrolActiveRoundCache.load();
      if (cached == null) return;
      unawaited(syncFromServer());
      return;
    }

    final before = last;
    last = await PatrolActiveRoundCache.mergeBackgroundVerified(last);
    _lastEmitted = last;
    _emitNewlyVerifiedCheckpoints(before, last);
  }

  /// Đọc snapshot FGS vừa persist — tránh GET `/me/active` trùng trên main.
  static Future<void> applyFromFgsCache() async {
    if (!_session.sessionActive) {
      if (!await _session.ensureSessionActive()) return;
      _bindSocketHandlers();
    }

    final cached = await PatrolActiveRoundCache.load();
    if (cached == null) {
      await _emitActiveRound(null);
      await _afterRoundPersistedSideEffects();
      return;
    }

    final last = _lastEmitted;
    if (last == null || last.round.id != cached.roundId) {
      // Cache chỉ có roundId + checkPoints — cần GET khi đổi vòng hoặc chưa bootstrap UI.
      await syncFromServer();
      return;
    }

    await _emitActiveRound(
      ActivePatrolRound(
        schedule: last.schedule,
        round: last.round,
        checkPoints: cached.checkPoints,
      ),
    );
    await _afterRoundPersistedSideEffects();
  }

  static Future<void> _emitActiveRound(ActivePatrolRound? active) async {
    _lastEmitted = active;
    if (!_activeRoundChanges.isClosed) {
      _activeRoundChanges.add(active);
    }
  }

  static Future<void> _afterRoundPersistedSideEffects() async {
    if (PatrolRealtimeTrackService.instance.isSessionTracking) {
      await PatrolRealtimeTrackCoordinator.syncTrackingAfterRoundPersisted(
        force: true,
      );
    }

    if (await PatrolTrackingConfigStore.socketEnabled() &&
        !await PatrolTrackingConfigStore.backgroundEnabled()) {
      unawaited(PatrolTrackSocketClient.instance.flushPendingLocations());
    }
  }

  static CheckPoint? _checkPointFromPayload(Map<Object?, Object?>? payload) {
    if (payload == null) return null;
    final raw = payload['checkPoint'];
    if (raw is! Map) return null;
    try {
      return CheckPoint.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  static void _emitCheckpointVerified(CheckPoint point) {
    final verified =
        point.verified == true ? point : point.copyWith(verified: true);
    var last = _lastEmitted;
    if (last != null) {
      if (last.checkPoints.any(
        (p) => p.id == verified.id && p.verified == true,
      )) {
        return;
      }
      _lastEmitted = ActivePatrolRound(
        schedule: last.schedule,
        round: last.round,
        checkPoints: [
          for (final p in last.checkPoints)
            p.id == verified.id ? verified : p,
        ],
      );
    }
    if (!_checkpointVerifiedChanges.isClosed) {
      _checkpointVerifiedChanges.add(verified);
    }
  }

  static void _emitNewlyVerifiedCheckpoints(
    ActivePatrolRound before,
    ActivePatrolRound after,
  ) {
    final beforeVerified = {
      for (final p in before.checkPoints)
        if (p.verified == true) p.id,
    };
    for (final p in after.checkPoints) {
      if (p.verified != true || beforeVerified.contains(p.id)) continue;
      _emitCheckpointVerified(p);
    }
  }

  static Future<void> resumeIfSession() => _session.resumeIfSession();

  /// Called from [PatrolStartupCoordinator] after location gate.
  static Future<void> bootstrapAuthenticatedSession() async {
    _session.sessionActive = true;
    await _onAuthenticated();
  }

  static Future<void> _onAuthenticated() async {
    _bindSocketHandlers();
    await syncFromServer();
  }

  static Future<void> onSessionEnded() async {
    _session.sessionActive = false;
    _lastEmitted = null;
    await PatrolActiveRoundCache.save(null);
    if (!_activeRoundChanges.isClosed) {
      _activeRoundChanges.add(null);
    }
    if (await PatrolTrackingConfigStore.socketEnabled()) {
      await PatrolTrackSocketClient.instance.disconnect();
    }
  }

  /// GET `/me/active` — main STOMP hoặc sau khi FGS STOMP connect.
  static Future<void> syncFromServer({bool armAutoScan = false}) async {
    if (!_session.sessionActive) {
      if (!await _session.ensureSessionActive()) return;
      _bindSocketHandlers();
    }

    final r = await PatrolActiveRoundSync.fetchAndPersist(
      armAutoScan: armAutoScan,
    );
    if (PatrolSession.isUnauthorized(r.failure)) {
      await PatrolSession.endSessionAndNavigateToLogin();
      return;
    }
    if (!r.ok) return;

    final active = r.data == null
        ? null
        : await PatrolActiveRoundCache.preservingLocalVerified(r.data!);
    await _emitActiveRound(active);
    await _afterRoundPersistedSideEffects();
  }
}
