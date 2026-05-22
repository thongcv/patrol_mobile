part of '../patrol_round_screen.dart';

/// Bản đồ toàn màn hình: GPS thiết bị + điểm tuyến (Maps SDK only — [GoogleMapsConfig]).
class _RouteMapOverlay extends StatefulWidget {
  const _RouteMapOverlay({
    required this.routeRevision,
    required this.checkPointsProvider,
    required this.isScanned,
    required this.onDismiss,
  });

  final Listenable routeRevision;
  final List<CheckPoint> Function() checkPointsProvider;
  final bool Function(CheckPoint) isScanned;
  final VoidCallback onDismiss;

  @override
  State<_RouteMapOverlay> createState() => _RouteMapOverlayState();
}

class _RouteMapOverlayState extends State<_RouteMapOverlay> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  LatLng? _userPosition;
  bool _loadingLocation = true;
  bool _syncingMarkers = false;
  bool _didFitCamera = false;
  StreamSubscription<NativeGpsEvent>? _gpsSub;
  final Map<String, BitmapDescriptor> _pinIconCache = {};

  static final _defaultCenter = LatLng(10.8231, 106.6297);
  static const _defaultZoom = 14.0;

  List<CheckPoint> get _checkPoints => widget.checkPointsProvider();

  List<CheckPoint> get _pointsWithGps => _checkPoints
      .where((p) => p.hasCoordinates)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    widget.routeRevision.addListener(_onRouteRevision);
    unawaited(_startLocationTracking());
  }

  void _onRouteRevision() {
    if (!mounted) return;
    setState(() {});
    unawaited(_syncMarkers());
  }

  @override
  void dispose() {
    widget.routeRevision.removeListener(_onRouteRevision);
    final sub = _gpsSub;
    _gpsSub = null;
    if (sub != null) unawaited(sub.cancel());
    super.dispose();
  }

  Future<void> _startLocationTracking() async {
    final gps = await readDeviceGpsOnce(
      timeout: const Duration(seconds: 6),
      targetAccuracyM: 25,
    );
    if (!mounted) return;
    setState(() {
      _loadingLocation = false;
      _userPosition = finitePatrolMapLatLng(
        gps.position?.latitude,
        gps.position?.longitude,
      );
    });
    await _syncMarkers();
    await _fitMapToMarkersOnce();

    _gpsSub = listenDeviceGpsForMap(
      onPosition: (pos) {
        if (!mounted) return;
        final latLng = finitePatrolMapLatLng(pos.latitude, pos.longitude);
        if (latLng == null) return;
        _userPosition = latLng;
        unawaited(_updateUserMarkerOnly());
      },
    );
  }

  Future<void> _fitMapToMarkersOnce() async {
    if (_didFitCamera) return;
    _didFitCamera = true;
    await _fitMapToMarkers();
  }

  Future<BitmapDescriptor> _pinIcon({
    required Color color,
    String? label,
    bool showLocationDot = false,
  }) async {
    final key = '${color.toARGB32()}|$label|$showLocationDot';
    final cached = _pinIconCache[key];
    if (cached != null) return cached;
    final bytes = await buildMapPinImage(
      color: color,
      label: label,
      showLocationDot: showLocationDot,
    );
    final icon = BitmapDescriptor.bytes(
      bytes,
      width: 44,
      height: 52,
    );
    _pinIconCache[key] = icon;
    return icon;
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    await _syncMarkers();
    await _fitMapToMarkersOnce();
  }

  Future<void> _updateUserMarkerOnly() async {
    final pos = _userPosition;
    if (pos == null) return;
    final icon = await _pinIcon(
      color: PatrolShellColors.accent,
      showLocationDot: true,
    );
    if (!mounted) return;
    final others = _markers
        .where((m) => m.markerId.value != 'user')
        .toSet();
    setState(() {
      _markers = {
        ...others,
        Marker(
          markerId: const MarkerId('user'),
          position: pos,
          icon: icon,
          anchor: const Offset(0.5, 1.0),
        ),
      };
    });
  }

  Future<void> _syncMarkers() async {
    if (_syncingMarkers) return;
    _syncingMarkers = true;
    try {
      final markers = <Marker>{};

      for (final p in _pointsWithGps) {
        final pos = finitePatrolMapLatLng(p.latitude, p.longitude);
        if (pos == null) continue;
        final scanned = widget.isScanned(p);
        final color = scanned
            ? const Color(0xFF34D399)
            : const Color(0xFFFBBF24);
        final icon = await _pinIcon(
          color: color,
          label: '${p.sequenceOrder}',
        );
        markers.add(
          Marker(
            markerId: MarkerId('cp_${p.id}'),
            position: pos,
            icon: icon,
            anchor: const Offset(0.5, 1.0),
          ),
        );
      }

      final circles = buildCheckpointRadiusCircles(
        checkPoints: _pointsWithGps,
        isScanned: widget.isScanned,
      );

      if (_userPosition != null) {
        final icon = await _pinIcon(
          color: PatrolShellColors.accent,
          showLocationDot: true,
        );
        markers.add(
          Marker(
            markerId: const MarkerId('user'),
            position: _userPosition!,
            icon: icon,
            anchor: const Offset(0.5, 1.0),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _markers = markers;
        _circles = circles;
      });
    } finally {
      _syncingMarkers = false;
    }
  }

  Future<void> _fitMapToMarkers() async {
    final controller = _mapController;
    if (controller == null) return;

    final positions = <LatLng>[];
    for (final p in _pointsWithGps) {
      final pos = finitePatrolMapLatLng(p.latitude, p.longitude);
      if (pos != null) positions.add(pos);
    }
    if (_userPosition != null) positions.add(_userPosition!);
    if (positions.isEmpty) return;

    if (positions.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: positions.first, zoom: 15),
        ),
      );
      return;
    }

    var minLat = 90.0;
    var maxLat = -90.0;
    var minLng = 180.0;
    var maxLng = -180.0;
    for (final pos in positions) {
      if (pos.latitude < minLat) minLat = pos.latitude;
      if (pos.latitude > maxLat) maxLat = pos.latitude;
      if (pos.longitude < minLng) minLng = pos.longitude;
      if (pos.longitude > maxLng) maxLng = pos.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 56),
    );
  }

  CameraPosition _initialCamera() {
    var center = _defaultCenter;
    if (_userPosition != null) {
      center = _userPosition!;
    } else {
      for (final p in _pointsWithGps) {
        final pos = finitePatrolMapLatLng(p.latitude, p.longitude);
        if (pos != null) {
          center = pos;
          break;
        }
      }
    }
    return CameraPosition(target: center, zoom: _defaultZoom);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pad = MediaQuery.paddingOf(context);

    return Material(
      color: PatrolShellColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetVerticalDismissHandle(onDismiss: widget.onDismiss),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.patrolRoundMapSwipeDismiss,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + pad.bottom),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      if (!GoogleMapsConfig.isConfigured)
                        ColoredBox(
                          color: PatrolShellColors.surface,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Chưa cấu hình Google Maps: đặt GOOGLE_MAPS_API_KEY '
                                '(--dart-define) hoặc GoogleMapsConfig.devFallbackApiKey. '
                                'Trên iOS cần thêm key vào Info.plist.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ),
                          ),
                        )
                      else
                        PatrolGoogleMap(
                          key: const ValueKey('patrol_route_map'),
                          initialCameraPosition: _initialCamera(),
                          markers: _markers,
                          circles: _circles,
                          onMapCreated: _onMapCreated,
                        ),
                      if (_loadingLocation)
                        const Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF34D399),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: _MapLegend(l10n: l10n),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PatrolShellColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _legendRow(
              const Color(0xFF38BDF8),
              Icons.my_location_rounded,
              l10n.patrolRoundMapYou,
            ),
            const SizedBox(height: 6),
            _legendRow(
              const Color(0xFF34D399),
              null,
              l10n.patrolRoundMapCheckpointScanned,
            ),
            const SizedBox(height: 4),
            _legendRow(
              const Color(0xFFFBBF24),
              null,
              l10n.patrolRoundMapCheckpointPending,
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(Color color, IconData? icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        if (icon != null) ...[
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
