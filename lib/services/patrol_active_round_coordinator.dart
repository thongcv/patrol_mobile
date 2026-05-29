import 'dart:async';

import '../models/active_patrol_round.dart';
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

  static ActivePatrolRound? _lastEmitted;

  /// Phát khi cache vòng tuần tra thay đổi (socket hoặc bootstrap sau đăng nhập).
  static Stream<ActivePatrolRound?> get activeRoundChanges =>
      _activeRoundChanges.stream;

  static void attach() {
    _session.attach();
    _bindSocketHandlers();
  }

  static void _bindSocketHandlers() {
    PatrolTrackSocketDispatch.onActiveRoundChanged = _requestSyncFromServer;
    PatrolTrackSocketDispatch.onSocketConnected = _requestSyncFromServer;
  }

  static void detach() {
    _session.detach();
    PatrolTrackSocketDispatch.onActiveRoundChanged = null;
    PatrolTrackSocketDispatch.onSocketConnected = null;
  }

  static void _requestSyncFromServer() {
    unawaited(syncFromServer());
  }

  /// FGS đã cập nhật cache (auto-scan) — merge `verified` vào UI, không GET lại.
  static Future<void> applyFgsRoundUpdate() async {
    await PatrolRealtimeTrackService.instance.reloadRoundIdFromPrefs();
    final cached = await PatrolActiveRoundCache.load();
    var last = _lastEmitted;
    if (cached != null && last != null && cached.roundId == last.round.id) {
      final verifiedIds = {
        for (final p in cached.checkPoints)
          if (p.verified == true) p.id,
      };
      if (verifiedIds.isNotEmpty) {
        last = ActivePatrolRound(
          schedule: last.schedule,
          round: last.round,
          checkPoints: [
            for (final p in last.checkPoints)
              verifiedIds.contains(p.id) ? p.copyWith(verified: true) : p,
          ],
        );
        _lastEmitted = last;
      }
    }
    if (!_activeRoundChanges.isClosed) {
      _activeRoundChanges.add(_lastEmitted);
    }
  }

  static Future<void> resumeIfSession() => _session.resumeIfSession();

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
  static Future<void> syncFromServer() async {
    if (!_session.sessionActive) {
      if (!await _session.ensureSessionActive()) return;
      _bindSocketHandlers();
    }

    final r = await PatrolActiveRoundSync.fetchAndPersist();
    if (PatrolSession.isUnauthorized(r.failure)) {
      await PatrolSession.endSessionAndNavigateToLogin();
      return;
    }
    if (!r.ok) return;

  final active = r.data == null
        ? null
        : await PatrolActiveRoundCache.preservingLocalVerified(r.data!);
    _lastEmitted = active;
    if (!_activeRoundChanges.isClosed) {
      _activeRoundChanges.add(active);
    }

    await PatrolRealtimeTrackCoordinator.syncTrackingAfterRoundPersisted();

    if (await PatrolTrackingConfigStore.socketEnabled() &&
        !await PatrolTrackingConfigStore.backgroundEnabled()) {
      unawaited(PatrolTrackSocketClient.instance.flushPendingLocations());
    }
  }
}
