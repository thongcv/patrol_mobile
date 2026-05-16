import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../http/api_failure.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/patrol_coord_label.dart';
import '../../models/check_point.dart';
import '../../services/check_point_service.dart';
import '../../utils/barometric_altitude.dart';
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

  bool _gpsBusy = false;
  Position? _position;
  String? _gpsMessageKey;

  /// Độ cao từ barometer (phiên); dùng hiển thị và khi gửi điểm.
  double? _barometricAltitude;

  StreamSubscription<Position>? _positionStreamSub;
  StreamSubscription<double>? _barometerStreamSub;

  /// Điểm mốc so với stream: chỉ refresh UI khi đã dịch chuyển đủ xa (tránh nhiễu GPS).
  Position? _streamAnchor;

  /// Ngưỡng tối thiểu (m) so với lần hiển thị trước — nhỏ hơn = nhạy hơn (dễ nhấp nháy nếu GPS yếu).
  static const double _gpsUiMoveThresholdM = 1.0;

  /// Chỉ vẽ lại độ cao barometer khi thay đổi ít nhất bấy nhiêu (m).
  static const double _altitudeUiChangeThresholdM = 0.5;

  final Set<int> _updatingIds = {};

  /// Điểm có `qrImage` khác rỗng từ GET danh sách gần nhất — hiện QR ngay khi parse được.
  Set<int> _pointIdsWithQrPayloadFromLastFetch = {};

  /// Điểm đã gửi tọa độ thành công (phiên) — cho phép hiện QR khi `qrImage` có dữ liệu hợp lệ.
  final Set<int> _pointIdsRevealQrAfterGpsOk = {};

  double? _altitudeForDisplay(Position position) {
    return resolveAltitudeMeters(
      barometricMeters: _barometricAltitude,
      gpsMeters: position.altitude,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadPoints();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startGpsTracking());
    });
  }

  @override
  void dispose() {
    _stopBarometerTracking();
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    super.dispose();
  }

  void _stopBarometerTracking() {
    _barometerStreamSub?.cancel();
    _barometerStreamSub = null;
  }

  void _startBarometerTracking() {
    _stopBarometerTracking();
    _barometerStreamSub = barometricAltitudeStream().listen(
      (alt) {
        if (!mounted) return;
        final prev = _barometricAltitude;
        if (prev != null && (alt - prev).abs() < _altitudeUiChangeThresholdM) {
          return;
        }
        setState(() => _barometricAltitude = alt);
      },
      onError: (_) {},
      cancelOnError: false,
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  void _commitSiteFromDto(MySiteCheckPointsDto data, {required bool finishInitialLoad}) {
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

  /// Đọc GPS một lần (dùng cho nút làm mới và cho gán tọa độ — luôn gọi `getCurrentPosition` mới).
  Future<({Position? position, String? messageKey})> _readGps() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return (position: null, messageKey: 'service');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return (position: null, messageKey: 'denied');
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      return (position: pos, messageKey: null);
    } catch (_) {
      return (position: null, messageKey: 'error');
    }
  }

  /// Cấu hình stream theo nền tảng — `LocationSettings` chung thường không đủ trên iOS/Android.
  LocationSettings _positionStreamSettings() {
    if (kIsWeb) {
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          intervalDuration: const Duration(milliseconds: 500),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          activityType: ActivityType.fitness,
          pauseLocationUpdatesAutomatically: false,
        );
      default:
        return const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        );
    }
  }

  void _onPositionStreamUpdate(Position pos) {
    if (!mounted) return;
    final anchor = _streamAnchor ?? _position;
    if (anchor != null) {
      final moved = Geolocator.distanceBetween(
        anchor.latitude,
        anchor.longitude,
        pos.latitude,
        pos.longitude,
      );
      // Cho phép cập nhật nhỏ hơn ngưỡng nếu độ tin cậy tốt hơn rõ rệt (GPS “khóa” đường đi).
      final acc = pos.accuracy;
      final anchorAcc = anchor.accuracy;
      final betterFix = acc.isFinite &&
          anchorAcc.isFinite &&
          acc > 0 &&
          anchorAcc > 0 &&
          acc < anchorAcc - 2;
      final altDelta = pos.altitude.isFinite && anchor.altitude.isFinite
          ? (pos.altitude - anchor.altitude).abs()
          : 0.0;
      final altChanged =
          altDelta >= _altitudeUiChangeThresholdM && _barometricAltitude == null;
      if (moved < _gpsUiMoveThresholdM && !betterFix && !altChanged) return;
    }
    _streamAnchor = pos;
    setState(() {
      _position = pos;
      _gpsMessageKey = null;
    });
  }

  /// Lấy vị trí ngay, sau đó theo dõi stream để cập nhật lat/lng khi di chuyển.
  Future<void> _startGpsTracking({bool userInitiated = false}) async {
    _stopBarometerTracking();
    await _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _streamAnchor = null;
    _barometricAltitude = null;

    if (!mounted) return;
    setState(() {
      _gpsBusy = true;
      if (userInitiated) _gpsMessageKey = null;
    });

    final r = await _readGps();
    if (!mounted) return;

    if (r.position == null) {
      setState(() {
        _gpsBusy = false;
        _position = null;
        _gpsMessageKey = r.messageKey;
      });
      return;
    }

    setState(() {
      _position = r.position;
      _gpsMessageKey = null;
      _gpsBusy = false;
    });
    _streamAnchor = r.position;
    _startBarometerTracking();

    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: _positionStreamSettings(),
    ).listen(
      _onPositionStreamUpdate,
      onError: (_) {
        if (!mounted) return;
        setState(() => _gpsMessageKey = 'error');
      },
    );
  }

  String _gpsStatusText(AppLocalizations l10n) {
    if (_gpsBusy) return l10n.patrolPointGpsLoading;
    switch (_gpsMessageKey) {
      case 'service':
        return l10n.patrolPointGpsServiceOff;
      case 'denied':
        return l10n.patrolPointGpsDenied;
      case 'error':
        return l10n.patrolPointGpsError;
      default:
        break;
    }
    if (_position != null) {
      return patrolServerCoordLabel(
        l10n,
        _position!.latitude,
        _position!.longitude,
        altitude: _altitudeForDisplay(_position!),
      );
    }
    return l10n.patrolPointGpsTapRefresh;
  }

  Future<void> _applyGpsToPoint(CheckPoint point) async {
    setState(() => _updatingIds.add(point.id));

    final gps = await _readGps();

    if (!mounted) return;

    if (gps.position == null) {
      setState(() => _updatingIds.remove(point.id));
      final l10n = AppLocalizations.of(context)!;
      final msg = switch (gps.messageKey) {
        'service' => l10n.patrolPointGpsServiceOff,
        'denied' => l10n.patrolPointGpsDenied,
        'error' => l10n.patrolPointGpsError,
        _ => l10n.patrolPointUpdateNeedGps,
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      return;
    }

    setState(() { 
      _position = gps.position;
      _gpsMessageKey = null;
    });

    final gpsAlt = gps.position!.altitude;
    final gpsAltitude = gpsAlt.isFinite ? gpsAlt : point.gpsAltitude;
    final baroAltitude = _barometricAltitude ?? point.baroAltitude;

    final payload = point.copyWith(
      latitude: gps.position!.latitude,
      longitude: gps.position!.longitude,
      gpsAltitude: gpsAltitude,
      baroAltitude: baroAltitude,
    );
    final r = await CheckPointService.instance.updateCheckPoint(payload);

    if (!mounted) return;

    if (r.ok) {
      final server = r.data;
      var merged = payload;
      if (server != null) {
        final q = server.qrImage?.trim();
        merged = payload.copyWith(
          qrImage: (q != null && q.isNotEmpty) ? server.qrImage : payload.qrImage,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10nOk.patrolPointUpdateSuccess)),
      );
    } else {
      setState(() => _updatingIds.remove(point.id));
      final l10nFail = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageForUpdateFailure(r.failure!, l10nFail))),
      );
    }
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
            onPressed: _gpsBusy
                ? null
                : () => unawaited(_startGpsTracking(userInitiated: true)),
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
                  showQrImage: _pointIdsWithQrPayloadFromLastFetch
                          .contains(p.id) ||
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
        ? _checkPointQrPreview(point.qrImage, size: 64)
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
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (qrPreview != null) ...[
                qrPreview,
                const SizedBox(width: 10),
              ],
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

/// QR từ API: URL `http(s)://`, `data:image/...;base64,...`, hoặc chuỗi base64 thuần.
Widget? _checkPointQrPreview(String? qrImage, {double size = 88}) {
  final raw = qrImage?.trim();
  if (raw == null || raw.isEmpty) return null;

  Widget framed(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return framed(
      Image.network(
        raw,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(
          Icons.broken_image_outlined,
          size: size * 0.35,
          color: Colors.black38,
        ),
      ),
    );
  }

  String? b64Payload;
  if (raw.startsWith('data:image')) {
    final comma = raw.indexOf(',');
    if (comma != -1) {
      b64Payload = raw.substring(comma + 1);
    }
  } else {
    b64Payload = raw;
  }

  if (b64Payload == null || b64Payload.isEmpty) return null;

  try {
    final bytes = base64Decode(b64Payload.replaceAll(RegExp(r'\s'), ''));
    return framed(
      Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  } catch (_) {
    return null;
  }
}
