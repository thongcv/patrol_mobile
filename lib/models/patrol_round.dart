/// Vòng tuần tra đang chạy (`round`).
class PatrolRound {
  PatrolRound({
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

  factory PatrolRound.fromJson(Map<String, dynamic> json) {
    return PatrolRound(
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
