import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../http/api_failure.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/patrol_coord_label.dart';
import '../../models/check_point.dart';
import '../../services/check_point_service.dart';
import '../../utils/api_image_preview.dart';
import '../../utils/barometric_altitude.dart';
import '../../utils/device_location.dart';
import 'patrol_shell.dart';

/// Lấy vị trí point — `link`: `patrol-point`.
/// GET `/api/check-points/me/site`, PUT `/api/check-points` để gán lat/lng/độ cao.
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
  ApiFailure? _pointsFailure;

  LiveDeviceLocationTracker? _locationTracker;

  final Set<int> _updatingIds = {};

  /// Điểm có `qrImage` khác rỗng từ GET danh sách gần nhất — hiện QR ngay khi parse được.
  Set<int> _pointIdsWithQrPayloadFromLastFetch = {};

  /// Điểm đã gửi tọa độ thành công (phiên) — cho phép hiện QR khi `qrImage` có dữ liệu hợp lệ.
  final Set<int> _pointIdsRevealQrAfterGpsOk = {};

  @override
  void initState() {
    super.initState();
    _loadPoints();
    unawaited(_initLocationTracker());
  }

  Future<void> _initLocationTracker() async {
    final tracker = await LiveDeviceLocationTracker.create(
      onChanged: () {
        if (mounted) setState(() {});
      },
      isActive: () => mounted,
    );
    if (!mounted) {
      await tracker.dispose();
      return;
    }
    _locationTracker = tracker;
    setState(() {});
    await tracker.start();
  }

  @override
  void dispose() {
    final tracker = _locationTracker;
    if (tracker != null) unawaited(tracker.dispose());
    super.dispose();
  }

  Future<void> _loadPoints() async {
    setState(() {
      _loadingPoints = true;
      _pointsFailure = null;
    });

    final r = await CheckPointService.instance.fetchMySiteCheckPoints();

    if (!mounted) return;
    if (r.ok) {
      _commitSiteFromDto(r.data!, finishInitialLoad: true);
    } else {
      setState(() {
        _site = null;
        _loadingPoints = false;
        _pointsFailure = r.failure;
        _pointIdsWithQrPayloadFromLastFetch = {};
      });
      final l10n = AppLocalizations.of(context)!;
      final msg = _messageForPointsFailure(r.failure!, l10n);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _commitSiteFromDto(
    MySiteCheckPointsDto data, {
    required bool finishInitialLoad,
  }) {
    final idsWithQrPayload = <int>{
      for (final p in data.checkPoints)
        if (p.qrImage != null && p.qrImage!.trim().isNotEmpty) p.id,
    };
    setState(() {
      _site = data;
      if (finishInitialLoad) _loadingPoints = false;
      _pointsFailure = null;
      _pointIdsWithQrPayloadFromLastFetch = idsWithQrPayload;
    });
  }

  String _messageForPointsFailure(ApiFailure f, AppLocalizations l10n) {
    return f.userMessage(
      configMissing: l10n.toastApiNotConfigured,
      network: l10n.toastNetworkErrorShort,
      unauthorized: l10n.patrolPointUnauthorized,
      badResponse: l10n.patrolPointLoadFailed,
      server: l10n.patrolPointLoadFailed,
    );
  }

  String _messageForUpdateFailure(ApiFailure f, AppLocalizations l10n) {
    return f.userMessage(
      configMissing: l10n.toastApiNotConfigured,
      network: l10n.toastNetworkErrorShort,
      unauthorized: l10n.patrolPointUnauthorized,
      badResponse: l10n.patrolPointUpdateFailed,
      server: l10n.patrolPointUpdateFailed,
    );
  }

  Future<void> _applyGpsToPoint(CheckPoint point) async {
    setState(() => _updatingIds.add(point.id));

    final tracker = _locationTracker;
    final wantBaro = tracker != null && tracker.barometerSupported;
    final gps = await readDeviceGpsOnce(
      enableBarometer: wantBaro,
      targetAccuracyM: kCheckpointGpsTargetAccuracyM,
    );
    final freshBaro = gps.barometricAltitude;

    if (!mounted) return;

    if (gps.position == null) {
      setState(() => _updatingIds.remove(point.id));
      final l10n = AppLocalizations.of(context)!;
      final msg = switch (gps.messageKey) {
        'service' => l10n.patrolPointGpsServiceOff,
        'denied' => l10n.patrolPointGpsDenied,
        'error' => l10n.patrolPointGpsError,
        'unavailable' => l10n.patrolPointUpdateNeedGps,
        _ => l10n.patrolPointUpdateNeedGps,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final baroAltitude = tracker != null && tracker.barometerSupported
        ? (freshBaro ?? point.baroAltitude)
        : point.baroAltitude;

    tracker?.applyGpsReading(
      position: gps.position!,
      freshBarometricAltitude: freshBaro,
    );

    final gpsAlt = gps.position!.altitude;
    final gpsAltitude = gpsAlt.isFinite ? gpsAlt : point.gpsAltitude;

    final payload = point.copyWith(
      latitude: gps.position!.latitude,
      longitude: gps.position!.longitude,
      gpsAltitude: gpsAltitude,
      baroAltitude: baroAltitude,
      accuracy: gps.position!.accuracy,
      altitudeAccuracy: gps.position!.altitudeAccuracy,
    );
    final r = await CheckPointService.instance.updateCheckPoint(payload);

    if (!mounted) return;

    if (r.ok) {
      final server = r.data;
      var merged = payload;
      if (server != null) {
        final q = server.qrImage?.trim();
        merged = payload.copyWith(
          qrImage: (q != null && q.isNotEmpty)
              ? server.qrImage
              : payload.qrImage,
          latitude: server.latitude ?? payload.latitude,
          longitude: server.longitude ?? payload.longitude,
          gpsAltitude: server.gpsAltitude ?? payload.gpsAltitude,
          baroAltitude: server.baroAltitude ?? payload.baroAltitude,
        );
      }
      final site = _site;
      setState(() {
        _updatingIds.remove(point.id);
        _pointIdsRevealQrAfterGpsOk.add(merged.id);
        final mergedQr = merged.qrImage?.trim();
        if (mergedQr != null && mergedQr.isNotEmpty) {
          _pointIdsWithQrPayloadFromLastFetch = {
            ..._pointIdsWithQrPayloadFromLastFetch,
            merged.id,
          };
        }
        if (site != null) {
          _site = MySiteCheckPointsDto(
            siteId: site.siteId,
            siteName: site.siteName,
            siteAddress: site.siteAddress,
            checkPoints: [
              for (final p in site.checkPoints)
                if (p.id == merged.id) merged else p,
            ],
          );
        }
      });
      if (site == null) {
        await _loadPoints();
      }
      if (!mounted) return;
      final l10nOk = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10nOk.patrolPointUpdateSuccess)));
    } else {
      setState(() => _updatingIds.remove(point.id));
      final l10nFail = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageForUpdateFailure(r.failure!, l10nFail))),
      );
    }
  }

  String _gpsStatusText(AppLocalizations l10n) {
    final t = _locationTracker;
    if (t == null || t.busy) return l10n.patrolPointGpsLoading;
    switch (t.messageKey) {
      case 'service':
        return l10n.patrolPointGpsServiceOff;
      case 'denied':
        return l10n.patrolPointGpsDenied;
      case 'error':
        return l10n.patrolPointGpsError;
      case 'unavailable':
        return l10n.patrolPointUpdateNeedGps;
      default:
        break;
    }
    final pos = t.position;
    if (pos != null) {
      return patrolServerCoordLabel(
        l10n,
        pos.latitude,
        pos.longitude,
        altitude: t.altitudeForDisplay(pos),
      );
    }
    return l10n.patrolPointGpsTapRefresh;
  }

  @override
  Widget build(BuildContext context) {
    final theme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);
    final l10n = AppLocalizations.of(context)!;
    final points = _site?.checkPoints;
    final subtitleStyle = theme.labelMedium?.copyWith(
      color: Colors.white.withValues(alpha: 0.55),
      letterSpacing: 0.3,
      height: 1.2,
    );

    return PatrolFeatureScaffold(
      useOuterScaffold: !widget.embedded,
      locale: widget.locale,
      title: widget.embedded ? null : l10n.patrolPointTitle,
      heroIcon: Icons.my_location_rounded,
      heroColor: PatrolShellColors.accent,
      subtitleSlot: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              _gpsStatusText(l10n),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: subtitleStyle,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: _locationTracker == null || _locationTracker!.busy
                ? null
                : () => unawaited(
                    _locationTracker!.start(userInitiated: true),
                  ),
            icon: _locationTracker == null || _locationTracker!.busy
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
            l10n: l10n,
          ),
          const SizedBox(height: 18),
          Text(
            l10n.patrolPointPointsHeading,
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
            _ErrorBlock(theme: theme, l10n: l10n, onRetry: _loadPoints)
          else if (points == null || points.isEmpty)
            Text(
              l10n.patrolPointEmpty,
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
                  l10n: l10n,
                  busy: _updatingIds.contains(p.id),
                  showQrImage:
                      _pointIdsWithQrPayloadFromLastFetch.contains(p.id) ||
                      _pointIdsRevealQrAfterGpsOk.contains(p.id),
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
    required this.l10n,
  });

  final TextTheme theme;
  final bool loading;
  final String? siteName;
  final String? siteAddress;
  final List<CheckPoint>? points;
  final ApiFailure? failure;
  final VoidCallback onReload;
  final AppLocalizations l10n;

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
                    l10n.patrolPointListLoading,
                    style: theme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  )
                : failure != null
                ? Text(
                    failure!.userMessage(
                      configMissing: l10n.toastApiNotConfigured,
                      network: l10n.toastNetworkErrorShort,
                      unauthorized: l10n.patrolPointUnauthorized,
                      badResponse: l10n.patrolPointLoadFailed,
                      server: l10n.patrolPointLoadFailed,
                    ),
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
                          '${l10n.patrolPointSiteAddressLabel}: ${siteAddress!.trim()}',
                          style: theme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.55),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        l10n.patrolPointCountSummary(n),
                        style: theme.labelLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (n > 0 && missing > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          l10n.patrolPointMissingCoordsSummary(missing),
                          style: theme.bodySmall?.copyWith(
                            color: PatrolShellColors.accentMuted.withValues(
                              alpha: 0.85,
                            ),
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
            tooltip: l10n.patrolPointReload,
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
    required this.l10n,
    required this.onRetry,
  });

  final TextTheme theme;
  final AppLocalizations l10n;
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
            l10n.patrolPointLoadFailed,
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
            label: Text(l10n.patrolPointReload),
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
    required this.l10n,
    required this.busy,
    required this.showQrImage,
    required this.onApplyGps,
  });

  final TextTheme theme;
  final CheckPoint point;
  final AppLocalizations l10n;
  final bool busy;
  final bool showQrImage;
  final VoidCallback onApplyGps;

  @override
  Widget build(BuildContext context) {
    final coordLabel = point.hasCoordinates
        ? patrolServerCoordLabel(
            l10n,
            point.latitude!,
            point.longitude!,
            altitude: resolveAltitudeMeters(
              barometricMeters: point.baroAltitude,
              gpsMeters: point.gpsAltitude ?? double.nan,
            ),
          )
        : l10n.patrolPointServerNoCoords;
    final qrPreview = showQrImage
        ? apiImagePreview(point.qrImage, size: 64)
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PatrolShellColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  '${point.sequenceOrder}',
                  style: theme.titleSmall?.copyWith(
                    color: PatrolShellColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        point.name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
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
                            l10n.patrolPointInactive,
                            style: theme.labelSmall?.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Tooltip(
                message: l10n.patrolPointUpdateCoordsTooltip,
                child: IconButton.filledTonal(
                  onPressed: busy ? null : onApplyGps,
                  style: IconButton.styleFrom(
                    backgroundColor: PatrolShellColors.accent.withValues(
                      alpha: 0.22,
                    ),
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
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (qrPreview != null) ...[qrPreview, const SizedBox(width: 10)],
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        point.hasCoordinates
                            ? Icons.check_circle_outline_rounded
                            : Icons.warning_amber_rounded,
                        size: 17,
                        color: point.hasCoordinates
                            ? PatrolShellColors.accentMuted
                            : Colors.amberAccent.withValues(alpha: 0.85),
                      ),
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}
