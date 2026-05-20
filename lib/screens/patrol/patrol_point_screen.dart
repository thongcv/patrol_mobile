import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../http/api_failure.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/patrol_coord_label.dart';
import '../../models/check_point.dart';
import '../../services/check_point_service.dart';
import '../../utils/device_location.dart';
import '../../utils/bluetooth_beacon_reader.dart';
import '../../utils/nfc_tag_reader.dart';
import 'patrol_shell.dart';

enum _PatrolPointUpdatingKind { nfc, bluetooth, gps }

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
        bluetoothRssi: scanResult.beacon?.rssi,
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

String _nfcScanFailureMessage(AppLocalizations l10n, NfcReadFailure failure) {
  return switch (failure) {
    NfcReadFailure.disabled => l10n.patrolPointNfcDisabled,
    NfcReadFailure.timeout => l10n.patrolPointNfcScanTimeout,
    NfcReadFailure.unavailable => l10n.patrolPointNfcUnavailable,
    NfcReadFailure.noIdentifier || NfcReadFailure.failed =>
      l10n.patrolPointNfcScanFailed,
  };
}

String _bluetoothScanSummary(
  AppLocalizations l10n,
  BluetoothBeaconDetails beacon,
) {
  final distance = BluetoothBeaconDetails.formatDistanceMeters(
    beacon.distanceMeters,
  );
  return l10n.patrolPointBluetoothScanSummary(beacon.rssi, distance);
}

String? _bluetoothScanMetaLine(
  AppLocalizations l10n,
  BluetoothBeaconDetails beacon,
) {
  final address = beacon.deviceAddress?.trim();
  final hasAddress = address != null && address.isNotEmpty;
  final hasMajor = beacon.major != null;
  final hasMinor = beacon.minor != null;
  if (!hasAddress && !hasMajor && !hasMinor) return null;
  return l10n.patrolPointBluetoothScanMeta(
    hasAddress ? address : '—',
    hasMajor ? '${beacon.major}' : '—',
    hasMinor ? '${beacon.minor}' : '—',
  );
}

String _bluetoothScanFailureMessage(
  AppLocalizations l10n,
  BluetoothReadFailure failure,
) {
  return switch (failure) {
    BluetoothReadFailure.disabled => l10n.patrolPointBluetoothDisabled,
    BluetoothReadFailure.permissionDenied =>
      l10n.patrolPointBluetoothPermissionDenied,
    BluetoothReadFailure.timeout => l10n.patrolPointBluetoothScanTimeout,
    BluetoothReadFailure.unavailable => l10n.patrolPointBluetoothUnavailable,
    BluetoothReadFailure.failed => l10n.patrolPointBluetoothScanFailed,
  };
}

class _BluetoothIdentifierInputDialog extends StatefulWidget {
  const _BluetoothIdentifierInputDialog({
    this.initial,
    required this.messenger,
  });

  final String? initial;
  final ScaffoldMessengerState messenger;

  @override
  State<_BluetoothIdentifierInputDialog> createState() =>
      _BluetoothIdentifierInputDialogState();
}

