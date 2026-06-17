import '../models/patrol_tracking_config.dart';
import 'patrol_datetime_format.dart';

/// Start/end grace applied to round expected window for emit gating.
typedef PatrolShiftWindowGrace = ({Duration start, Duration end});

/// Active round window (`round.expectedStartTime` / `expectedEndTime`) for emit gating.
abstract final class PatrolShiftWindow {
  PatrolShiftWindow._();

  static Duration _startGrace(PatrolShiftWindowGrace? emitWindowGrace) =>
      emitWindowGrace?.start ??
      const Duration(
        minutes: PatrolTrackingConfig.defaultShiftWindowStartGraceMinutes,
      );

  static Duration _endGrace(PatrolShiftWindowGrace? emitWindowGrace) =>
      emitWindowGrace?.end ??
      const Duration(
        minutes: PatrolTrackingConfig.defaultShiftWindowEndGraceMinutes,
      );

  /// Effective bounds after applying [emitWindowGrace] (local time).
  static ({DateTime? start, DateTime? end}) effectiveBounds({
    String? expectedStartTime,
    String? expectedEndTime,
    PatrolShiftWindowGrace? emitWindowGrace,
  }) {
    final startGrace = _startGrace(emitWindowGrace);
    final endGrace = _endGrace(emitWindowGrace);
    final start = parsePatrolApiInstant(expectedStartTime);
    final end = parsePatrolApiInstant(expectedEndTime);
    return (
      start: start?.subtract(startGrace),
      end: end?.add(endGrace),
    );
  }

  /// `true` when [now] is inside the round expected window (± [emitWindowGrace]).
  ///
  /// Bounds are API instants (UTC ISO); compared in local time.
  /// When both bounds are absent or unparseable, returns `true` (no window gate).
  static bool isWithinWindow({
    required DateTime now,
    String? expectedStartTime,
    String? expectedEndTime,
    PatrolShiftWindowGrace? emitWindowGrace,
  }) {
    final bounds = effectiveBounds(
      expectedStartTime: expectedStartTime,
      expectedEndTime: expectedEndTime,
      emitWindowGrace: emitWindowGrace,
    );
    if (bounds.start == null && bounds.end == null) return true;
    final effectiveStart = bounds.start;
    final effectiveEnd = bounds.end;
    if (effectiveStart != null && now.isBefore(effectiveStart)) return false;
    if (effectiveEnd != null && !now.isBefore(effectiveEnd)) return false;
    return true;
  }
}

/// Cached round window persisted for FGS / main isolates.
class PatrolShiftWindowSnapshot {
  const PatrolShiftWindowSnapshot({
    this.expectedStartTime,
    this.expectedEndTime,
  });

  final String? expectedStartTime;
  final String? expectedEndTime;

  bool contains(
    DateTime now, {
    PatrolShiftWindowGrace? emitWindowGrace,
  }) =>
      PatrolShiftWindow.isWithinWindow(
        now: now,
        expectedStartTime: expectedStartTime,
        expectedEndTime: expectedEndTime,
        emitWindowGrace: emitWindowGrace,
      );

  /// Next instant when [contains] may change (effective start/end, local).
  DateTime? nextBoundaryAfter(
    DateTime now, {
    PatrolShiftWindowGrace? emitWindowGrace,
  }) {
    final bounds = PatrolShiftWindow.effectiveBounds(
      expectedStartTime: expectedStartTime,
      expectedEndTime: expectedEndTime,
      emitWindowGrace: emitWindowGrace,
    );
    if (bounds.start == null && bounds.end == null) return null;

    final effectiveStart = bounds.start;
    final effectiveEnd = bounds.end;
    if (effectiveStart != null && now.isBefore(effectiveStart)) {
      return effectiveStart;
    }
    if (effectiveEnd != null && now.isBefore(effectiveEnd)) return effectiveEnd;
    return null;
  }

  Map<String, dynamic> toJson() => {
        if (expectedStartTime != null) 'expectedStartTime': expectedStartTime,
        if (expectedEndTime != null) 'expectedEndTime': expectedEndTime,
      };

  factory PatrolShiftWindowSnapshot.fromJson(Map<String, dynamic> json) {
    final start = json['expectedStartTime'] as String?;
    final end = json['expectedEndTime'] as String?;
    if (start != null || end != null) {
      return PatrolShiftWindowSnapshot(
        expectedStartTime: start,
        expectedEndTime: end,
      );
    }
    // Legacy schedule-based cache — treat as unrestricted until round re-persisted.
    return const PatrolShiftWindowSnapshot();
  }

  factory PatrolShiftWindowSnapshot.fromRound({
    String? expectedStartTime,
    String? expectedEndTime,
  }) {
    return PatrolShiftWindowSnapshot(
      expectedStartTime: expectedStartTime,
      expectedEndTime: expectedEndTime,
    );
  }
}
