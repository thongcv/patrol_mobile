import 'dart:async';

import '../models/active_patrol_round.dart';
import '../navigation/patrol_session.dart';
import 'account_session_store.dart';
import 'patrol_active_round_cache.dart';
import 'patrol_realtime_track_coordinator.dart';
import 'patrol_round_service.dart';
import 'patrol_track_socket_client.dart';
import 'patrol_tracking_config_store.dart';

/// Đồng bộ vòng tuần tra đang active — chỉ qua STOMP + GET khi socket báo / vừa kết nối.
abstract final class PatrolActiveRoundCoordinator {
  PatrolActiveRoundCoordinator._();

  static StreamSubscription<void>? _authSub;
  static StreamSubscription<void>? _sessionEndedSub;
  static StreamSubscription<void>? _activeRoundSub;
  static StreamSubscription<bool>? _socketConnectedSub;

  static final StreamController<ActivePatrolRound?> _activeRoundChanges =
      StreamController<ActivePatrolRound?>.broadcast();

  /// Phát khi cache vòng tuần tra thay đổi (socket hoặc bootstrap sau đăng nhập).
  static Stream<ActivePatrolRound?> get activeRoundChanges =>
      _activeRoundChanges.stream;

  static bool _sessionActive = false;

  static void attach() {
    _authSub ??= PatrolSession.authStoredChanges.listen((_) {
      unawaited(resumeIfSession());
    });

    _sessionEndedSub ??= PatrolSession.sessionEnded.listen((_) {
      unawaited(onSessionEnded());
    });

    _activeRoundSub ??=
        PatrolTrackSocketClient.instance.activeRoundSignals.listen((_) {
      unawaited(syncFromServer());
    });

    _socketConnectedSub ??=
        PatrolTrackSocketClient.instance.connectionChanges.listen((connected) {
      if (connected) unawaited(syncFromServer());
    });

    unawaited(_notifyIfRestoredSession());
  }

  static void detach() {
    _authSub?.cancel();
    _authSub = null;
    _sessionEndedSub?.cancel();
    _sessionEndedSub = null;
    _activeRoundSub?.cancel();
    _activeRoundSub = null;
    _socketConnectedSub?.cancel();
    _socketConnectedSub = null;
    _sessionActive = false;
  }

  static Future<void> _notifyIfRestoredSession() async {
    if (!await AccountSessionStore.instance.hasStoredSession()) return;
    PatrolSession.notifyAuthStored();
  }

  static Future<void> resumeIfSession() async {
    if (!await AccountSessionStore.instance.hasStoredSession()) return;
    await onAuthenticated();
  }

  static Future<void> onAuthenticated() async {
    _sessionActive = true;
    await _connectSessionSocket();
  }

  static Future<void> onSessionEnded() async {
    _sessionActive = false;
    await PatrolActiveRoundCache.save(null);
    if (!_activeRoundChanges.isClosed) {
      _activeRoundChanges.add(null);
    }
    if (await PatrolTrackingConfigStore.socketEnabled()) {
      await PatrolTrackSocketClient.instance.disconnect();
    }
  }

  /// GET `/me/active` — gọi từ STOMP `active-round-changed` hoặc sau khi socket connect.
  static Future<void> syncFromServer() async {
    if (!_sessionActive) return;

    final r = await PatrolRoundService.instance.fetchMyActivePatrolRound();
    if (PatrolSession.isUnauthorized(r.failure)) {
      await PatrolSession.endSessionAndNavigateToLogin();
      return;
    }

    if (!r.ok) return;

    final active = r.data;
    await PatrolActiveRoundCache.save(active);
    if (!_activeRoundChanges.isClosed) {
      _activeRoundChanges.add(active);
    }

    final roundId = active?.round.id;
    await PatrolRealtimeTrackCoordinator.applyActiveRound(roundId);
  }

  static Future<void> _connectSessionSocket() async {
    if (!await PatrolTrackingConfigStore.socketEnabled()) return;
    await PatrolTrackSocketClient.instance.connect();
  }
}
