import '../http/api_result.dart';

import '../models/active_patrol_round.dart';

import 'patrol_active_round_cache.dart';

import 'patrol_round_service.dart';

import 'patrol_tracking_config_store.dart';

/// GET `/me/active` + persist cache/prefs — safe from UI and FGS isolates.

abstract final class PatrolActiveRoundSync {
  PatrolActiveRoundSync._();

  /// Persists round cache. Arms background auto-scan only when [armAutoScan] is
  /// `true` (STOMP `active-round-changed` — not app bootstrap GET).
  static Future<ApiResult<ActivePatrolRound?>> fetchAndPersist({
    bool armAutoScan = false,
  }) async {
    final r = await PatrolRoundService.instance.fetchMyActivePatrolRound();
    if (!r.ok) return r;
    await PatrolActiveRoundCache.save(r.data);
    if (armAutoScan) {
      final enabled = await PatrolTrackingConfigStore.backgroundAutoScanEnabled();
      await _armBackgroundAutoScanIfAllowed(r.data?.round.id, enabled);
    }
    return r;
  }

  /// Clears armed auto-scan (app bootstrap / login — before GET round).
  static Future<void> clearBackgroundAutoScanArmed() async {
    await PatrolActiveRoundCache.setBackgroundAutoScanArmed(false);
  }

  /// Arms FGS auto-scan when [backgroundAutoScan] config is on and a round is cached.
  static Future<void> armBackgroundAutoScanIfConfigured() async {
    final enabled = await PatrolTrackingConfigStore.backgroundAutoScanEnabled();
    final cached = await PatrolActiveRoundCache.load();
    await _armBackgroundAutoScanIfAllowed(cached?.roundId, enabled);
  }

  static Future<void> _armBackgroundAutoScanIfAllowed(
    int? roundId,
    bool enabledScan,
  ) async {
    final hasRound = roundId != null && roundId > 0;
    final allowed = hasRound && enabledScan;
    await PatrolActiveRoundCache.setBackgroundAutoScanArmed(allowed);
  }
}
