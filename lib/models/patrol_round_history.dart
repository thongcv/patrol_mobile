import '../http/api_response.dart';

class PatrolRoundHistoryDetail {
  PatrolRoundHistoryDetail({
    required this.id,
    this.assignedAccountId,
    this.assignedName,
    required this.status,
  });

  final int id;
  final String? assignedAccountId;
  final String? assignedName;
  final String status;

  factory PatrolRoundHistoryDetail.fromJson(Map<String, dynamic> json) {
    return PatrolRoundHistoryDetail(
      id: jsonInt(json['id']) ?? 0,
      assignedAccountId: jsonStr(json['assignedAccountId']),
      assignedName: jsonStr(json['assignedName']),
      status: jsonStr(json['status']) ?? '',
    );
  }
}

class PatrolRoundHistoryItem {
  PatrolRoundHistoryItem({
    required this.id,
    required this.status,
    this.scheduleId,
    this.scheduleName,
    this.siteId,
    this.siteName,
    this.merchantId,
    this.expectedStartTime,
    this.expectedEndTime,
    this.createdDate,
    this.updatedDate,
    this.details = const [],
  });

  final int id;
  final String status;
  final int? scheduleId;
  final String? scheduleName;
  final int? siteId;
  final String? siteName;
  final int? merchantId;
  final String? expectedStartTime;
  final String? expectedEndTime;
  final String? createdDate;
  final String? updatedDate;
  final List<PatrolRoundHistoryDetail> details;

  /// Primary assignee label from details (name preferred).
  String get assigneeLabel {
    if (details.isEmpty) return '—';
    final names = <String>[];
    for (final d in details) {
      final name = d.assignedName?.trim();
      if (name != null && name.isNotEmpty) {
        names.add(name);
        continue;
      }
      final id = d.assignedAccountId?.trim();
      if (id != null && id.isNotEmpty) names.add(id);
    }
    if (names.isEmpty) return '—';
    return names.join(', ');
  }

  factory PatrolRoundHistoryItem.fromJson(Map<String, dynamic> json) {
    final detailsRaw = json['details'];
    final detailsList = detailsRaw is List ? detailsRaw : const <dynamic>[];

    return PatrolRoundHistoryItem(
      id: jsonInt(json['id']) ?? 0,
      status: jsonStr(json['status']) ?? '',
      scheduleId: jsonInt(json['scheduleId']),
      scheduleName: jsonStr(json['scheduleName']),
      siteId: jsonInt(json['siteId']),
      siteName: jsonStr(json['siteName']),
      merchantId: jsonInt(json['merchantId']),
      expectedStartTime: jsonStr(json['expectedStartTime']),
      expectedEndTime: jsonStr(json['expectedEndTime']),
      createdDate: jsonStr(json['createdDate']),
      updatedDate: jsonStr(json['updatedDate']),
      details: detailsList
          .map(jsonMapCoerce)
          .whereType<Map<String, dynamic>>()
          .map(PatrolRoundHistoryDetail.fromJson)
          .toList(),
    );
  }
}

class PatrolRoundHistoryPage {
  PatrolRoundHistoryPage({
    required this.content,
    required this.size,
    required this.number,
    required this.totalElements,
    required this.totalPages,
  });

  final List<PatrolRoundHistoryItem> content;
  final int size;
  final int number;
  final int totalElements;
  final int totalPages;

  bool get hasMore => number + 1 < totalPages;

  factory PatrolRoundHistoryPage.fromJson(Map<String, dynamic> json) {
    final contentRaw = json['content'];
    final contentList = contentRaw is List ? contentRaw : const <dynamic>[];
    final page = jsonMapCoerce(json['page']) ?? const <String, dynamic>{};

    return PatrolRoundHistoryPage(
      content: contentList
          .map(jsonMapCoerce)
          .whereType<Map<String, dynamic>>()
          .map(PatrolRoundHistoryItem.fromJson)
          .toList(),
      size: jsonInt(page['size']) ?? 12,
      number: jsonInt(page['number']) ?? 0,
      totalElements: jsonInt(page['totalElements']) ?? 0,
      totalPages: jsonInt(page['totalPages']) ?? 0,
    );
  }
}
