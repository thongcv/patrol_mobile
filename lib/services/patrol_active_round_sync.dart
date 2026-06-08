import 'dart:async';

import '../http/api_result.dart';

import '../models/active_patrol_round.dart';

import '../background/patrol_background_service.dart';
import '../services/patrol_background_auto_scan_ui_state.dart';
import 'patrol_active_round_cache.dart';
import 'patrol_foreground_notification.dart';

import 'patrol_round_service.dart';

import 'patrol_tracking_config_store.dart';

/// GET `/me/active` + persist cache/prefs — safe from UI and FGS isolates.

abstract final class PatrolActiveRoundSync {
  PatrolActiveRoundSync._();

  /// Persists round cache. Never arms auto-scan — user confirms notification or header radar.
  static Future<ApiResult<ActivePatrolRound?>> fetchAndPersist() async {
    final r = await PatrolRoundService.instance.fetchMyActivePatrolRound();
    if (!r.ok) return r;
    await PatrolActiveRoundCache.save(r.data);

    if (r.data == null || _isRoundEnded(r.data!)) {
      await disarmBackgroundAutoScanOnRoundEnd();
      return r;
    }

    final awaitingLatch =
        await PatrolActiveRoundCache.ensureAwaitingNextRoundIfRoundChanged(
      r.data?.round.id,
    );
    if (awaitingLatch) {
      await PatrolActiveRoundCache.setBackgroundAutoScanArmed(false);
      unawaited(PatrolBackgroundService.offerNextRoundAutoScanIfAwaiting());
    }
    return r;
  }

  static bool _isRoundEnded(ActivePatrolRound active) {
    switch (active.round.status.trim().toUpperCase()) {
      case 'COMPLETED':
      case 'CANCELLED':
        return true;
      default:
        return false;
    }
  }

  /// Next-round notification **Xác nhận** or header radar while [awaiting].
  static Future<void> confirmNextRoundAutoScanFromUser() async {
    PatrolBackgroundAutoScanUiState.setAwaitingNextRoundConfirm(false);
    await PatrolBackgroundService.invokeConfirmNextRoundAutoScan();
    await PatrolActiveRoundCache.signalConfirmNextRoundAutoScan();
    await PatrolForegroundNotification.cancelNextRoundConfirm();
  }

  /// User armed background auto-scan (not while next-round [awaiting]).
  static Future<bool> armBackgroundAutoScanByUser() async {
    if (await PatrolActiveRoundCache.isAwaitingNextRoundAutoScanConfirm()) {
      return false;
    }
    final enabled =
        await PatrolTrackingConfigStore.backgroundAutoScanEnabled();
    final cached = await PatrolActiveRoundCache.load();
    final roundId = cached?.roundId;
    if (!enabled || roundId == null || roundId <= 0) {
      await PatrolActiveRoundCache.setBackgroundAutoScanArmed(false);
      return false;
    }
    await PatrolActiveRoundCache.setBackgroundAutoScanArmed(true);
    return true;
  }

  /// Round finished / no active round — stop latch so FGS gate blocks auto-scan.
  static Future<void> disarmBackgroundAutoScanOnRoundEnd() async {
    await PatrolActiveRoundCache.setBackgroundAutoScanArmed(false);
    await PatrolActiveRoundCache.setBackgroundAutoScanRunning(false);
    await PatrolActiveRoundCache.setAwaitingNextRoundAutoScanConfirm(false);
    PatrolBackgroundAutoScanUiState.setRunning(false);
    await PatrolBackgroundService.pauseBackgroundAutoScan();
  }

  static Future<void> clearBackgroundAutoScanArmed() async {
    await PatrolActiveRoundCache.setBackgroundAutoScanArmed(false);
  }
}
