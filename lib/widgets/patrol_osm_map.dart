import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Patrol map rendered with OpenStreetMap raster tiles via flutter_map.
///
/// No API key / billing required (unlike Google Maps). Tiles are served from
/// the OpenStreetMap standard tile servers; keep usage light and provide a
/// proper `userAgentPackageName` per the OSM tile usage policy.
class PatrolOsmMap extends StatelessWidget {
  const PatrolOsmMap({
    super.key,
    required this.mapController,
    required this.initialCenter,
    required this.initialZoom,
    this.onMapReady,
    this.onPositionChanged,
    this.markers = const [],
    this.circles = const [],
    this.backgroundColor,
  });

  final MapController mapController;
  final LatLng initialCenter;
  final double initialZoom;
  final VoidCallback? onMapReady;
  final void Function(MapCamera camera, bool hasGesture)? onPositionChanged;
  final List<Marker> markers;
  final List<CircleMarker> circles;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        minZoom: 2,
        maxZoom: 19,
        onMapReady: onMapReady,
        onPositionChanged: onPositionChanged,
        backgroundColor: backgroundColor ?? const Color(0xFF1F2937),
        interactionOptions: const InteractionOptions(
          // Note: `flingAnimation` is intentionally omitted. A pinch gesture can
          // leave the tracked focal offset at zero while still carrying fling
          // velocity, which makes flutter_map compute a NaN fling direction
          // (`Offset / 0`) and corrupt the camera center into LatLng(NaN, NaN).
          flags: InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.scrollWheelZoom,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.sps.patrol',
          maxNativeZoom: 19,
          tileProvider: NetworkTileProvider(),
        ),
        if (circles.isNotEmpty) CircleLayer(circles: circles),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomRight,
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }
}