class _BluetoothIdentifierInputDialogState
    extends State<_BluetoothIdentifierInputDialog> {
  late final TextEditingController _controller;
  bool _scanning = false;
  BluetoothBeaconDetails? _lastBeacon;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_scanning) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _scanning = true);
    final result = await readBluetoothBeaconIdentifier(
      timeout: kBluetoothDiscoveryScanTimeout,
      minRssi: kBluetoothDiscoveryMinRssi,
      successRssi: kBluetoothDiscoverySuccessRssi,
      stableHits: kBluetoothDiscoveryStableHits,
    );
    if (!mounted) return;
    if (result.ok) {
      setState(() {
        _scanning = false;
        _controller.text = result.identifier!;
        _lastBeacon = result.beacon;
      });
    } else {
      setState(() => _scanning = false);
    }
    if (!result.ok && result.failure != null) {
      widget.messenger.showSnackBar(
        SnackBar(
          content: Text(_bluetoothScanFailureMessage(l10n, result.failure!)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canScan = isBluetoothScanSupported;

    return AlertDialog(
      backgroundColor: PatrolShellColors.surface,
      title: Text(
        l10n.patrolPointBluetoothDialogTitle,
        style: const TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canScan) ...[
            OutlinedButton.icon(
              onPressed: _scanning ? null : _startScan,
              icon: _scanning
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PatrolShellColors.accent.withValues(
                          alpha: 0.9,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.bluetooth_rounded,
                      color: PatrolShellColors.accent.withValues(alpha: 0.95),
                    ),
              label: Text(
                _scanning
                    ? l10n.patrolPointBluetoothScanning
                    : l10n.patrolPointBluetoothScanButton,
                style: TextStyle(
                  color: _scanning ? Colors.white54 : PatrolShellColors.accent,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_lastBeacon != null) ...[
            Text(
              _bluetoothScanSummary(l10n, _lastBeacon!),
              style: TextStyle(
                color: PatrolShellColors.accent.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
            if (_bluetoothScanMetaLine(l10n, _lastBeacon!) != null) ...[
              const SizedBox(height: 4),
              Text(
                _bluetoothScanMetaLine(l10n, _lastBeacon!)!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
            ],
            if (_lastBeacon!.deviceName != null &&
                _lastBeacon!.deviceName!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                l10n.patrolPointBluetoothScanName(
                  _lastBeacon!.deviceName!.trim(),
                ),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autofocus: !canScan,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: l10n.patrolPointBluetoothDialogHint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(
                  BluetoothReadResult.success(
                    v.trim(),
                    beacon: _lastBeacon,
                  ),
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _scanning ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.patrolRoundCancel),
        ),
        FilledButton(
          onPressed: _scanning
              ? null
              : () => Navigator.of(context).pop(
                    BluetoothReadResult.success(
                      _controller.text.trim(),
                      beacon: _lastBeacon,
                    ),
                  ),
          style: FilledButton.styleFrom(
            backgroundColor: PatrolShellColors.accent,
            foregroundColor: PatrolShellColors.background,
          ),
          child: Text(l10n.patrolPointDialogSave),
        ),
      ],
    );
  }
}

class _NfcIdentifierInputDialog extends StatefulWidget {
  const _NfcIdentifierInputDialog({
    this.initial,
    required this.messenger,
  });

  final String? initial;
  final ScaffoldMessengerState messenger;

  @override
  State<_NfcIdentifierInputDialog> createState() =>
      _NfcIdentifierInputDialogState();
}

class _NfcIdentifierInputDialogState extends State<_NfcIdentifierInputDialog> {
  late final TextEditingController _controller;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_scanning) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _scanning = true);
    final result = await readNfcTagIdentifier(
      iosAlertMessage: l10n.patrolPointNfcScanning,
    );
    if (!mounted) return;
    setState(() => _scanning = false);
    if (result.ok) {
      _controller.text = result.identifier!;
    } else if (result.failure != null) {
      widget.messenger.showSnackBar(
        SnackBar(
          content: Text(_nfcScanFailureMessage(l10n, result.failure!)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canScan = isNfcScanSupported;

    return AlertDialog(
      backgroundColor: PatrolShellColors.surface,
      title: Text(
        l10n.patrolPointNfcDialogTitle,
        style: const TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canScan) ...[
            OutlinedButton.icon(
              onPressed: _scanning ? null : _startScan,
              icon: _scanning
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PatrolShellColors.accent.withValues(
                          alpha: 0.9,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.nfc_rounded,
                      color: PatrolShellColors.accent.withValues(alpha: 0.95),
                    ),
              label: Text(
                _scanning
                    ? l10n.patrolPointNfcScanning
                    : l10n.patrolPointNfcScanButton,
                style: TextStyle(
                  color: _scanning ? Colors.white54 : PatrolShellColors.accent,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autofocus: !canScan,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: l10n.patrolPointNfcDialogHint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _scanning ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.patrolRoundCancel),
        ),
        FilledButton(
          onPressed: _scanning
              ? null
              : () => Navigator.of(context).pop(_controller.text.trim()),
          style: FilledButton.styleFrom(
            backgroundColor: PatrolShellColors.accent,
            foregroundColor: PatrolShellColors.background,
          ),
          child: Text(l10n.patrolPointDialogSave),
        ),
      ],
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

Future<void> _showPatrolCheckpointMetaDialog(
  BuildContext context, {
  required AppLocalizations l10n,
  required String title,
  required String body,
  VoidCallback? onEdit,
}) async {
  final mat = MaterialLocalizations.of(context);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: SelectableText(body),
      ),
      actions: [
        if (onEdit != null)
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onEdit();
            },
            child: Text(l10n.patrolPointCheckpointMetaChange),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(mat.closeButtonLabel),
        ),
      ],
    ),
  );
}

class _PatrolPointMetaIcon extends StatelessWidget {
  const _PatrolPointMetaIcon({
    required this.l10n,
    required this.busy,
    required this.icon,
    required this.applyTooltip,
    required this.detailTooltip,
    required this.dialogTitle,
    required this.dialogBody,
    required this.onApply,
    this.readOnly = false,
    this.showTooltip = true,
  });

  final AppLocalizations l10n;
  final bool busy;
  final IconData icon;
  /// Khi đã có dữ liệu — gợi ý khi nhấn giữ / hover.
  final String detailTooltip;
  /// Khi chưa có — hành động gán (luôn dùng cho NFC / Bluetooth / GPS).
  final String applyTooltip;
  final String dialogTitle;
  final String Function() dialogBody;
  final VoidCallback onApply;
  final bool readOnly;
  final bool showTooltip;

  Future<void> _onTap(BuildContext context) async {
    if (busy) return;
    final body = dialogBody();
    final hasDetail = body.trim().isNotEmpty;
    if (!hasDetail) {
      onApply();
      return;
    }
    await _showPatrolCheckpointMetaDialog(
      context,
      l10n: l10n,
      title: dialogTitle,
      body: body,
      onEdit: readOnly ? null : onApply,
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = dialogBody();
    final hasDetail = body.trim().isNotEmpty;
    final accent = hasDetail
        ? PatrolShellColors.accent
        : Colors.white.withValues(alpha: 0.55);
    final hint = hasDetail ? detailTooltip : applyTooltip;

    final button = IconButton.filledTonal(
      onPressed: busy || !showTooltip ? null : () => _onTap(context),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      style: IconButton.styleFrom(
        backgroundColor: PatrolShellColors.accent.withValues(
          alpha: hasDetail ? 0.28 : 0.14,
        ),
        foregroundColor: accent,
      ),
      icon: busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accent,
              ),
            )
          : Icon(icon, size: 22),
    );

    if (showTooltip) {
      return Tooltip(
        message: hint,
        child: button,
      );
    }
    return button;
  }
}

class _CheckPointCard extends StatelessWidget {
  const _CheckPointCard({
    required this.theme,
    required this.point,
    required this.l10n,
    required this.nfcBusy,
    required this.bluetoothBusy,
    required this.gpsBusy,
    required this.onApplyNfc,
    required this.onApplyBluetooth,
    required this.onApplyGps,
  });

  final TextTheme theme;
  final CheckPoint point;
  final AppLocalizations l10n;
  final bool nfcBusy;
  final bool bluetoothBusy;
  final bool gpsBusy;
  final VoidCallback onApplyNfc;
  final VoidCallback onApplyBluetooth;
  final VoidCallback onApplyGps;

  bool get _anyMetaBusy => nfcBusy || bluetoothBusy || gpsBusy;

  @override
  Widget build(BuildContext context) {
    final hasNfc = point.nfc != null && point.nfc!.trim().isNotEmpty;
    final hasBluetooth =
        point.bluetooth != null && point.bluetooth!.trim().isNotEmpty;
    final hasQrCode =
        point.qrCode != null && point.qrCode!.trim().isNotEmpty;
    final hasCoords = point.hasCoordinates;

    final needsAssignMenu = !hasNfc || !hasBluetooth || !hasCoords;

    String bluetoothDetailBody() {
      if (!hasBluetooth) return '';
      final buf = StringBuffer(
        l10n.patrolPointBluetoothValue(point.bluetooth!.trim()),
      );
      final rssi = point.bluetoothRssi;
      if (rssi != null) {
        buf.write('\nRSSI: $rssi dBm');
      }
      return buf.toString();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
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
              if (needsAssignMenu)
                PopupMenuButton<String>(
                  enabled: !_anyMetaBusy,
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'nfc':
                        onApplyNfc();
                        break;
                      case 'bluetooth':
                        onApplyBluetooth();
                        break;
                      case 'gps':
                        onApplyGps();
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (!hasNfc)
                      PopupMenuItem(
                        value: 'nfc',
                        child: Text(l10n.patrolPointUpdateNfcTooltip),
                      ),
                    if (!hasBluetooth)
                      PopupMenuItem(
                        value: 'bluetooth',
                        child: Text(l10n.patrolPointUpdateBluetoothTooltip),
                      ),
                    if (!hasCoords)
                      PopupMenuItem(
                        value: 'gps',
                        child: Text(l10n.patrolPointUpdateCoordsTooltip),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 2,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (hasNfc)
                _PatrolPointMetaIcon(
                  l10n: l10n,
                  busy: nfcBusy,
                  icon: Icons.nfc_rounded,
                  applyTooltip: l10n.patrolPointUpdateNfcTooltip,
                  detailTooltip: l10n.patrolPointNfcValue(point.nfc!.trim()),
                  dialogTitle: l10n.patrolPointNfcDialogTitle,
                  dialogBody: () => point.nfc!.trim(),
                  onApply: onApplyNfc,
                ),
              if (hasBluetooth)
                _PatrolPointMetaIcon(
                  l10n: l10n,
                  busy: bluetoothBusy,
                  icon: Icons.bluetooth_rounded,
                  applyTooltip: l10n.patrolPointUpdateBluetoothTooltip,
                  detailTooltip:
                      l10n.patrolPointBluetoothValue(point.bluetooth!.trim()),
                  dialogTitle: l10n.patrolPointBluetoothDialogTitle,
                  dialogBody: bluetoothDetailBody,
                  onApply: onApplyBluetooth,
                ),
              if (hasQrCode)
                _PatrolPointMetaIcon(
                  l10n: l10n,
                  busy: false,
                  icon: Icons.qr_code_scanner_rounded,
                  applyTooltip: l10n.patrolRoundChipQr,
                  detailTooltip: point.qrCode!.trim(),
                  dialogTitle: l10n.patrolRoundChipQr,
                  dialogBody: () => point.qrCode!.trim(),
                  onApply: () {},
                  readOnly: true,
                  showTooltip: false,
                ),
              if (hasCoords)
                _PatrolPointMetaIcon(
                  l10n: l10n,
                  busy: gpsBusy,
                  icon: Icons.gps_fixed_rounded,
                  applyTooltip: l10n.patrolPointUpdateCoordsTooltip,
                  detailTooltip: patrolServerCoordLabel(
                    l10n,
                    point.latitude!,
                    point.longitude!,
                    altitude: point.gpsAltitude != null &&
                            point.gpsAltitude!.isFinite
                        ? point.gpsAltitude
                        : null,
                  ),
                  dialogTitle: l10n.patrolRoundChipGps,
                  dialogBody: () => patrolServerCoordLabel(
                    l10n,
                    point.latitude!,
                    point.longitude!,
                    altitude: point.gpsAltitude != null &&
                            point.gpsAltitude!.isFinite
                        ? point.gpsAltitude
                        : null,
                  ),
                  onApply: onApplyGps,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
