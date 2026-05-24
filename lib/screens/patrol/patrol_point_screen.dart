import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../http/api_failure.dart';
import '../../navigation/patrol_session.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/patrol_coord_label.dart';
import '../../models/check_point.dart';
import '../../services/account_session_store.dart';
import '../../services/check_point_service.dart';
import '../../utils/device_location.dart';
import '../../utils/bluetooth_beacon_reader.dart';
import '../../utils/nfc_tag_reader.dart';
import 'patrol_shell.dart';

part 'point/patrol_point_types.dart';
part 'point/patrol_point_bluetooth_helpers.dart';
part 'point/patrol_point_bluetooth_dialog.dart';
part 'point/patrol_point_nfc_dialog.dart';
part 'point/patrol_point_summary_strip.dart';
part 'point/patrol_point_error_block.dart';
part 'point/patrol_point_meta_dialog.dart';
part 'point/patrol_point_meta_icon.dart';
part 'point/patrol_point_check_point_card.dart';

/// Capture point location — `link`: `patrol-point`.
/// GET `/api/check-points/me/site`, PUT `/api/check-points` to assign lat/lng/altitude.
class PatrolPointScreen extends StatefulWidget {
  const PatrolPointScreen({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
    this.embedded = false,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  /// `true` when shown in Home tab (no new route push).
  final bool embedded;

  @override
  State<PatrolPointScreen> createState() => _PatrolPointScreenState();
}

class _PatrolPointScreenState extends State<PatrolPointScreen> {
  MySiteCheckPointsDto? _site;
  bool _loadingPoints = true;
  ApiFailure? _pointsFailure;

  LiveDeviceLocationTracker? _locationTracker;

  final Set<(int, _PatrolPointUpdatingKind)> _updatingFields = {};

  @override
  void initState() {
    super.initState();
    _loadPoints();
    unawaited(_initLocationTracker());
  }

  Future<void> _initLocationTracker() async {
    final tracker = await LiveDeviceLocationTracker.create(
      isActive: () => mounted,
    );
    if (!mounted) {
      tracker.dispose();
      return;
    }
    _locationTracker = tracker;
    setState(() {});
    await tracker.start();
  }

  @override
  void dispose() {
    _locationTracker?.dispose();
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
    } else if (PatrolSession.isUnauthorized(r.failure)) {
      await PatrolSession.endSessionAndNavigateToLogin();
    } else {
      setState(() {
        _site = null;
        _loadingPoints = false;
        _pointsFailure = r.failure;
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
    setState(() {
      _site = data;
      if (finishInitialLoad) _loadingPoints = false;
      _pointsFailure = null;
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
      badResponse: l10n.patrolPointFieldUpdateFailed,
      server: l10n.patrolPointFieldUpdateFailed,
    );
  }

  void _replacePointInSite(CheckPoint merged) {
    final site = _site;
    if (site == null) return;
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

  Future<bool> _persistCheckPointUpdate(
    CheckPoint payload,
    _PatrolPointUpdatingKind updatingKind,
  ) async {
    final r = await CheckPointService.instance.updateCheckPoint(payload);

    if (!mounted) return false;

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
          nfc: server.nfc ?? payload.nfc,
          bluetooth: server.bluetooth ?? payload.bluetooth,
        );
      }
      final site = _site;
      setState(() {
        _updatingFields.remove((payload.id, updatingKind));
        if (site != null) _replacePointInSite(merged);
      });
      if (site == null) {
        await _loadPoints();
      }
      return true;
    }

    setState(() => _updatingFields.remove((payload.id, updatingKind)));
    if (PatrolSession.isUnauthorized(r.failure)) {
      await PatrolSession.endSessionAndNavigateToLogin();
      return false;
    }
    final l10nFail = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_messageForUpdateFailure(r.failure!, l10nFail))),
    );
    return false;
  }

  Future<BluetoothReadResult?> _promptBluetoothIdentifier({String? initial}) {
    final messenger = ScaffoldMessenger.of(context);
    return showDialog<BluetoothReadResult>(
      context: context,
      builder: (ctx) => _BluetoothIdentifierInputDialog(
        initial: initial,
        messenger: messenger,
      ),
    );
  }

