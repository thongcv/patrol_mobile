class CheckPoint {
  CheckPoint({
    required this.id,
    required this.siteId,
    this.qrCode,
    required this.name,
    required this.sequenceOrder,
    required this.active,
    this.nfc,
    this.bluetooth,
    this.qrImage,
    this.latitude,
    this.longitude,
    this.gpsAltitude,
    this.baroAltitude,
    this.accuracy,
    this.altitudeAccuracy,
    this.radius,
    this.rssi,
    this.major,
    this.minor,
    this.description,
    this.createdBy,
    this.updatedBy,
    this.createdDate,
    this.updatedDate,
    this.verified,
  });

  final int id;
  final int siteId;
  final String? qrCode;
  final String name;
  final int sequenceOrder;
  final bool active;
  final String? nfc;
  final String? bluetooth;
  final String? qrImage;
  final double? latitude;
  final double? longitude;
  final double? gpsAltitude;
  final double? baroAltitude;
  final double? accuracy;
  final double? altitudeAccuracy;
  final double? radius;
  final double? rssi;
  final int? major;
  final int? minor;
  final String? description;
  final String? createdBy;
  final String? updatedBy;
  final String? createdDate;
  final String? updatedDate;
  final bool? verified;

  bool get hasCoordinates {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return false;
    return lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  /// Ghép metadata từ GET `/api/check-points/me/site` vào mốc active.
  ///
  /// [preferActive] `true` khi refresh (GET `/api/patrol-rounds/me/active` là
  /// nguồn đúng cho `verified`, GPS, accuracy, audit…). Chỉ lấy từ site khi
  /// active thiếu. `false` khi load lần đầu — site bổ sung metadata đầy đủ hơn.
  CheckPoint mergeSiteMetadata(
    CheckPoint site, {
    required bool preferActive,
  }) {
    String pickStr(String activeVal, String siteVal) {
      if (!preferActive) return siteVal.isNotEmpty ? siteVal : activeVal;
      return activeVal.isNotEmpty ? activeVal : siteVal;
    }

    String? pickOptStr(String? activeVal, String? siteVal) {
      if (!preferActive) {
        final s = siteVal?.trim();
        if (s != null && s.isNotEmpty) return siteVal;
        return activeVal;
      }
      final a = activeVal?.trim();
      if (a != null && a.isNotEmpty) return activeVal;
      final s = siteVal?.trim();
      if (s != null && s.isNotEmpty) return siteVal;
      return activeVal;
    }

    double? pickOptDouble(double? activeVal, double? siteVal) {
      if (preferActive) return activeVal ?? siteVal;
      return siteVal ?? activeVal;
    }

    int? pickOptInt(int? activeVal, int? siteVal) {
      if (preferActive) return activeVal ?? siteVal;
      return siteVal ?? activeVal;
    }

    final order = preferActive
        ? (sequenceOrder != 0 ? sequenceOrder : site.sequenceOrder)
        : (site.sequenceOrder != 0 ? site.sequenceOrder : sequenceOrder);

    return CheckPoint(
      id: id,
      siteId: siteId != 0 ? siteId : site.siteId,
      qrCode: pickOptStr(qrCode, site.qrCode),
      name: pickStr(name, site.name),
      sequenceOrder: order,
      active: preferActive ? active : site.active,
      nfc: pickOptStr(nfc, site.nfc),
      bluetooth: pickOptStr(bluetooth, site.bluetooth),
      qrImage: qrImage,
      latitude: pickOptDouble(latitude, site.latitude),
      longitude: pickOptDouble(longitude, site.longitude),
      gpsAltitude: pickOptDouble(gpsAltitude, site.gpsAltitude),
      baroAltitude: pickOptDouble(baroAltitude, site.baroAltitude),
      accuracy: pickOptDouble(accuracy, site.accuracy),
      altitudeAccuracy: pickOptDouble(altitudeAccuracy, site.altitudeAccuracy),
      radius: pickOptDouble(radius, site.radius),
      rssi: pickOptDouble(rssi, site.rssi),
      major: pickOptInt(major, site.major),
      minor: pickOptInt(minor, site.minor),
      description: pickOptStr(description, site.description),
      createdBy: preferActive ? (createdBy ?? site.createdBy) : (site.createdBy ?? createdBy),
      updatedBy: preferActive ? (updatedBy ?? site.updatedBy) : (site.updatedBy ?? updatedBy),
      createdDate:
          preferActive ? (createdDate ?? site.createdDate) : (site.createdDate ?? createdDate),
      updatedDate:
          preferActive ? (updatedDate ?? site.updatedDate) : (site.updatedDate ?? updatedDate),
      verified: verified,
    );
  }

  CheckPoint copyWith({
    int? id,
    int? siteId,
    String? qrCode,
    String? name,
    int? sequenceOrder,
    bool? active,
    String? nfc,
    String? bluetooth,
    String? qrImage,
    double? latitude,
    double? longitude,
    double? gpsAltitude,
    double? baroAltitude,
    double? accuracy,
    double? altitudeAccuracy,
    double? radius,
    double? rssi,
    int? major,
    int? minor,
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
      qrCode: qrCode ?? this.qrCode,
      name: name ?? this.name,
      sequenceOrder: sequenceOrder ?? this.sequenceOrder,
      active: active ?? this.active,
      nfc: nfc ?? this.nfc,
      bluetooth: bluetooth ?? this.bluetooth,
      qrImage: qrImage ?? this.qrImage,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gpsAltitude: gpsAltitude ?? this.gpsAltitude,
      baroAltitude: baroAltitude ?? this.baroAltitude,
      accuracy: accuracy ?? this.accuracy,
      altitudeAccuracy: altitudeAccuracy ?? this.altitudeAccuracy,
      radius: radius ?? this.radius,
      rssi: rssi ?? this.rssi,
      major: major ?? this.major,
      minor: minor ?? this.minor,
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
      'qrCode': qrCode,
      'name': name,
      'sequenceOrder': sequenceOrder,
      'active': active,
      'nfc': nfc,
      'bluetooth': bluetooth,
      'qrImage': qrImage,
      'latitude': latitude,
      'longitude': longitude,
      'gpsAltitude': gpsAltitude,
      'baroAltitude': baroAltitude,
      'accuracy': accuracy,
      'altitudeAccuracy': altitudeAccuracy,
      'radius': radius,
      'rssi': rssi,
      'major': major,
      'minor': minor,
      'description': description,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'createdDate': createdDate,
      'updatedDate': updatedDate,
      if (verified != null) 'verified': verified,
    };
  }

  factory CheckPoint.fromJson(Map<String, dynamic> json) {
    return CheckPoint(
      id: (json['id'] as num?)?.toInt() ?? 0,
      siteId: (json['siteId'] as num?)?.toInt() ?? 0,
      qrCode: json['qrCode'] as String? ?? json['code'] as String?,
      name: json['name'] as String? ?? '',
      sequenceOrder: (json['sequenceOrder'] as num?)?.toInt() ?? 0,
      active: json['active'] as bool? ?? true,
      nfc: json['nfc'] as String?,
      bluetooth: json['bluetooth'] as String?,
      qrImage: json['qrImage'] as String? ?? json['qr_image'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      gpsAltitude: (json['gpsAltitude'] as num?)?.toDouble() ??
          (json['altitude'] as num?)?.toDouble(),
      baroAltitude: (json['baroAltitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      altitudeAccuracy: (json['altitudeAccuracy'] as num?)?.toDouble(),
      radius: (json['radius'] as num?)?.toDouble(),
      rssi: (json['rssi'] as num?)?.toDouble(),
      major: (json['major'] as num?)?.toInt(),
      minor: (json['minor'] as num?)?.toInt(),
      description: json['description'] as String?,
      createdBy: json['createdBy'] as String?,
      updatedBy: json['updatedBy'] as String?,
      createdDate: json['createdDate'] as String?,
      updatedDate: json['updatedDate'] as String?,
      verified: _readBoolFromJson(json['verified']),
    );
  }
}

bool? _readBoolFromJson(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final s = value.trim().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
  }
  return null;
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
