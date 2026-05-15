import 'check_point.dart';

/// Lịch tuần tra (`schedule` trong GET active round).
class PatrolScheduleDto {
  PatrolScheduleDto({
    required this.id,
    required this.name,
    required this.siteId,
    required this.active,
    this.merchantId,
    this.startTime,
    this.endTime,
    this.startEffectiveDate,
    this.endEffectiveDate,
    this.frequencyMinutes,
    this.roundMinutes,
    this.assignedTeamNamesJoined,
    this.assignedAccountNamesJoined,
  });

  final int id;
  final String name;
  final int siteId;
  final bool active;
  final int? merchantId;
  final String? startTime;
  final String? endTime;
  final String? startEffectiveDate;
  final String? endEffectiveDate;
  final int? frequencyMinutes;
  final int? roundMinutes;
  final String? assignedTeamNamesJoined;
  final String? assignedAccountNamesJoined;

  factory PatrolScheduleDto.fromJson(Map<String, dynamic> json) {
    return PatrolScheduleDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      siteId: (json['siteId'] as num?)?.toInt() ?? 0,
      active: json['active'] as bool? ?? true,
      merchantId: (json['merchantId'] as num?)?.toInt(),
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      startEffectiveDate: json['startEffectiveDate'] as String?,
      endEffectiveDate: json['endEffectiveDate'] as String?,
      frequencyMinutes: (json['frequencyMinutes'] as num?)?.toInt(),
      roundMinutes: (json['roundMinutes'] as num?)?.toInt(),
      assignedTeamNamesJoined: json['assignedTeamNamesJoined'] as String?,
      assignedAccountNamesJoined:
          json['assignedAccountNamesJoined'] as String?,
    );
  }
}

/// Vòng tuần tra đang chạy (`round`).
class PatrolRoundDto {
  PatrolRoundDto({
    required this.id,
    required this.scheduleId,
    required this.status,
    this.merchantId,
    this.assignedTeamId,
    this.assignedAccountId,
    this.expectedStartTime,
    this.expectedEndTime,
    this.assignedName,
  });

  final int id;
  final int scheduleId;
  final String status;
  final int? merchantId;
  final int? assignedTeamId;
  final String? assignedAccountId;
  final String? expectedStartTime;
  final String? expectedEndTime;
  final String? assignedName;

  factory PatrolRoundDto.fromJson(Map<String, dynamic> json) {
    return PatrolRoundDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      scheduleId: (json['scheduleId'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      merchantId: (json['merchantId'] as num?)?.toInt(),
      assignedTeamId: (json['assignedTeamId'] as num?)?.toInt(),
      assignedAccountId: json['assignedAccountId'] as String?,
      expectedStartTime: json['expectedStartTime'] as String?,
      expectedEndTime: json['expectedEndTime'] as String?,
      assignedName: json['assignedName'] as String?,
    );
  }
}

/// Payload `data` từ GET `/api/patrol-rounds/me/active`.
class ActivePatrolRoundDto {
  ActivePatrolRoundDto({
    required this.schedule,
    required this.round,
    required this.checkPoints,
  });

  final PatrolScheduleDto schedule;
  final PatrolRoundDto round;
  final List<CheckPointDto> checkPoints;

  factory ActivePatrolRoundDto.fromJson(Map<String, dynamic> json) {
    final scheduleJson = json['schedule'];
    final roundJson = json['round'];
    if (scheduleJson is! Map<String, dynamic> ||
        roundJson is! Map<String, dynamic>) {
      throw const FormatException('active patrol round missing schedule/round');
    }

    final raw = json['checkPoints'] as List<dynamic>? ?? [];
    final points = raw
        .whereType<Map<String, dynamic>>()
        .map(CheckPointDto.fromJson)
        .toList()
      ..sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));

    return ActivePatrolRoundDto(
      schedule: PatrolScheduleDto.fromJson(scheduleJson),
      round: PatrolRoundDto.fromJson(roundJson),
      checkPoints: points,
    );
  }
}
