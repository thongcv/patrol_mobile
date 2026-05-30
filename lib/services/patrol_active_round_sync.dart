import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
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
      await _armBackgroundAutoScanIfAllowed(r.data?.round.id);
    }
    return r;
  }

  /// Clears armed auto-scan (app bootstrap / login — before GET round).
  static Future<void> clearBackgroundAutoScanArmed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.patrolTrackBackgroundAutoScanEnabled, false);
  }

  static Future<void> _armBackgroundAutoScanIfAllowed(int? roundId) async {
    final hasRound = roundId != null && roundId > 0;
    final allowed = hasRound &&
        await PatrolTrackingConfigStore.backgroundAutoScanEnabled();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      StorageKeys.patrolTrackBackgroundAutoScanEnabled,
      allowed,
    );
  }
}
