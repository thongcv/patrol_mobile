import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/check_point.dart';
import 'check_point_proximity.dart';

LatLng? finitePatrolMapLatLng(double? lat, double? lng) {
  if (lat == null || lng == null) return null;
  if (!lat.isFinite || !lng.isFinite) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return LatLng(lat, lng);
}

/// Vòng tròn bán kính checkpoint trên map (Maps SDK `Circle`, không Geocoding).
Set<Circle> buildCheckpointRadiusCircles({
  required Iterable<CheckPoint> checkPoints,
  required bool Function(CheckPoint) isScanned,
}) {
  final circles = <Circle>{};
  for (final p in checkPoints) {
    if (!p.hasCoordinates) continue;
    final center = finitePatrolMapLatLng(p.latitude, p.longitude);
    if (center == null) continue;
    final scanned = isScanned(p);
    final stroke = scanned ? const Color(0xFF34D399) : const Color(0xFFFBBF24);
    final radiusM = p.radius ?? kDefaultCheckPointRadiusM;
    if (!radiusM.isFinite || radiusM <= 0) continue;
    circles.add(
      Circle(
        circleId: CircleId('cp_radius_${p.id}'),
        center: center,
        radius: radiusM,
        fillColor: stroke.withValues(alpha: 0.12),
        strokeColor: stroke.withValues(alpha: 0.55),
        strokeWidth: 1,
      ),
    );
  }
  return circles;
}

/// Đa giác xấp xỉ hình tròn (Maps SDK `Polygon`) khi cần polygon thay vì Circle.
Set<Polygon> buildCheckpointRadiusPolygons({
  required Iterable<CheckPoint> checkPoints,
  required bool Function(CheckPoint) isScanned,
  int segments = 32,
}) {
  final polygons = <Polygon>{};
  for (final p in checkPoints) {
    if (!p.hasCoordinates) continue;
    final center = finitePatrolMapLatLng(p.latitude, p.longitude);
    if (center == null) continue;
    final scanned = isScanned(p);
    final stroke = scanned ? const Color(0xFF34D399) : const Color(0xFFFBBF24);
    final radiusM = p.radius ?? kDefaultCheckPointRadiusM;
    if (!radiusM.isFinite || radiusM <= 0) continue;
    final ring = _geodesicRing(
      center: center,
      radiusMeters: radiusM,
      segments: segments,
    );
    polygons.add(
      Polygon(
        polygonId: PolygonId('cp_poly_${p.id}'),
        points: ring,
        fillColor: stroke.withValues(alpha: 0.12),
        strokeColor: stroke.withValues(alpha: 0.55),
        strokeWidth: 1,
      ),
    );
  }
  return polygons;
}

List<LatLng> _geodesicRing({
  required LatLng center,
  required double radiusMeters,
  required int segments,
}) {
  const earthRadiusM = 6371000.0;
  final latRad = center.latitude * math.pi / 180;
  final lngRad = center.longitude * math.pi / 180;
  final angular = radiusMeters / earthRadiusM;
  final points = <LatLng>[];
  for (var i = 0; i < segments; i++) {
    final bearing = 2 * math.pi * i / segments;
    final lat2 = math.asin(
      math.sin(latRad) * math.cos(angular) +
          math.cos(latRad) * math.sin(angular) * math.cos(bearing),
    );
    final lng2 = lngRad +
        math.atan2(
          math.sin(bearing) * math.sin(angular) * math.cos(latRad),
          math.cos(angular) - math.sin(latRad) * math.sin(lat2),
        );
    points.add(LatLng(lat2 * 180 / math.pi, lng2 * 180 / math.pi));
  }
  return points;
}
