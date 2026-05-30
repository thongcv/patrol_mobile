import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import '../models/active_patrol_round.dart';
import '../models/check_point.dart';

/// Active round snapshot + FGS coordination prefs (cross-isolate).
abstract final class PatrolActiveRoundCache {
  PatrolActiveRoundCache._();

  static Future<SharedPreferences> _prefs({bool reload = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    return prefs;
  }

  // --- FGS coordination prefs ---

  static Future<bool> isTrackEmitEnabled({bool reload = true}) async {
    final prefs = await _prefs(reload: reload);
    return prefs.getBool(StorageKeys.patrolTrackEmitEnabled) ?? false;
  }

  static Future<void> setTrackEmitEnabled(bool enabled) async {
    final prefs = await _prefs();
    await prefs.setBool(StorageKeys.patrolTrackEmitEnabled, enabled);
  }

  static Future<void> clearTrackEmitEnabled() async {
    final prefs = await _prefs();
    await prefs.remove(StorageKeys.patrolTrackEmitEnabled);
  }

  static Future<bool> isBackgroundAutoScanArmed({bool reload = true}) async {
    final prefs = await _prefs(reload: reload);
    return prefs.getBool(StorageKeys.patrolTrackBackgroundAutoScanEnabled) ??
        false;
  }

  static Future<void> setBackgroundAutoScanArmed(bool armed) async {
    final prefs = await _prefs();
    await prefs.setBool(StorageKeys.patrolTrackBackgroundAutoScanEnabled, armed);
  }

  static Future<bool> isForegroundScanBusy({bool reload = true}) async {
    final prefs = await _prefs(reload: reload);
    return prefs.getBool(StorageKeys.patrolTrackForegroundScanBusy) ?? false;
  }

  static Future<void> setForegroundScanBusy(bool busy) async {
    final prefs = await _prefs();
    await prefs.setBool(StorageKeys.patrolTrackForegroundScanBusy, busy);
  }

  static Future<bool> isPendingFgsReloadAfterRound({bool reload = true}) async {
    final prefs = await _prefs(reload: reload);
    return prefs.getBool(StorageKeys.patrolTrackPendingFgsReloadAfterRound) ??
        false;
  }

  static Future<void> setPendingFgsReloadAfterRound(bool pending) async {
    final prefs = await _prefs();
    await prefs.setBool(
      StorageKeys.patrolTrackPendingFgsReloadAfterRound,
      pending,
    );
  }

  /// GET `/me/active` may omit `verified` — only then keep local verified from cache.
  /// When API sends `verified: false`, trust the server.
  /// Merges `verified: true` from the FGS snapshot into [active] (same round id).
  ///
  /// Use when opening [PatrolRoundScreen] or after background auto-scan — GET active
  /// may still return `verified: false` before the server catches up.
  static Future<ActivePatrolRound> mergeBackgroundVerified(
    ActivePatrolRound active,
  ) async {
    final cached = await load();
    if (cached == null || cached.roundId != active.round.id) {
      return active;
    }
    return mergeVerifiedCheckPoints(active, cached.checkPoints);
  }

  static ActivePatrolRound mergeVerifiedCheckPoints(
    ActivePatrolRound active,
    List<CheckPoint> verifiedSource,
  ) {
    final verifiedIds = {
      for (final p in verifiedSource)
        if (p.verified == true) p.id,
    };
    if (verifiedIds.isEmpty) return active;
    return ActivePatrolRound(
      schedule: active.schedule,
      round: active.round,
      checkPoints: [
        for (final p in active.checkPoints)
          verifiedIds.contains(p.id) ? p.copyWith(verified: true) : p,
      ],
    );
  }

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
    final prefs = await _prefs();
    if (active == null) {
      await prefs.remove(StorageKeys.patrolTrackActiveRoundSnapshot);
      await prefs.remove(StorageKeys.patrolTrackActiveRoundRevision);
      return;
    }
    final merged = await preservingLocalVerified(active);
    final next = (
      roundId: merged.round.id,
      checkPoints: merged.checkPoints,
    );
    final existing = await load();
    if (existing != null &&
        snapshotFingerprint(existing) == snapshotFingerprint(next)) {
      return;
    }
    await prefs.setString(
      StorageKeys.patrolTrackActiveRoundSnapshot,
      jsonEncode(<String, dynamic>{
        'roundId': merged.round.id,
        'checkPoints': [
          for (final p in merged.checkPoints) p.toJson(),
        ],
      }),
    );
    await _bumpRevision(prefs);
    await prefs.reload();
  }

  static Future<int> readRevision() async {
    final prefs = await _prefs();
    return prefs.getInt(StorageKeys.patrolTrackActiveRoundRevision) ?? 0;
  }

  /// Stable content hash for deduping reload / GPS reattach when data unchanged.
  static String snapshotFingerprint(
    ({int roundId, List<CheckPoint> checkPoints}) snapshot,
  ) {
    final parts = <String>[snapshot.roundId.toString()];
    for (final p in snapshot.checkPoints) {
      parts.add(
        '${p.id}:${p.verified == true}:${p.sequenceOrder}:'
        '${p.latitude}:${p.longitude}:${p.hasCoordinates}',
      );
    }
    return parts.join('|');
  }

  static Future<void> _bumpRevision(SharedPreferences prefs) async {
    final next = (prefs.getInt(StorageKeys.patrolTrackActiveRoundRevision) ?? 0) + 1;
    await prefs.setInt(StorageKeys.patrolTrackActiveRoundRevision, next);
  }

  static Future<({int roundId, List<CheckPoint> checkPoints})?> load() async {
    final prefs = await _prefs(reload: true);
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
    final next = (roundId: roundId, checkPoints: checkPoints);
    final existing = await load();
    if (existing != null &&
        snapshotFingerprint(existing) == snapshotFingerprint(next)) {
      return;
    }
    final prefs = await _prefs();
    await prefs.setString(
      StorageKeys.patrolTrackActiveRoundSnapshot,
      jsonEncode(<String, dynamic>{
        'roundId': roundId,
        'checkPoints': [for (final p in checkPoints) p.toJson()],
      }),
    );
    await _bumpRevision(prefs);
  }
}
