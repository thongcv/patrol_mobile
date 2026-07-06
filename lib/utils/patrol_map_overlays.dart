import 'dart:ui' show Color;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/check_point.dart';
import 'check_point_proximity.dart';

/// Validates a coordinate pair and returns a [LatLng] (OpenStreetMap / flutter_map),
/// or null when out of range / non-finite.
LatLng? finitePatrolMapLatLng(double? lat, double? lng) {
  if (lat == null || lng == null) return null;
  if (!lat.isFinite || !lng.isFinite) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return LatLng(lat, lng);
}

/// Checkpoint radius circles drawn on the map ([CircleMarker], radius in meters).
List<CircleMarker> buildCheckpointRadiusCircles({
  required Iterable<CheckPoint> checkPoints,
  required bool Function(CheckPoint) isScanned,
  double defaultRadiusM = kDefaultCheckPointRadiusM,
}) {
  final circles = <CircleMarker>[];
  for (final p in checkPoints) {
    if (!p.hasCoordinates) continue;
    final center = finitePatrolMapLatLng(p.latitude, p.longitude);
    if (center == null) continue;
    final scanned = isScanned(p);
    final stroke = scanned ? const Color(0xFF34D399) : const Color(0xFFFBBF24);
    final radiusM = effectiveCheckPointRadiusM(
      p,
      defaultRadiusM: defaultRadiusM,
    );
    if (!radiusM.isFinite || radiusM <= 0) continue;
    circles.add(
      CircleMarker(
        point: center,
        radius: radiusM,
        useRadiusInMeter: true,
        color: stroke.withValues(alpha: 0.12),
        borderColor: stroke.withValues(alpha: 0.55),
        borderStrokeWidth: 1,
      ),
    );
  }
  return circles;
}
