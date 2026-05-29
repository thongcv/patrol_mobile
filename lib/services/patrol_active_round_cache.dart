import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import '../models/active_patrol_round.dart';
import '../models/check_point.dart';

/// Caches active patrol round for background auto-scan (UI-independent).
abstract final class PatrolActiveRoundCache {
  PatrolActiveRoundCache._();

  /// GET `/me/active` may omit `verified` — only then keep local verified from cache.
  /// When API sends `verified: false`, trust the server.
  static Future<ActivePatrolRound> preservingLocalVerified(
    ActivePatrolRound active,
  ) async {
    final previous = await load();
    if (previous == null || previous.roundId != active.round.id) {
      return active;
    }
    final verifiedIds = {
      for (final p in previous.checkPoints)
        if (p.verified == true) p.id,
    };
    if (verifiedIds.isEmpty) return active;
    return ActivePatrolRound(
      schedule: active.schedule,
      round: active.round,
      checkPoints: [
        for (final p in active.checkPoints)
          p.verified != null
              ? p
              : verifiedIds.contains(p.id)
                  ? p.copyWith(verified: true)
                  : p,
      ],
    );
  }

  static Future<bool> isCheckpointVerified(int checkpointId) async {
    final cached = await load();
    if (cached == null) return false;
    return cached.checkPoints.any(
      (p) => p.id == checkpointId && p.verified == true,
    );
  }

  static Future<void> save(ActivePatrolRound? active) async {
    final prefs = await SharedPreferences.getInstance();
    if (active == null) {
      await prefs.remove(StorageKeys.patrolTrackActiveRoundSnapshot);
      return;
    }
    final merged = await preservingLocalVerified(active);
    await prefs.setString(
      StorageKeys.patrolTrackActiveRoundSnapshot,
      jsonEncode(<String, dynamic>{
        'roundId': merged.round.id,
        'checkPoints': [
          for (final p in merged.checkPoints) p.toJson(),
        ],
      }),
    );
  }

  static Future<({int roundId, List<CheckPoint> checkPoints})?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.patrolTrackActiveRoundSnapshot);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      final roundId = (map['roundId'] as num?)?.toInt();
      if (roundId == null || roundId <= 0) return null;
      final rawPoints = map['checkPoints'];
      if (rawPoints is! List) return null;
      final points = rawPoints
          .whereType<Map<String, dynamic>>()
          .map(CheckPoint.fromJson)
          .toList()
        ..sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));
      return (roundId: roundId, checkPoints: points);
    } catch (_) {
      return null;
    }
  }

  static Future<void> markCheckpointVerified(int checkpointId) async {
    final cached = await load();
    if (cached == null) return;
    final updated = [
      for (final p in cached.checkPoints)
        p.id == checkpointId ? p.copyWith(verified: true) : p,
    ];
    await _writeSnapshot(roundId: cached.roundId, checkPoints: updated);
  }

  static Future<void> patchCheckPoints(List<CheckPoint> checkPoints) async {
    final cached = await load();
    if (cached == null) return;
    await _writeSnapshot(roundId: cached.roundId, checkPoints: checkPoints);
  }

  static Future<void> _writeSnapshot({
    required int roundId,
    required List<CheckPoint> checkPoints,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.patrolTrackActiveRoundSnapshot,
      jsonEncode(<String, dynamic>{
        'roundId': roundId,
        'checkPoints': [for (final p in checkPoints) p.toJson()],
      }),
    );
  }
}
