import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import '../models/active_patrol_round.dart';
import '../models/check_point.dart';
import '../models/patrol_round.dart';
import '../utils/patrol_round_status.dart';
import '../utils/patrol_shift_window.dart';
import 'patrol_tracking_config_store.dart';

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

  static PatrolShiftWindowSnapshot? _memoryShiftWindow;
  static var _memoryShiftWindowLoaded = false;

  static void invalidateTrackingEmitGateCache() {
    _memoryShiftWindowLoaded = false;
    _memoryShiftWindow = null;
  }

  static Future<PatrolShiftWindowSnapshot?> readShiftWindow({
    bool reload = true,
  }) async {
    if (!reload && _memoryShiftWindowLoaded) return _memoryShiftWindow;

    final prefs = await _prefs(reload: reload);
    final raw = prefs.getString(StorageKeys.patrolTrackShiftWindow);
    PatrolShiftWindowSnapshot? parsed;
    if (raw == null || raw.isEmpty) {
      parsed = null;
    } else {
      try {
        final map = jsonDecode(raw);
        if (map is Map<String, dynamic>) {
          parsed = PatrolShiftWindowSnapshot.fromJson(map);
        }
      } catch (_) {
        parsed = null;
      }
    }
    _memoryShiftWindow = parsed;
    _memoryShiftWindowLoaded = true;
    return parsed;
  }

  /// Reload shift-window prefs (FGS refresh / after round persist on this isolate).
  static Future<void> refreshTrackingEmitGateCache() async {
    invalidateTrackingEmitGateCache();
    await readShiftWindow(reload: true);
  }

  /// `true` when STOMP / background GPS track emit is allowed now.
  ///
  /// When [PatrolTrackingConfig.trackByShiftWindow] is `false` (default), emit
  /// for the whole patrol session ([isTrackEmitEnabled]) — no active round required.
  /// When `true`, requires a cached active round ([load]) and current time within
  /// `round.expectedStartTime` / `expectedEndTime`, unless background auto-scan is
  /// armed for that round.
  ///
  static Future<bool> isTrackingWithinShiftWindow({
    DateTime? now,
    bool reload = false,
  }) async {
    final window = await readShiftWindow(reload: reload);
    if (window == null) return false;

    if (!await PatrolTrackingConfigStore.trackByShiftWindow()) {
      return true;
    }
    final grace = await PatrolTrackingConfigStore.shiftWindowGrace();
    return window.contains(now ?? DateTime.now(), emitWindowGrace: grace);
  }

  /// STOMP / GPS track emit — shift window unless background auto-scan is armed
  /// (user confirmed patrol for this round; treat as in-shift for location emit).
  static Future<bool> isTrackLocationEmitAllowed({
    DateTime? now,
    bool reload = false,
  }) async {
    if (!await PatrolTrackingConfigStore.trackByShiftWindow()) {
      return true;
    }
    if (await load() == null) return false;
    if (await isBackgroundAutoScanArmed(reload: reload)) {
      return true;
    }
    return isTrackingWithinShiftWindow(now: now, reload: reload);
  }

  static Future<void> _writeShiftWindow(PatrolRound round) async {
    final prefs = await _prefs();
    final snapshot = PatrolShiftWindowSnapshot.fromRound(
      expectedStartTime: round.expectedStartTime,
      expectedEndTime: round.expectedEndTime,
    );
    await prefs.setString(
      StorageKeys.patrolTrackShiftWindow,
      jsonEncode(snapshot.toJson()),
    );
    invalidateTrackingEmitGateCache();
  }

  static Future<void> _clearShiftWindow() async {
    final prefs = await _prefs();
    await prefs.remove(StorageKeys.patrolTrackShiftWindow);
    invalidateTrackingEmitGateCache();
  }

  /// STOMP/bootstrap latch AND live `backgroundAutoScan` from tracking config.
  static Future<bool> isBackgroundAutoScanArmed({bool reload = true}) async {
    final prefs = await _prefs(reload: reload);
    final latched =
        prefs.getBool(StorageKeys.patrolTrackBackgroundAutoScanEnabled) ??
            false;
    if (!latched) return false;
    return PatrolTrackingConfigStore.backgroundAutoScanEnabled();
  }

  static Future<void> setBackgroundAutoScanArmed(bool armed) async {
    final prefs = await _prefs();
    await prefs.setBool(StorageKeys.patrolTrackBackgroundAutoScanEnabled, armed);
  }

  static Future<bool> isBackgroundAutoScanRunning({bool reload = true}) async {
    final prefs = await _prefs(reload: reload);
    return prefs.getBool(StorageKeys.patrolTrackBackgroundAutoScanRunning) ??
        false;
  }

  static Future<void> setBackgroundAutoScanRunning(bool running) async {
    final prefs = await _prefs();
    await prefs.setBool(
      StorageKeys.patrolTrackBackgroundAutoScanRunning,
      running,
    );
  }

  /// `true` while [PatrolRoundScreen] blocks FGS auto-scan (manual mode or in-flight QR/NFC/GPS/BT).
  /// Cross-isolate; main sets via [PatrolRealtimeTrackService.setForegroundRoundScanBusy].
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

  static Future<void> clearConfirmNextRoundAutoScan() async {
    final prefs = await _prefs();
    await prefs.remove(StorageKeys.patrolTrackConfirmNextRoundAutoScanAtMs);
  }

  /// Written when user taps confirm on the next-round notification (any isolate).
  static Future<void> signalConfirmNextRoundAutoScan() async {
    final prefs = await _prefs();
    await prefs.setInt(
      StorageKeys.patrolTrackConfirmNextRoundAutoScanAtMs,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Returns `true` once when a confirm signal is pending (clears the key).
  static Future<bool> takeConfirmNextRoundAutoScan() async {
    final prefs = await _prefs(reload: true);
    final ms =
        prefs.getInt(StorageKeys.patrolTrackConfirmNextRoundAutoScanAtMs) ?? 0;
    if (ms == 0) return false;
    await prefs.remove(StorageKeys.patrolTrackConfirmNextRoundAutoScanAtMs);
    return true;
  }

  static Future<void> clearNextRoundConfirmHandled({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await _prefs();
    await p.remove(StorageKeys.patrolTrackNextRoundConfirmHandledAtMs);
  }

  /// Written when next-round confirm handler finishes (FGS isolate or main fallback).
  static Future<void> signalNextRoundConfirmHandled() async {
    final prefs = await _prefs();
    await prefs.setInt(
      StorageKeys.patrolTrackNextRoundConfirmHandledAtMs,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Returns `true` once when confirm handler finished (clears the key).
  static Future<bool> takeNextRoundConfirmHandled() async {
    final prefs = await _prefs(reload: true);
    final ms =
        prefs.getInt(StorageKeys.patrolTrackNextRoundConfirmHandledAtMs) ?? 0;
    if (ms == 0) return false;
    await prefs.remove(StorageKeys.patrolTrackNextRoundConfirmHandledAtMs);
    return true;
  }

  static Future<void> signalCancelNextRoundAutoScan() async {
    final prefs = await _prefs();
    await prefs.setInt(
      StorageKeys.patrolTrackCancelNextRoundAutoScanAtMs,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<bool> takeCancelNextRoundAutoScan() async {
    final prefs = await _prefs(reload: true);
    final ms =
        prefs.getInt(StorageKeys.patrolTrackCancelNextRoundAutoScanAtMs) ?? 0;
    if (ms == 0) return false;
    await prefs.remove(StorageKeys.patrolTrackCancelNextRoundAutoScanAtMs);
    return true;
  }

  static Future<bool> isAwaitingNextRoundAutoScanConfirm({
    bool reload = true,
  }) async {
    final prefs = await _prefs(reload: reload);
    return prefs.getBool(
          StorageKeys.patrolTrackAwaitingNextRoundAutoScanConfirm,
        ) ??
        false;
  }

  static Future<void> setAwaitingNextRoundAutoScanConfirm(bool awaiting) async {
    final prefs = await _prefs();
    if (awaiting) {
      await clearNextRoundConfirmHandled(prefs: prefs);
      await prefs.setBool(
        StorageKeys.patrolTrackAwaitingNextRoundAutoScanConfirm,
        true,
      );
    } else {
      await prefs.remove(
        StorageKeys.patrolTrackAwaitingNextRoundAutoScanConfirm,
      );
      await clearNextRoundPromptOffer(prefs: prefs);
    }
  }

  /// `true` when cached round status allows FGS scan / next-round notify.
  static Future<bool> isCachedRoundPendingOrInProgress({bool reload = true}) async {
    final cached = await load();
    if (cached == null) return false;
    final status = cached.roundStatus;
    if (status == null || status.isEmpty) return false;
    return PatrolRoundStatus.isPendingOrInProgress(status);
  }

  /// Once per active round while [awaiting] — blocks repeat notify/TTS on UI sync.
  static Future<bool> tryAcquireNextRoundPromptOffer() async {
    if (!await isAwaitingNextRoundAutoScanConfirm()) return false;
    if (!await isCachedRoundPendingOrInProgress()) return false;
    final cached = await load();
    final roundId = cached?.roundId ?? 0;
    if (roundId <= 0) return false;

    final prefs = await _prefs(reload: true);
    final offeredRoundId =
        prefs.getInt(StorageKeys.patrolTrackNextRoundPromptOfferRoundId) ?? 0;
    if (offeredRoundId == roundId) return false;

    await prefs.setInt(
      StorageKeys.patrolTrackNextRoundPromptOfferRoundId,
      roundId,
    );
    await prefs.setInt(
      StorageKeys.patrolTrackNextRoundPromptShownAtMs,
      DateTime.now().millisecondsSinceEpoch,
    );
    return true;
  }

  static Future<void> clearNextRoundPromptOffer({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await _prefs();
    await p.remove(StorageKeys.patrolTrackNextRoundPromptOfferRoundId);
    await p.remove(StorageKeys.patrolTrackNextRoundPromptShownAtMs);
  }

  static Future<int?> lastAutoScanConfirmedRoundId({bool reload = true}) async {
    final prefs = await _prefs(reload: reload);
    final id =
        prefs.getInt(StorageKeys.patrolTrackLastAutoScanConfirmedRoundId);
    if (id == null || id <= 0) return null;
    return id;
  }

  static Future<void> setLastAutoScanConfirmedRoundId(int roundId) async {
    if (roundId <= 0) return;
    final prefs = await _prefs();
    await prefs.setInt(
      StorageKeys.patrolTrackLastAutoScanConfirmedRoundId,
      roundId,
    );
  }

  static Future<void> clearLastAutoScanConfirmedRoundId({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await _prefs();
    await p.remove(StorageKeys.patrolTrackLastAutoScanConfirmedRoundId);
  }

  /// Next-round auto-scan latch — round end / disarm. Keeps [lastAutoScanConfirmedRoundId]
  /// so the next STOMP round change can detect `last != roundId`. Cleared on logout only.
  static Future<void> clearNextRoundAutoScanSession({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await _prefs();
    await p.setBool(StorageKeys.patrolTrackBackgroundAutoScanEnabled, false);
    await p.setBool(StorageKeys.patrolTrackBackgroundAutoScanRunning, false);
    await p.remove(StorageKeys.patrolTrackAwaitingNextRoundAutoScanConfirm);
    await p.remove(StorageKeys.patrolTrackConfirmNextRoundAutoScanAtMs);
    await p.remove(StorageKeys.patrolTrackCancelNextRoundAutoScanAtMs);
    await p.remove(StorageKeys.patrolTrackNextRoundConfirmHandledAtMs);
    await clearNextRoundPromptOffer(prefs: p);
    await p.setBool(StorageKeys.patrolTrackPendingFgsReloadAfterRound, false);
  }

  /// Baselines first active round; on later round changes sets [awaiting] when config allows.
  static Future<bool> ensureAwaitingNextRoundIfRoundChanged(
    int? roundId, {
    String? roundStatus,
  }) async {
    if (roundId == null || roundId <= 0) return false;
    if (roundStatus != null &&
        !PatrolRoundStatus.isPendingOrInProgress(roundStatus)) {
      return false;
    }
    if (await isAwaitingNextRoundAutoScanConfirm()) return false;
    if (!await PatrolTrackingConfigStore.backgroundAutoScanEnabled()) {
      await setLastAutoScanConfirmedRoundId(roundId);
      return false;
    }

    final last = await lastAutoScanConfirmedRoundId();
    if (last == null) {
      // First active round for this session — baseline, not a "next round" transition.
      await setLastAutoScanConfirmedRoundId(roundId);
      await setBackgroundAutoScanArmed(false);
      await setAwaitingNextRoundAutoScanConfirm(true);
      return true;
    }
    if (last != roundId) {
      // FGS is already auto-scanning — user accepted this round; do not disarm on UI open.
      if (await isBackgroundAutoScanArmed() &&
          await isBackgroundAutoScanRunning()) {
        await setLastAutoScanConfirmedRoundId(roundId);
        return false;
      }
      await setBackgroundAutoScanArmed(false);
      await setAwaitingNextRoundAutoScanConfirm(true);
      return true;
    }
    return false;
  }

  static Future<void> markAutoScanConfirmedForCurrentRound() async {
    final cached = await load();
    final id = cached?.roundId;
    if (id != null && id > 0) {
      await setLastAutoScanConfirmedRoundId(id);
    }
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

  /// Chỉ merge verified từ cache khi FGS auto-scan đang chạy; không thì tin GET active.
  static Future<ActivePatrolRound> mergeBackgroundVerifiedIfRunning(
    ActivePatrolRound active,
  ) async {
    if (!await isBackgroundAutoScanRunning()) return active;
    return mergeBackgroundVerified(active);
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

  static Future<void> save(
    ActivePatrolRound? active, {
    bool preserveLocalVerified = true,
  }) async {
    final prefs = await _prefs();
    if (active == null) {
      await prefs.remove(StorageKeys.patrolTrackActiveRoundSnapshot);
      await prefs.remove(StorageKeys.patrolTrackActiveRoundRevision);
      await _clearShiftWindow();
      await clearNextRoundAutoScanSession(prefs: prefs);
      return;
    }
    final status = active.round.status.trim().toUpperCase();
    if (status == 'COMPLETED' || status == 'CANCELLED') {
      await clearNextRoundAutoScanSession(prefs: prefs);
    }
    final merged = preserveLocalVerified
        ? await preservingLocalVerified(active)
        : active;
    await _writeShiftWindow(merged.round);
    final next = (
      roundId: merged.round.id,
      checkPoints: merged.checkPoints,
      roundStatus: merged.round.status,
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
        'roundStatus': merged.round.status,
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
    ({
      int roundId,
      List<CheckPoint> checkPoints,
      String? roundStatus,
    }) snapshot,
  ) {
    final parts = <String>[
      snapshot.roundId.toString(),
      snapshot.roundStatus ?? '',
    ];
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

  static Future<
      ({
        int roundId,
        List<CheckPoint> checkPoints,
        String? roundStatus,
      })?> load() async {
    final prefs = await _prefs(reload: true);
    final raw = prefs.getString(StorageKeys.patrolTrackActiveRoundSnapshot);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      final roundId = (map['roundId'] as num?)?.toInt();
      if (roundId == null || roundId <= 0) return null;
      final roundStatus = map['roundStatus'] as String?;
      final rawPoints = map['checkPoints'];
      if (rawPoints is! List) return null;
      final points = rawPoints
          .whereType<Map<String, dynamic>>()
          .map(CheckPoint.fromJson)
          .toList()
        ..sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));
      return (
        roundId: roundId,
        checkPoints: points,
        roundStatus: roundStatus,
      );
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
    final existing = await load();
    final next = (
      roundId: roundId,
      checkPoints: checkPoints,
      roundStatus: existing?.roundStatus,
    );
    if (existing != null &&
        snapshotFingerprint(existing) == snapshotFingerprint(next)) {
      return;
    }
    final prefs = await _prefs();
    await prefs.setString(
      StorageKeys.patrolTrackActiveRoundSnapshot,
      jsonEncode(<String, dynamic>{
        'roundId': roundId,
        if (existing?.roundStatus != null) 'roundStatus': existing!.roundStatus,
        'checkPoints': [for (final p in checkPoints) p.toJson()],
      }),
    );
    await _bumpRevision(prefs);
  }
}
