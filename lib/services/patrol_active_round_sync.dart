import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import '../http/api_result.dart';
import '../models/active_patrol_round.dart';
import '../models/check_point.dart';
import 'check_point_service.dart';
import 'patrol_active_round_cache.dart';
import 'patrol_round_service.dart';

/// GET `/me/active` + persist cache/prefs — safe from UI and FGS isolates.
abstract final class PatrolActiveRoundSync {
  PatrolActiveRoundSync._();

  static Future<ApiResult<ActivePatrolRound?>> fetchAndPersist() async {
    final r = await PatrolRoundService.instance.fetchMyActivePatrolRound();
    if (!r.ok) return r;

    final active = r.data == null
        ? null
        : await enrichActiveRoundWithSiteCoordinates(r.data!);
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

  /// GET `/me/active` may omit lat/lng — fill from GET `/api/check-points/me/site`.
  static Future<ActivePatrolRound> enrichActiveRoundWithSiteCoordinates(
    ActivePatrolRound active,
  ) async {
    final enriched = await enrichCheckPointsFromSite(active.checkPoints);
    if (identical(enriched, active.checkPoints)) return active;
    return ActivePatrolRound(
      schedule: active.schedule,
      round: active.round,
      checkPoints: enriched,
    );
  }

  static Future<List<CheckPoint>> enrichCheckPointsFromSite(
    List<CheckPoint> points,
  ) async {
    final needsCoords = points.any(
      (p) => p.verified != true && !p.hasCoordinates,
    );
    if (!needsCoords) return points;

    final site = await CheckPointService.instance.fetchMySiteCheckPoints();
    if (!site.ok || site.data == null) return points;

    final siteById = {
      for (final p in site.data!.checkPoints) p.id: p,
    };
    if (siteById.isEmpty) return points;

    return [
      for (final p in points)
        if (p.hasCoordinates || p.verified == true)
          p
        else
          siteById[p.id] == null
              ? p
              : p.mergeSiteMetadata(siteById[p.id]!, preferActive: true),
    ];
  }
}
