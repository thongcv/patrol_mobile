import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/auth_strings.dart';
import '../../models/check_point.dart';
import '../../services/check_point_service.dart';
import 'patrol_shell.dart';

/// Lấy vị trí point — `link`: `patrol-point`.
/// GET `/api/check-points/me/site`, PUT `/api/check-points` để gán lat/lng.
class PatrolPointScreen extends StatefulWidget {
  const PatrolPointScreen({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
    this.embedded = false,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  /// `true` khi hiển thị trong tab Trang chủ (không push route mới).
  final bool embedded;

  @override
  State<PatrolPointScreen> createState() => _PatrolPointScreenState();
}

class _PatrolPointScreenState extends State<PatrolPointScreen> {
  MySiteCheckPointsDto? _site;
  bool _loadingPoints = true;
  CheckPointsMeSiteFailure? _pointsFailure;

  bool _gpsBusy = false;
  Position? _position;
  String? _gpsMessageKey;

  final Set<int> _updatingIds = {};

  AuthStrings get s => AuthStrings(widget.locale);

  @override
  void initState() {
    super.initState();
    _loadPoints();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshGps(silent: true);
    });
  }

  Future<void> _loadPoints() async {
    setState(() {
      _loadingPoints = true;
      _pointsFailure = null;
    });

    final r = await CheckPointService.instance.fetchMySiteCheckPoints();

    if (!mounted) return;
    if (r.ok) {
      setState(() {
        _site = r.data;
        _loadingPoints = false;
        _pointsFailure = null;
      });
    } else {
      setState(() {
        _site = null;
        _loadingPoints = false;
        _pointsFailure = r.failure;
      });
      final msg = _messageForPointsFailure(r.failure!);
      if (msg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  String? _messageForPointsFailure(CheckPointsMeSiteFailure f) {
    switch (f) {
      case CheckPointsMeSiteFailure.configMissing:
        return s.toastApiNotConfigured;
      case CheckPointsMeSiteFailure.unauthorized:
        return s.patrolPointUnauthorized;
      case CheckPointsMeSiteFailure.network:
        return s.toastNetworkErrorShort;
      case CheckPointsMeSiteFailure.badResponse:
        return s.patrolPointLoadFailed;
    }
  }

  String? _messageForUpdateFailure(CheckPointUpdateFailure f) {
    switch (f) {
      case CheckPointUpdateFailure.configMissing:
        return s.toastApiNotConfigured;
      case CheckPointUpdateFailure.unauthorized:
        return s.patrolPointUnauthorized;
      case CheckPointUpdateFailure.network:
        return s.toastNetworkErrorShort;
      case CheckPointUpdateFailure.badResponse:
        return s.patrolPointUpdateFailed;
    }
  }

  Future<void> _refreshGps({bool silent = false}) async {
    setState(() {
      _gpsBusy = true;
      if (!silent) _gpsMessageKey = null;
    });

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() {
        _gpsBusy = false;
        _position = null;
        _gpsMessageKey = 'service';
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _gpsBusy = false;
        _position = null;
        _gpsMessageKey = 'denied';
      });
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      setState(() {
        _gpsBusy = false;
        _position = pos;
        _gpsMessageKey = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gpsBusy = false;
        _position = null;
        _gpsMessageKey = 'error';
      });
    }
  }

  String _gpsStatusText() {
    if (_gpsBusy) return s.patrolPointGpsLoading;
    switch (_gpsMessageKey) {
      case 'service':
        return s.patrolPointGpsServiceOff;
      case 'denied':
        return s.patrolPointGpsDenied;
      case 'error':
        return s.patrolPointGpsError;
      default:
        break;
    }
    if (_position != null) {
      return s.patrolPointServerCoords(_position!.latitude, _position!.longitude);
    }
    return s.patrolPointGpsTapRefresh;
  }

  Future<void> _applyGpsToPoint(CheckPointDto point) async {
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.patrolPointUpdateNeedGps)),
      );
      return;
    }

    setState(() => _updatingIds.add(point.id));
    final payload = point.copyWith(
      latitude: _position!.latitude,
      longitude: _position!.longitude,
    );
    final r = await CheckPointService.instance.updateCheckPoint(payload);

    if (!mounted) return;
    setState(() => _updatingIds.remove(point.id));

    if (r.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.patrolPointUpdateSuccess)),
      );
      await _loadPoints();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageForUpdateFailure(r.failure!)!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);
    final points = _site?.checkPoints;
    final subtitleStyle = theme.labelMedium?.copyWith(
      color: Colors.white.withValues(alpha: 0.55),
      letterSpacing: 0.3,
      height: 1.2,
    );

    return PatrolFeatureScaffold(
      useOuterScaffold: !widget.embedded,
      locale: widget.locale,
      title: widget.embedded ? null : s.patrolPointTitle,
      heroIcon: Icons.my_location_rounded,
      heroColor: PatrolShellColors.accent,
      subtitleSlot: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              _gpsStatusText(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: subtitleStyle,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: _gpsBusy ? null : () => _refreshGps(silent: false),
            icon: _gpsBusy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PatrolShellColors.accent,
                    ),
                  )
                : Icon(
                    Icons.gps_fixed_rounded,
                    color: PatrolShellColors.accent,
                    size: 22,
                  ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryStrip(
            theme: theme,
            loading: _loadingPoints,
            siteName: _site?.siteName,
            siteAddress: _site?.siteAddress,
            points: points,
            failure: _pointsFailure,
            onReload: _loadPoints,
            strings: s,
          ),
          const SizedBox(height: 18),
          Text(
            s.patrolPointPointsHeading,
            style: theme.titleSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingPoints)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PatrolShellColors.accent,
                ),
              ),
            )
          else if (_pointsFailure != null)
            _ErrorBlock(theme: theme, strings: s, onRetry: _loadPoints)
          else if (points == null || points.isEmpty)
            Text(
              s.patrolPointEmpty,
              style: theme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
                height: 1.5,
              ),
            )
          else
            ...points.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CheckPointCard(
                  theme: theme,
                  point: p,
                  strings: s,
                  busy: _updatingIds.contains(p.id),
                  onApplyGps: () => _applyGpsToPoint(p),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.theme,
    required this.loading,
    this.siteName,
    this.siteAddress,
    required this.points,
    required this.failure,
    required this.onReload,
    required this.strings,
  });

  final TextTheme theme;
  final bool loading;
  final String? siteName;
  final String? siteAddress;
  final List<CheckPointDto>? points;
  final CheckPointsMeSiteFailure? failure;
  final VoidCallback onReload;
  final AuthStrings strings;

  @override
  Widget build(BuildContext context) {
    final n = points?.length ?? 0;
    final missing = points == null
        ? 0
        : points!.where((p) => !p.hasCoordinates).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PatrolShellColors.surfaceElevated.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: loading
                ? Text(
                    strings.patrolPointListLoading,
                    style: theme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  )
                : failure != null
                    ? Text(
                        strings.patrolPointLoadFailed,
                        style: theme.bodySmall?.copyWith(
                          color: Colors.orangeAccent.withValues(alpha: 0.9),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (siteName != null && siteName!.trim().isNotEmpty) ...[
                            Text(
                              siteName!.trim(),
                              style: theme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (siteAddress != null &&
                              siteAddress!.trim().isNotEmpty) ...[
                            Text(
                              '${strings.patrolPointSiteAddressLabel}: ${siteAddress!.trim()}',
                              style: theme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.55),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            strings.patrolPointCountSummary.replaceAll('{n}', '$n'),
                            style: theme.labelLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (n > 0 && missing > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              strings.patrolPointMissingCoordsSummary
                                  .replaceAll('{n}', '$missing'),
                              style: theme.bodySmall?.copyWith(
                                color: PatrolShellColors.accentMuted
                                    .withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ],
                      ),
          ),
          IconButton.filledTonal(
            onPressed: loading ? null : onReload,
            style: IconButton.styleFrom(
              backgroundColor: PatrolShellColors.accent.withValues(alpha: 0.18),
              foregroundColor: PatrolShellColors.accent,
            ),
            tooltip: strings.patrolPointReload,
            icon: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PatrolShellColors.accent,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.theme,
    required this.strings,
    required this.onRetry,
  });

  final TextTheme theme;
  final AuthStrings strings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PatrolShellColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.patrolPointLoadFailed,
            style: theme.bodyMedium?.copyWith(
              color: Colors.orangeAccent.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: PatrolShellColors.accent,
              foregroundColor: PatrolShellColors.background,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(strings.patrolPointReload),
          ),
        ],
      ),
    );
  }
}

