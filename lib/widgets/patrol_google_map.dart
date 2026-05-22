import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Bản đồ patrol — style mặc định Google (sáng); chỉ Maps SDK (xem [GoogleMapsConfig]).
///
/// Không bật: myLocation layer Google, toolbar, compass mở app Maps, lite mode, v.v.
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
