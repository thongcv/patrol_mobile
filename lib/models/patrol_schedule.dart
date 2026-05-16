/// Lịch tuần tra (`schedule` trong GET active round).
class PatrolSchedule {
  PatrolSchedule({
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
    this.siteName,
    this.siteAddress,
    this.totalCheckPoints,
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
  final String? siteName;
  final String? siteAddress;
  final int? totalCheckPoints;

  factory PatrolSchedule.fromJson(Map<String, dynamic> json) {
    return PatrolSchedule(
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
      siteName: json['siteName'] as String?,
      siteAddress: json['siteAddress'] as String?,
      totalCheckPoints: (json['totalCheckPoints'] as num?)?.toInt(),
    );
  }
}