class _CheckPointCard extends StatelessWidget {
  const _CheckPointCard({
    required this.theme,
    required this.point,
    required this.strings,
    required this.busy,
    required this.onApplyGps,
  });

  final TextTheme theme;
  final CheckPointDto point;
  final AuthStrings strings;
  final bool busy;
  final VoidCallback onApplyGps;

  @override
  Widget build(BuildContext context) {
    final coordLabel = point.hasCoordinates
        ? strings.patrolPointServerCoords(point.latitude!, point.longitude!)
        : strings.patrolPointServerNoCoords;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        color: PatrolShellColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PatrolShellColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              '${point.sequenceOrder}',
              style: theme.titleSmall?.copyWith(
                color: PatrolShellColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        point.name,
                        style: theme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!point.active)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            strings.patrolPointInactive,
                            style: theme.labelSmall?.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  point.code.isNotEmpty ? point.code : '—',
                  style: theme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      point.hasCoordinates
                          ? Icons.check_circle_outline_rounded
                          : Icons.warning_amber_rounded,
                      size: 17,
                      color: point.hasCoordinates
                          ? PatrolShellColors.accentMuted
                          : Colors.amberAccent.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        coordLabel,
                        style: theme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.68),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Tooltip(
            message: strings.patrolPointUpdateCoordsTooltip,
            child: IconButton.filledTonal(
              onPressed: busy ? null : onApplyGps,
              style: IconButton.styleFrom(
                backgroundColor:
                    PatrolShellColors.accent.withValues(alpha: 0.22),
                foregroundColor: PatrolShellColors.accent,
              ),
              icon: busy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PatrolShellColors.accent,
                      ),
                    )
                  : const Icon(Icons.add_location_alt_rounded, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
