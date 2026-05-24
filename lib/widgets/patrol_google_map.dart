import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Patrol map — default Google style (light); Maps SDK only (see [GoogleMapsConfig]).
///
/// Disabled: Google myLocation layer, toolbar, compass opening Maps app, lite mode, etc.
class PatrolGoogleMap extends StatelessWidget {
  const PatrolGoogleMap({
    super.key,
    required this.initialCameraPosition,
    this.onMapCreated,
    this.markers = const {},
    this.polygons = const {},
    this.circles = const {},
    this.style,
  });

  final CameraPosition initialCameraPosition;
  final void Function(GoogleMapController controller)? onMapCreated;
  final Set<Marker> markers;
  final Set<Polygon> polygons;
  final Set<Circle> circles;
  final String? style;

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: initialCameraPosition,
      onMapCreated: onMapCreated,
      style: style,
      markers: markers,
      polygons: polygons,
      circles: circles,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      liteModeEnabled: false,
      indoorViewEnabled: false,
      trafficEnabled: false,
      buildingsEnabled: true,
    );
  }
}
