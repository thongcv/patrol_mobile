import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import '../http/api_result.dart';
import '../models/active_patrol_round.dart';
import 'patrol_active_round_cache.dart';
import 'patrol_round_service.dart';

/// GET `/me/active` + persist cache/prefs — safe from UI and FGS isolates.
abstract final class PatrolActiveRoundSync {
  PatrolActiveRoundSync._();

  static Future<ApiResult<ActivePatrolRound?>> fetchAndPersist() async {
    final r = await PatrolRoundService.instance.fetchMyActivePatrolRound();
    if (!r.ok) return r;

    final active = r.data;
    await PatrolActiveRoundCache.save(active);
    await _applyRoundTrackingPrefs(active?.round.id);
    return r;
  }

  static Future<void> _applyRoundTrackingPrefs(int? roundId) async {
    final prefs = await SharedPreferences.getInstance();
    if (roundId == null || roundId <= 0) {
      await prefs.remove(StorageKeys.patrolTrackRoundId);
      await prefs.setBool(StorageKeys.patrolTrackBackgroundAutoScanEnabled, false);
      return;
    }
    await prefs.setInt(StorageKeys.patrolTrackRoundId, roundId);
    await prefs.setBool(StorageKeys.patrolTrackBackgroundAutoScanEnabled, true);
  }
}
