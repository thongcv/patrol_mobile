part of '../patrol_round_screen.dart';

/// Full-screen map: session tracking GPS + route points (OpenStreetMap / flutter_map).
class _RouteMapOverlay extends StatefulWidget {
  const _RouteMapOverlay({
    required this.routeRevision,
    required this.checkPointsProvider,
    required this.isScanned,
    required this.onDismiss,
  });

  final ValueNotifier<_RouteMapUpdate> routeRevision;
  final List<CheckPoint> Function() checkPointsProvider;
  final bool Function(CheckPoint) isScanned;
  final VoidCallback onDismiss;

  @override
  State<_RouteMapOverlay> createState() => _RouteMapOverlayState();
}

class _RouteMapOverlayState extends State<_RouteMapOverlay> {
  final MapController _mapController = MapController();
  bool _mapReady = false;
  LatLng? _userPosition;
  bool _loadingLocation = true;
  bool _didFitCamera = false;
  StreamSubscription<Position>? _trackPositionSub;

  static const _defaultCenter = LatLng(10.8231, 106.6297);
  static const _defaultZoom = 14.0;

  // Last known-good camera, used to self-heal if the camera ever ends up with a
  // non-finite center/zoom (which crashes flutter_map's projection).
  LatLng _lastGoodCenter = _defaultCenter;
  double _lastGoodZoom = _defaultZoom;
  bool _recoveringCamera = false;

  List<CheckPoint> get _checkPoints => widget.checkPointsProvider();

  List<CheckPoint> get _pointsWithGps =>
      _checkPoints.where((p) => p.hasCoordinates).toList(growable: false);

  @override
  void initState() {
    super.initState();
    widget.routeRevision.addListener(_onRouteRevision);
    unawaited(_startLocationTracking());
  }

  void _onRouteRevision() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    widget.routeRevision.removeListener(_onRouteRevision);
    final sub = _trackPositionSub;
    _trackPositionSub = null;
    if (sub != null) unawaited(sub.cancel());
    super.dispose();
  }

  Future<void> _startLocationTracking() async {
    final track = PatrolRealtimeTrackService.instance;

    void applyPosition(double lat, double lng) {
      if (!mounted) return;
      final latLng = finitePatrolMapLatLng(lat, lng);
      if (latLng == null) return;
      setState(() {
        _loadingLocation = false;
        _userPosition = latLng;
      });
      _fitMapToMarkersOnce();
    }

    final seed = track.lastKnownPosition;
    if (seed != null) {
      applyPosition(seed.latitude, seed.longitude);
    }

    _trackPositionSub = track.positionUpdates.listen((pos) {
      applyPosition(pos.latitude, pos.longitude);
    });

    if (seed != null) return;

    if (track.isSessionTracking) {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      if (_userPosition == null) {
        setState(() => _loadingLocation = false);
        _fitMapToMarkersOnce();
      }
      return;
    }

    final gps = await readDeviceGpsOnce(
      timeout: const Duration(seconds: 6),
      targetAccuracyM: 25,
    );
    if (!mounted) return;
    final pos = gps.position;
    if (pos != null) {
      applyPosition(pos.latitude, pos.longitude);
    } else {
      setState(() => _loadingLocation = false);
      _fitMapToMarkersOnce();
    }
  }

  void _fitMapToMarkersOnce() {
    if (_didFitCamera || !_mapReady) return;
    final positions = <LatLng>[];
    for (final p in _pointsWithGps) {
      final pos = finitePatrolMapLatLng(p.latitude, p.longitude);
      if (pos != null) positions.add(pos);
    }
    if (_userPosition != null) positions.add(_userPosition!);
    if (positions.isEmpty) return;

    _didFitCamera = true;
    _fitToPositions(positions, attempt: 0);
  }

  /// Fits the camera once the map has a real (finite, positive) size. While the
  /// overlay sheet is still animating in, the camera size can be the impossible
  /// placeholder size, which makes flutter_map's fit math produce NaN — so we
  /// wait for a laid-out frame before fitting.
  void _fitToPositions(List<LatLng> positions, {required int attempt}) {
    if (!mounted) return;
    final size = _mapController.camera.nonRotatedSize;
    final ready = size.width.isFinite &&
        size.height.isFinite &&
        size.width > 0 &&
        size.height > 0;
    if (!ready) {
      if (attempt >= 5) return;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _fitToPositions(positions, attempt: attempt + 1),
      );
      return;
    }

    final unique = <LatLng>[];
    final seen = <String>{};
    for (final p in positions) {
      if (seen.add('${p.latitude},${p.longitude}')) unique.add(p);
    }

    if (unique.length == 1) {
      _mapController.move(unique.first, 15);
      return;
    }

    // Keep padding within the available size to avoid a non-positive fit area.
    final padX = size.width / 4 < 56 ? size.width / 4 : 56.0;
    final padY = size.height / 4 < 56 ? size.height / 4 : 56.0;
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: unique,
          padding: EdgeInsets.symmetric(horizontal: padX, vertical: padY),
          maxZoom: 17,
        ),
      );
    } catch (_) {
      _mapController.move(unique.first, 14);
    }
  }

  void _onMapReady() {
    _mapReady = true;
    _fitMapToMarkersOnce();
  }

  /// Safety net: if the camera center/zoom ever becomes non-finite (a known
  /// failure mode in flutter_map gesture math), snap back to the last valid
  /// camera before the next paint projects the bad value and throws.
  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    final center = camera.center;
    final isFinite = center.latitude.isFinite &&
        center.longitude.isFinite &&
        camera.zoom.isFinite;
    if (isFinite) {
      _lastGoodCenter = center;
      _lastGoodZoom = camera.zoom;
      return;
    }
    if (_recoveringCamera) return;
    _recoveringCamera = true;
    _mapController.move(
      _lastGoodCenter,
      _lastGoodZoom.isFinite ? _lastGoodZoom : _defaultZoom,
    );
    _recoveringCamera = false;
  }

  List<CircleMarker> _buildCircles() {
    return buildCheckpointRadiusCircles(
      checkPoints: _pointsWithGps,
      isScanned: widget.isScanned,
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    for (final p in _pointsWithGps) {
      final pos = finitePatrolMapLatLng(p.latitude, p.longitude);
      if (pos == null) continue;
      final scanned = widget.isScanned(p);
      markers.add(
        Marker(
          point: pos,
          width: kMapPinWidth,
          height: kMapPinHeight,
          alignment: Alignment.topCenter,
          child: MapPin(
            color: scanned ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
            label: '${p.sequenceOrder}',
          ),
        ),
      );
    }
    final user = _userPosition;
    if (user != null) {
      markers.add(
        Marker(
          point: user,
          width: kMapPinWidth,
          height: kMapPinHeight,
          alignment: Alignment.topCenter,
          child: const MapPin(
            color: PatrolShellColors.accent,
            showLocationDot: true,
          ),
        ),
      );
    }
    return markers;
  }

  LatLng _initialCenter() {
    if (_userPosition != null) return _userPosition!;
    for (final p in _pointsWithGps) {
      final pos = finitePatrolMapLatLng(p.latitude, p.longitude);
      if (pos != null) return pos;
    }
    return _defaultCenter;
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
                      PatrolOsmMap(
                        key: const ValueKey('patrol_route_map'),
                        mapController: _mapController,
                        initialCenter: _initialCenter(),
                        initialZoom: _defaultZoom,
                        onMapReady: _onMapReady,
                        onPositionChanged: _onPositionChanged,
                        markers: _buildMarkers(),
                        circles: _buildCircles(),
                        backgroundColor: PatrolShellColors.surface,
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
