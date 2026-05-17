class CheckPoint {
  CheckPoint({
    required this.id,
    required this.siteId,
    required this.code,
    required this.name,
    required this.sequenceOrder,
    required this.active,
    this.nfc,
    this.qrImage,
    this.latitude,
    this.longitude,
    this.gpsAltitude,
    this.baroAltitude,
    this.accuracy,
    this.altitudeAccuracy,
    this.radius,
    this.description,
    this.createdBy,
    this.updatedBy,
    this.createdDate,
    this.updatedDate,
    this.verified
  });

  final int id;
  final int siteId;
  final String code;
  final String name;
  final int sequenceOrder;
  final bool active;
  final String? nfc;
  final String? qrImage;
  final double? latitude;
  final double? longitude;
  final double? gpsAltitude;
  final double? baroAltitude;
  final double? accuracy;
  final double? altitudeAccuracy;
  final double? radius;
  final String? description;
  final String? createdBy;
  final String? updatedBy;
  final String? createdDate;
  final String? updatedDate;
  final bool? verified;

  bool get hasCoordinates =>
      latitude != null && longitude != null;

  CheckPoint copyWith({
    int? id,
    int? siteId,
    String? code,
    String? name,
    int? sequenceOrder,
    bool? active,
    String? nfc,
    String? qrImage,
    double? latitude,
    double? longitude,
    double? gpsAltitude,
    double? baroAltitude,
    double? accuracy,
    double? altitudeAccuracy,
    double? radius,
    String? description,
    String? createdBy,
    String? updatedBy,
    String? createdDate,
    String? updatedDate,
    bool? verified,
  }) {
    return CheckPoint(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      code: code ?? this.code,
      name: name ?? this.name,
      sequenceOrder: sequenceOrder ?? this.sequenceOrder,
      active: active ?? this.active,
      nfc: nfc ?? this.nfc,
      qrImage: qrImage ?? this.qrImage,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gpsAltitude: gpsAltitude ?? this.gpsAltitude,
      baroAltitude: baroAltitude ?? this.baroAltitude,
      accuracy: accuracy ?? this.accuracy,
      altitudeAccuracy: altitudeAccuracy ?? this.altitudeAccuracy,
      radius: radius ?? this.radius,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
      verified: verified ?? this.verified,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'siteId': siteId,
      'code': code,
      'name': name,
      'sequenceOrder': sequenceOrder,
      'active': active,
      'nfc': nfc,
      'qrImage': qrImage,
      'latitude': latitude,
      'longitude': longitude,
      'gpsAltitude': gpsAltitude,
      'baroAltitude': baroAltitude,
      'accuracy': accuracy,
      'altitudeAccuracy': altitudeAccuracy,
      'radius': radius,
      'description': description,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'createdDate': createdDate,
      'updatedDate': updatedDate,
      'verified': verified,
    };
  }

  factory CheckPoint.fromJson(Map<String, dynamic> json) {
    return CheckPoint(
      id: (json['id'] as num?)?.toInt() ?? 0,
      siteId: (json['siteId'] as num?)?.toInt() ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sequenceOrder: (json['sequenceOrder'] as num?)?.toInt() ?? 0,
      active: json['active'] as bool? ?? true,
      nfc: json['nfc'] as String?,
      qrImage: json['qrImage'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      gpsAltitude: (json['gpsAltitude'] as num?)?.toDouble() ??
          (json['altitude'] as num?)?.toDouble(),
      baroAltitude: (json['baroAltitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      altitudeAccuracy: (json['altitudeAccuracy'] as num?)?.toDouble(),
      radius: (json['radius'] as num?)?.toDouble(),
      description: json['description'] as String?,
      createdBy: json['createdBy'] as String?,
      updatedBy: json['updatedBy'] as String?,
      createdDate: json['createdDate'] as String?,
      updatedDate: json['updatedDate'] as String?,
      verified: json['verified'] as bool? ?? false,
    );
  }
}

/// Payload `data` từ GET `/api/check-points/me/site` (object gồm site + danh sách).
class MySiteCheckPointsDto {
  MySiteCheckPointsDto({
    required this.siteId,
    this.siteName,
    this.siteAddress,
    required this.checkPoints,
  });

  final int siteId;
  final String? siteName;
  final String? siteAddress;
  final List<CheckPoint> checkPoints;

  factory MySiteCheckPointsDto.fromJson(Map<String, dynamic> json) {
    final raw = json['checkPoints'] as List<dynamic>? ?? [];
    final points = raw
        .whereType<Map<String, dynamic>>()
        .map(CheckPoint.fromJson)
        .toList()
      ..sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));
    return MySiteCheckPointsDto(
      siteId: (json['siteId'] as num?)?.toInt() ?? 0,
      siteName: json['siteName'] as String?,
      siteAddress: json['siteAddress'] as String?,
      checkPoints: points,
    );
  }
}
