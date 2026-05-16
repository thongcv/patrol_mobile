import 'check_point.dart';
import 'patrol_round.dart';
import 'patrol_schedule.dart';

/// Payload `data` từ GET `/api/patrol-rounds/me/active`.
class ActivePatrolRound {
  ActivePatrolRound({
    required this.schedule,
    required this.round,
    required this.checkPoints,
  });

  final PatrolSchedule schedule;
  final PatrolRound round;
  final List<CheckPoint> checkPoints;

  factory ActivePatrolRound.fromJson(Map<String, dynamic> json) {
    final scheduleJson = json['schedule'];
    final roundJson = json['round'];
    if (scheduleJson is! Map<String, dynamic> ||
        roundJson is! Map<String, dynamic>) {
      throw const FormatException('active patrol round missing schedule/round');
    }

    final raw = json['checkPoints'] as List<dynamic>? ?? [];
    final points = raw
        .whereType<Map<String, dynamic>>()
        .map(CheckPoint.fromJson)
        .toList()
      ..sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));

    return ActivePatrolRound(
      schedule: PatrolSchedule.fromJson(scheduleJson),
      round: PatrolRound.fromJson(roundJson),
      checkPoints: points,
    );
  }
}
