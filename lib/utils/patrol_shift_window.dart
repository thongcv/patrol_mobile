import 'patrol_datetime_format.dart';

/// Active round window (`round.expectedStartTime` / `expectedEndTime`) for emit gating.
abstract final class PatrolShiftWindow {
  PatrolShiftWindow._();

  /// `true` when [now] is inside the round expected window.
  ///
  /// Bounds are API instants (UTC ISO); compared in local time.
  /// When both bounds are absent or unparseable, returns `true` (no window gate).
  static bool isWithinWindow({
    required DateTime now,
    String? expectedStartTime,
    String? expectedEndTime,
  }) {
    final start = parsePatrolApiInstant(expectedStartTime);
    final end = parsePatrolApiInstant(expectedEndTime);
    if (start == null && end == null) return true;
    if (start != null && now.isBefore(start)) return false;
    if (end != null && !now.isBefore(end)) return false;
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

  bool contains(DateTime now) => PatrolShiftWindow.isWithinWindow(
        now: now,
        expectedStartTime: expectedStartTime,
        expectedEndTime: expectedEndTime,
      );

  /// Next instant when [contains] may change (round start or end, local).
  DateTime? nextBoundaryAfter(DateTime now) {
    final start = parsePatrolApiInstant(expectedStartTime);
    final end = parsePatrolApiInstant(expectedEndTime);
    if (start == null && end == null) return null;

    if (start != null && now.isBefore(start)) return start;
    if (end != null && now.isBefore(end)) return end;
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
