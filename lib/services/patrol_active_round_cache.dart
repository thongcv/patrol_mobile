import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import '../models/active_patrol_round.dart';
import '../models/check_point.dart';

/// Caches active patrol round for background auto-scan (UI-independent).
abstract final class PatrolActiveRoundCache {
  PatrolActiveRoundCache._();

  static Future<void> save(ActivePatrolRound? active) async {
    final prefs = await SharedPreferences.getInstance();
    if (active == null) {
      await prefs.remove(StorageKeys.patrolTrackActiveRoundSnapshot);
      return;
    }
    await prefs.setString(
      StorageKeys.patrolTrackActiveRoundSnapshot,
      jsonEncode(<String, dynamic>{
        'roundId': active.round.id,
        'checkPoints': [
          for (final p in active.checkPoints) p.toJson(),
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.patrolTrackActiveRoundSnapshot,
      jsonEncode(<String, dynamic>{
        'roundId': cached.roundId,
        'checkPoints': [for (final p in updated) p.toJson()],
      }),
    );
  }
}