  Future<String?> _promptNfcIdentifier({String? initial}) {
    final messenger = ScaffoldMessenger.of(context);
    return showDialog<String>(
      context: context,
      builder: (ctx) => _NfcIdentifierInputDialog(
        initial: initial,
        messenger: messenger,
      ),
    );
  }

  Future<void> _applyNfcToPoint(CheckPoint point) async {
    final l10n = AppLocalizations.of(context)!;
    final value = await _promptNfcIdentifier(initial: point.nfc);
    if (value == null || !mounted) return;
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.patrolPointIdentifierEmpty)),
      );
      return;
    }

    setState(
      () => _updatingFields.add((point.id, _PatrolPointUpdatingKind.nfc)),
    );
    final ok = await _persistCheckPointUpdate(
      point.copyWith(nfc: value),
      _PatrolPointUpdatingKind.nfc,
    );
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.patrolPointFieldUpdateSuccess)),
    );
  }

  Future<void> _applyBluetoothToPoint(CheckPoint point) async {
    final l10n = AppLocalizations.of(context)!;
    final scanResult = await _promptBluetoothIdentifier(
      initial: point.bluetooth,
    );
    if (scanResult == null || !mounted) return;
    if (!scanResult.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.patrolPointIdentifierEmpty)),
      );
      return;
    }

    setState(
      () => _updatingFields.add((point.id, _PatrolPointUpdatingKind.bluetooth)),
    );
    final ok = await _persistCheckPointUpdate(
      point.copyWith(
        bluetooth: scanResult.identifier!,
        rssi: scanResult.beacon?.rssi.toDouble(),
      ),
      _PatrolPointUpdatingKind.bluetooth,
    );
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.patrolPointFieldUpdateSuccess)),
    );
  }

  Future<void> _applyGpsToPoint(CheckPoint point) async {
    setState(
      () => _updatingFields.add((point.id, _PatrolPointUpdatingKind.gps)),
    );

    final tracker = _locationTracker;
    final wantBaro = tracker != null && tracker.barometerSupported;
    final gps = await readDeviceGpsOnce(
      enableBarometer: wantBaro,
      targetAccuracyM: kCheckpointGpsTargetAccuracyM,
    );
    final freshBaro = gps.barometricAltitude;

    if (!mounted) return;

    if (gps.position == null) {
      setState(
        () => _updatingFields.remove((point.id, _PatrolPointUpdatingKind.gps)),
      );
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
    final ok = await _persistCheckPointUpdate(
      payload,
      _PatrolPointUpdatingKind.gps,
    );
    if (!mounted) return;

    if (ok) {
      final l10nOk = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10nOk.patrolPointUpdateSuccess)),
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

    Widget gpsSubtitleRow() => Row(
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
    );

    final tracker = _locationTracker;
    final subtitleSlot = tracker == null
        ? gpsSubtitleRow()
        : ListenableBuilder(
            listenable: tracker,
            builder: (context, _) => gpsSubtitleRow(),
          );

    return PatrolFeatureScaffold(
      useOuterScaffold: !widget.embedded,
      locale: widget.locale,
      title: widget.embedded ? null : l10n.patrolPointTitle,
      heroIcon: Icons.my_location_rounded,
      heroColor: PatrolShellColors.accent,
      subtitleSlot: subtitleSlot,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryStrip(
            theme: theme,
            loading: _loadingPoints,
            siteId: _site?.siteId,
            beaconUuid: AccountSessionStore.instance.companyBeaconUuid,
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
                  nfcBusy: _updatingFields
                      .contains((p.id, _PatrolPointUpdatingKind.nfc)),
                  bluetoothBusy: _updatingFields
                      .contains((p.id, _PatrolPointUpdatingKind.bluetooth)),
                  gpsBusy: _updatingFields
                      .contains((p.id, _PatrolPointUpdatingKind.gps)),
                  onApplyNfc: () => _applyNfcToPoint(p),
                  onApplyBluetooth: () => _applyBluetoothToPoint(p),
                  onApplyGps: () => _applyGpsToPoint(p),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

