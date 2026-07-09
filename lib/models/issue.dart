import '../http/api_response.dart';

class Issue {
  Issue({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    this.currentAssigneeId,
    this.currentAssigneeName,
    this.siteId,
    this.note,
    this.createdDate,
    this.createdBy,
    this.createdByName,
    this.photoUrls = const [],
  });

  final int id;
  final String title;
  final String? description;
  final String status;
  final String? currentAssigneeId;
  final String? currentAssigneeName;
  final int? siteId;
  final String? note;
  final String? createdDate;
  final String? createdBy;
  final String? createdByName;
  final List<String> photoUrls;

  bool get isOpen {
    final s = status.trim().toUpperCase();
    return s == 'OPEN' || s == 'NEW';
  }

  factory Issue.fromJson(Map<String, dynamic> json) {
    final photos = json['photoUrls'];
    final photoList = photos is List
        ? photos.map((e) => e?.toString().trim()).whereType<String>().where((s) => s.isNotEmpty).toList()
        : const <String>[];

    return Issue(
      id: jsonInt(json['id']) ?? 0,
      title: jsonStr(json['title']) ?? '',
      description: jsonStr(json['description']),
      status: jsonStr(json['status']) ?? '',
      currentAssigneeId: jsonStr(json['currentAssigneeId']),
      currentAssigneeName: jsonStr(json['currentAssigneeName']),
      siteId: jsonInt(json['siteId']),
      note: jsonStr(json['note']),
      createdDate: jsonStr(json['createdDate']),
      createdBy: jsonStr(json['createdBy']),
      createdByName: jsonStr(json['createdByName']) ?? jsonStr(json['reporterName']),
      photoUrls: photoList,
    );
  }

}

class IssuePage {
  IssuePage({
    required this.content,
    required this.size,
    required this.number,
    required this.totalElements,
    required this.totalPages,
  });

  final List<Issue> content;
  final int size;
  final int number;
  final int totalElements;
  final int totalPages;

  bool get hasMore => number + 1 < totalPages;

  factory IssuePage.fromJson(Map<String, dynamic> json) {
    final contentRaw = json['content'];
    final contentList = contentRaw is List ? contentRaw : const <dynamic>[];
    final page = jsonMapCoerce(json['page']) ?? const <String, dynamic>{};

    return IssuePage(
      content: contentList
          .map(jsonMapCoerce)
          .whereType<Map<String, dynamic>>()
          .map(Issue.fromJson)
          .toList(),
      size: jsonInt(page['size']) ?? 10,
      number: jsonInt(page['number']) ?? 0,
      totalElements: jsonInt(page['totalElements']) ?? 0,
      totalPages: jsonInt(page['totalPages']) ?? 0,
    );
  }
}

class IssueCreateRequest {
  IssueCreateRequest({
    required this.title,
    this.description,
    required this.assigneeId,
    this.note,
    this.siteId,
    this.filePaths = const [],
  });

  final String title;
  final String? description;
  final String assigneeId;
  final String? note;
  final int? siteId;
  final List<String> filePaths;
}

class IssueUpdateRequest {
  IssueUpdateRequest({
    required this.id,
    required this.title,
    this.description,
    required this.assigneeId,
    this.note,
    this.siteId,
    this.filePaths = const [],
  });

  final int id;
  final String title;
  final String? description;
  final String assigneeId;
  final String? note;
  final int? siteId;
  final List<String> filePaths;
}

class IssueAssignment {
  IssueAssignment({
    required this.id,
    required this.issueId,
    this.assignerId,
    this.assignerName,
    this.assigneeId,
    this.assigneeName,
    required this.status,
    this.note,
    this.assignedAt,
    this.processedAt,
    this.createdDate,
  });

  final int id;
  final int issueId;
  final String? assignerId;
  final String? assignerName;
  final String? assigneeId;
  final String? assigneeName;
  final String status;
  final String? note;
  final String? assignedAt;
  final String? processedAt;
  final String? createdDate;

  factory IssueAssignment.fromJson(Map<String, dynamic> json) {
    return IssueAssignment(
      id: jsonInt(json['id']) ?? 0,
      issueId: jsonInt(json['issueId']) ?? 0,
      assignerId: jsonStr(json['assignerId']),
      assignerName: jsonStr(json['assignerName']),
      assigneeId: jsonStr(json['assigneeId']),
      assigneeName: jsonStr(json['assigneeName']),
      status: jsonStr(json['status']) ?? '',
      note: jsonStr(json['note']),
      assignedAt: jsonStr(json['assignedAt']),
      processedAt: jsonStr(json['processedAt']),
      createdDate: jsonStr(json['createdDate']),
    );
  }
}
