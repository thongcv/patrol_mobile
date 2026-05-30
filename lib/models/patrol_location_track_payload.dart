import 'package:geolocator/geolocator.dart';

/// STOMP payload to `/app/patrol/track-location` — guard from JWT, no `guardId` in body.
/// Server resolves guard from Bearer JWT; do not send `guardId` or `roundId` in the body.
class PatrolLocationTrackPayload {
  PatrolLocationTrackPayload({
    required this.latitude,
    required this.longitude,
    required this.isMocked,
    required this.recordedAtMs,
    this.accuracyM,
    this.altitudeM,
    this.speedMps,
  });

  final double latitude;
  final double longitude;
  final bool isMocked;
  final int recordedAtMs;
  final double? accuracyM;
  final double? altitudeM;
  final double? speedMps;

  factory PatrolLocationTrackPayload.fromPosition({
    required Position position,
  }) {
    return PatrolLocationTrackPayload(
      latitude: position.latitude,
      longitude: position.longitude,
      isMocked: position.isMocked,
      recordedAtMs: position.timestamp.millisecondsSinceEpoch,
      accuracyM: position.accuracy.isFinite && position.accuracy > 0
          ? position.accuracy
          : null,
      altitudeM: position.altitude.isFinite ? position.altitude : null,
      speedMps: position.speed.isFinite && position.speed >= 0
          ? position.speed
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'isMocked': isMocked,
    'recordedAt': recordedAtMs,
    if (accuracyM != null) 'accuracyM': accuracyM,
    if (altitudeM != null) 'altitudeM': altitudeM,
    if (speedMps != null) 'speedMps': speedMps,
  };

  factory PatrolLocationTrackPayload.fromJson(Map<String, dynamic> json) {
    return PatrolLocationTrackPayload(
      latitude: (json['latitude'] as num?)?.toDouble() ??
          (json['lat'] as num?)?.toDouble() ??
          0,
      longitude: (json['longitude'] as num?)?.toDouble() ??
          (json['lng'] as num?)?.toDouble() ??
          0,
      isMocked: json['isMocked'] as bool? ?? false,
      recordedAtMs: (json['recordedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      accuracyM: (json['accuracyM'] as num?)?.toDouble(),
      altitudeM: (json['altitudeM'] as num?)?.toDouble(),
      speedMps: (json['speedMps'] as num?)?.toDouble(),
    );
  }
}
