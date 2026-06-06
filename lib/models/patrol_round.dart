/// Active patrol round (`round`).
class PatrolRound {
  PatrolRound({
    required this.id,
    required this.scheduleId,
    required this.status,
    required this.detailStatus,
    this.merchantId,
    this.expectedStartTime,
    this.expectedEndTime,
    this.assignedName,
  });

  final int id;
  final int scheduleId;
  final String status;
  final String detailStatus;
  final int? merchantId;
  final String? expectedStartTime;
  final String? expectedEndTime;
  final String? assignedName;

  factory PatrolRound.fromJson(Map<String, dynamic> json) {
    return PatrolRound(
      id: (json['id'] as num?)?.toInt() ?? 0,
      scheduleId: (json['scheduleId'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      detailStatus: json['detailStatus'] as String? ?? '',
      merchantId: (json['merchantId'] as num?)?.toInt(),
      expectedStartTime: json['expectedStartTime'] as String?,
      expectedEndTime: json['expectedEndTime'] as String?,
      assignedName: json['assignedName'] as String?,
    );
  }
}
