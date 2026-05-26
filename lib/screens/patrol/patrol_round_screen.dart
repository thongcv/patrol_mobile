import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/google_maps_config.dart';
import '../../http/api_failure.dart';
import '../../navigation/patrol_session.dart';
import '../../l10n/app_localizations.dart';
import '../../models/active_patrol_round.dart';
import '../../models/check_point.dart';
import '../../models/patrol_round.dart';
import '../../services/check_point_service.dart';
import '../../services/patrol_log_service.dart';
import '../../services/patrol_round_service.dart';
import '../../services/patrol_active_round_cache.dart';
import '../../services/patrol_active_round_coordinator.dart';
import '../../services/patrol_realtime_track_coordinator.dart';
import '../../utils/bluetooth_beacon_reader.dart';
import '../../utils/check_point_proximity.dart';
import '../../utils/api_image_preview.dart';
import '../../utils/device_location.dart';
import '../../utils/super_gps_service.dart';
import '../../utils/map_pin_image.dart';
import '../../utils/patrol_map_overlays.dart';
import '../../utils/nfc_tag_reader.dart';
import '../../widgets/patrol_google_map.dart';
import '../../utils/patrol_datetime_format.dart';
import '../../utils/top_toast.dart';
import '../../widgets/qr_code_scanner_page.dart';
import 'patrol_shell.dart';
part 'round/patrol_round_types.dart';
part 'round/patrol_round_sheet_handle.dart';
part 'round/patrol_round_schedule_card.dart';
part 'round/patrol_round_round_card.dart';
part 'round/patrol_round_qr_photo_dialog.dart';
part 'round/patrol_round_qr_proximity.dart';
part 'round/patrol_round_route_point_card.dart';
part 'round/patrol_round_route_map_overlay.dart';
part 'round/patrol_round_common_widgets.dart';

/// QR preview / button size on checkpoint and round cards.
const double kPatrolQrPreviewSize = 64;

class PatrolRoundScreen extends StatefulWidget {
  const PatrolRoundScreen({
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
  State<PatrolRoundScreen> createState() => _PatrolRoundScreenState();
}

class _PatrolRoundScreenState extends State<PatrolRoundScreen> {
  ActivePatrolRound? _active;
  bool _loading = true;
  bool _refreshing = false;
  ApiFailure? _failure;
  final Set<int> _scannedCheckpointIds = {};
  /// Incremented after each successful GET active — forces list / QR preview rebuild.
  int _reloadToken = 0;
  /// Notifies route map overlay to refresh checkpoint state (scan / reload active).
  final ValueNotifier<int> _routeMapRevision = ValueNotifier(0);
  int? _scanningCheckpointId;
  _RoundManualScanKind? _manualScanKind;
  DeviceLocationWatch? _qrLocationWatch;
  bool _qrScanSubmitting = false;
  bool _autoScanActive = false;
  _RoundAutoScanKind? _autoScanKind;
  ValueNotifier<_QrScanProximityStatus>? _autoScanStatusNotifier;
  StreamSubscription<ActivePatrolRound?>? _activeRoundSocketSub;

  @override
  void initState() {
    super.initState();
    _activeRoundSocketSub =
        PatrolActiveRoundCoordinator.activeRoundChanges.listen((_) {
      if (!mounted) return;
      unawaited(_load(silent: _active != null));
    });
    _load();
  }

  @override
  void dispose() {
    TopToast.hide();
    _activeRoundSocketSub?.cancel();
    _routeMapRevision.dispose();
    unawaited(_stopQrLocationWatch());
    unawaited(PatrolRealtimeTrackCoordinator.setRoundScanBusy(false));
    super.dispose();
  }

  /// Pauses background auto-scan while any of the four scan buttons is active on the UI.
  void _syncBackgroundAutoScanSuppression() {
    final busy =
        _scanningCheckpointId != null ||
        _autoScanActive ||
        _manualScanKind != null;
    unawaited(PatrolRealtimeTrackCoordinator.setRoundScanBusy(busy));
  }

  void _notifyRouteMapRevision() {
    _routeMapRevision.value++;
  }

  Future<void> _stopQrLocationWatch() async {
    await _qrLocationWatch?.stop();
    _qrLocationWatch = null;
  }

  Future<void> _cancelQrScanWait() async {
    await _stopQrLocationWatch();
    _autoScanStatusNotifier?.dispose();
    _autoScanStatusNotifier = null;
    if (!mounted) return;
    if (_autoScanActive && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    setState(() {
      _scanningCheckpointId = null;
      _manualScanKind = null;
      _qrScanSubmitting = false;
      _autoScanActive = false;
      _autoScanKind = null;
    });
    _syncBackgroundAutoScanSuppression();
  }

  Future<void> _finishAutoScanSession({String? message}) async {
    await _stopQrLocationWatch();
    _autoScanStatusNotifier?.dispose();
    _autoScanStatusNotifier = null;
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    setState(() {
      _scanningCheckpointId = null;
      _manualScanKind = null;
      _qrScanSubmitting = false;
      _autoScanActive = false;
      _autoScanKind = null;
    });
    _syncBackgroundAutoScanSuppression();
    if (message != null && mounted) {
      context.showTopToast(message);
    }
  }

  void _resumeAutoScanAfterCheckpoint() {
    if (!mounted || !_autoScanActive) return;
    setState(() {
      _scanningCheckpointId = null;
      _qrScanSubmitting = false;
    });
    final l10n = AppLocalizations.of(context)!;
    final headline = _autoScanKind == _RoundAutoScanKind.bluetooth
        ? l10n.patrolRoundBluetoothWaiting
        : l10n.patrolRoundQrWaitingPosition;
    _autoScanStatusNotifier?.value = _QrScanProximityStatus(headline: headline);
  }

  String _gpsMessageFromKey(String? key, AppLocalizations l10n) {
    return switch (key) {
      'service' => l10n.patrolPointGpsServiceOff,
      'denied' => l10n.patrolPointGpsDenied,
      'error' => l10n.patrolPointGpsError,
      'unavailable' => l10n.patrolRoundQrGpsUnavailable,
      _ => l10n.patrolRoundQrGpsUnavailable,
    };
  }

  Future<void> _load({bool silent = false}) async {
    final isRefresh = silent || _active != null;
    setState(() {
      if (isRefresh) {
        _refreshing = true;
      } else {
        _loading = true;
      }
      _failure = null;
    });

    final r = await PatrolRoundService.instance.fetchMyActivePatrolRound();
    ActivePatrolRound? active = r.ok ? r.data : null;
    if (active != null) {
      active = await _mergeActiveRoundCheckPoints(
        active,
        fullRefresh: isRefresh,
      );
    }

    if (!mounted) return;
    if (r.ok) {
      setState(() {
        _applyLoadedActiveRound(active, fromRefresh: isRefresh);
        _loading = false;
        _refreshing = false;
        _failure = null;
      });
      await PatrolActiveRoundCache.save(active);
      unawaited(
        PatrolRealtimeTrackCoordinator.applyActiveRound(active?.round.id),
      );
    } else if (PatrolSession.isUnauthorized(r.failure)) {
      await PatrolSession.endSessionAndNavigateToLogin();
    } else {
      setState(() {
        _applyLoadedActiveRound(null, fromRefresh: isRefresh);
        _loading = false;
        _refreshing = false;
        _failure = r.failure;
      });
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageForFailure(r.failure!, l10n))),
      );
    }
  }

  bool _isCheckpointScanned(CheckPoint p) =>
      p.verified == true || _scannedCheckpointIds.contains(p.id);

  /// Sets [_active], syncs server `verified` into model + [_scannedCheckpointIds].
  void _applyLoadedActiveRound(
    ActivePatrolRound? active, {
    required bool fromRefresh,
  }) {
    _reloadToken++;
    if (active == null) {
      _active = null;
      _scannedCheckpointIds.clear();
      _notifyRouteMapRevision();
      return;
    }

    // On user refresh: trust only GET active `verified`, drop local scan overrides.
    final pendingLocal = fromRefresh
        ? <int>{}
        : _scannedCheckpointIds
            .where((id) => active.checkPoints.any((p) => p.id == id))
            .toSet();

    final scannedIds = <int>{};
    for (final p in active.checkPoints) {
      if (p.verified == true) scannedIds.add(p.id);
    }
    if (!fromRefresh) {
      for (final id in pendingLocal) {
        if (scannedIds.contains(id)) continue;
        final point = active.checkPoints.firstWhere((p) => p.id == id);
        if (point.verified != true) scannedIds.add(id);
      }
    }

    _scannedCheckpointIds
      ..clear()
      ..addAll(scannedIds);

    _active = ActivePatrolRound(
      schedule: active.schedule,
      round: active.round,
      checkPoints: [
        for (final p in active.checkPoints)
          scannedIds.contains(p.id)
              ? p.copyWith(verified: true)
              : fromRefresh
                  ? p.copyWith(verified: false)
                  : p,
      ],
    );
    _notifyRouteMapRevision();
  }

  void _markCheckpointVerified(int checkpointId) {
    final active = _active;
    if (active == null) return;
    setState(() {
      _scannedCheckpointIds.add(checkpointId);
      _active = ActivePatrolRound(
        schedule: active.schedule,
        round: active.round,
        checkPoints: [
          for (final p in active.checkPoints)
            p.id == checkpointId ? p.copyWith(verified: true) : p,
        ],
      );
    });
    _notifyRouteMapRevision();
  }

  /// Merges QR/metadata from site. When [fullRefresh], does not overwrite GET active fields.
  Future<ActivePatrolRound> _mergeActiveRoundCheckPoints(
    ActivePatrolRound active, {
    required bool fullRefresh,
  }) async {
    final needsSiteMerge = active.checkPoints.any((p) {
      final q = p.qrImage?.trim();
      final needsQr =
          q == null || q.isEmpty || !canPreviewApiImageSource(p.qrImage);
      final bt = p.bluetooth?.trim();
      final needsBluetooth = bt == null || bt.isEmpty;
      final nfc = p.nfc?.trim();
      final needsNfc = nfc == null || nfc.isEmpty;
      return needsQr || needsBluetooth || needsNfc;
    });
    if (!needsSiteMerge) return active;

    final site = await CheckPointService.instance.fetchMySiteCheckPoints();
    if (!site.ok || site.data == null) return active;

    final siteById = {
      for (final p in site.data!.checkPoints) p.id: p,
    };
    if (siteById.isEmpty) return active;

    final preferActive = fullRefresh;
    final mergedPoints = active.checkPoints.map((p) {
      final sitePoint = siteById[p.id];
      if (sitePoint == null) return p;

      var merged = p.mergeSiteMetadata(sitePoint, preferActive: preferActive);

      final siteQr = sitePoint.qrImage?.trim();
      if (siteQr != null && siteQr.isNotEmpty) {
        final current = merged.qrImage?.trim();
        if (current == null ||
            current.isEmpty ||
            !canPreviewApiImageSource(merged.qrImage)) {
          merged = merged.copyWith(qrImage: siteQr);
        }
      }

      return merged;
    }).toList();

    return ActivePatrolRound(
      schedule: active.schedule,
      round: active.round,
      checkPoints: mergedPoints,
    );
  }

  String _messageForFailure(ApiFailure f, AppLocalizations l10n) {
    return f.userMessage(
      configMissing: l10n.toastApiNotConfigured,
      network: l10n.toastNetworkErrorShort,
      unauthorized: l10n.patrolRoundUnauthorized,
      badResponse: l10n.patrolRoundLoadFailed,
      server: l10n.patrolRoundLoadFailed,
    );
  }

  String _messageForScanFailure(ApiFailure f, AppLocalizations l10n) {
    return f.userMessage(
      configMissing: l10n.toastApiNotConfigured,
      network: l10n.toastNetworkErrorShort,
      unauthorized: l10n.patrolRoundUnauthorized,
      badResponse: l10n.patrolRoundQrScanFailed,
      server: l10n.patrolRoundQrScanFailed,
    );
  }

  /// `null` = cancel; `[]` = skip photos; non-empty = image path list.
  Future<List<String>?> _confirmPhotoDialog({
    required AppLocalizations l10n,
    required CheckPoint point,
  }) {
    return showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _QrPhotoConfirmDialog(l10n: l10n, point: point),
    );
  }

  Future<void> _submitPatrolLogAfterProximity({
    required CheckPoint point,
    required int roundId,
    required DeviceLocationSample sample,
    List<String> photoPaths = const [],
    bool resumeAutoScan = false,
  }) async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    final submit = PatrolLogSubmit(
      roundId: roundId,
      checkpointId: point.id,
      siteId: point.siteId,
      scanTime: DateTime.now(),
      latitude: sample.latitude,
      longitude: sample.longitude,
      gpsAltitude: sample.gpsAltitude,
      baroAltitude: sample.baroAltitude,
      verified: true,
      photoPaths: photoPaths,
    );

    var ok = false;
    try {
      final logResult = await PatrolLogService.instance.createPatrolLog(submit);

      if (!mounted) return;

      if (logResult.ok) {
        ok = true;
        _markCheckpointVerified(point.id);
        if (!mounted) return;
        context.showTopToast(l10n.patrolRoundQrScanSuccess,
         duration: const Duration(milliseconds: 400));
      } else if (PatrolSession.isUnauthorized(logResult.failure)) {
        await PatrolSession.endSessionAndNavigateToLogin();
      } else {
        context.showTopToast(_messageForScanFailure(logResult.failure!, l10n),
         duration: const Duration(milliseconds: 400));
      }
    } catch (_) {
      if (!resumeAutoScan) {
        await _cancelQrScanWait();
      }
      if (!mounted) return;
      context.showTopToast(l10n.patrolRoundQrScanFailed,
       duration: const Duration(milliseconds: 400));
    } finally {
      if (mounted) {
        if (resumeAutoScan) {
          final remaining = _active != null
              ? switch (_autoScanKind) {
                  _RoundAutoScanKind.bluetooth =>
                    _eligibleBluetoothCheckPoints(_active!),
                  _RoundAutoScanKind.gps || null =>
                    _eligibleCheckPoints(_active!),
                }
              : <CheckPoint>[];
          if (ok && remaining.isEmpty) {
            await _finishAutoScanSession(
              message: l10n.patrolRoundAutoScanComplete,
            );
          } else {
            _resumeAutoScanAfterCheckpoint();
          }
        } else {
          setState(() {
            _scanningCheckpointId = null;
            _manualScanKind = null;
            _qrScanSubmitting = false;
            _autoScanActive = false;
            _autoScanKind = null;
          });
          _syncBackgroundAutoScanSuppression();
          await _stopQrLocationWatch();
        }
      }
    }
  }

  List<CheckPoint> _eligibleCheckPoints(ActivePatrolRound data) {
    final out = <CheckPoint>[];
    for (final p in data.checkPoints) {
      if (_isCheckpointScanned(p)) {
        continue;
      }
      if (!p.hasCoordinates) continue;
      out.add(p);
    }
    out.sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));
    return out;
  }

  CheckPoint? _autoScanCheckPoint(ActivePatrolRound data) {
    final eligible = _eligibleCheckPoints(data);
    return eligible.isEmpty ? null : eligible.first;
  }

  List<CheckPoint> _eligibleBluetoothCheckPoints(ActivePatrolRound data) {
    final out = <CheckPoint>[];
    for (final p in data.checkPoints) {
      if (_isCheckpointScanned(p)) continue;
      final bt = p.bluetooth?.trim();
      if (bt == null || bt.isEmpty) continue;
      out.add(p);
    }
    out.sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));
    return out;
  }

  CheckPoint? _matchBluetoothCheckPoint(
    List<CheckPoint> candidates, {
    required String identifier,
    String? deviceAddress,
  }) {
    for (final p in candidates) {
      final bt = p.bluetooth?.trim();
      if (bt == null || bt.isEmpty) continue;
      if (bluetoothIdentifiersMatch(bt, identifier)) return p;
      final addr = deviceAddress?.trim();
      if (addr != null &&
          addr.isNotEmpty &&
          bluetoothIdentifiersMatch(bt, addr)) {
        return p;
      }
    }
    return null;
  }

  CheckPoint? _findCheckPointByNfc(List<CheckPoint> points, String raw) {
    final payload = raw.trim();
    if (payload.isEmpty) return null;
    for (final p in points) {
      if (p.nfc?.trim() == payload && p.verified != true) return p;
    }
    return null;
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
      BluetoothReadFailure.failed => l10n.patrolRoundBluetoothScanFailed,
    };
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

  DeviceLocationSample _fallbackLocationSampleForCheckpoint(CheckPoint point) {
    final lat = point.latitude!;
    final lng = point.longitude!;
    return (
      position: Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: double.maxFinite,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      ),
      latitude: lat,
      longitude: lng,
      gpsAltitude: null,
      baroAltitude: null,
    );
  }

  CheckPointProximityEvaluation _evaluatePointProximity({
    required CheckPoint point,
    required DeviceLocationSample sample,
    required bool baroListening,
  }) {
    final pos = sample.position;
    final validateBaro = point.baroAltitude != null && baroListening;
    return evaluateCheckPointProximity(
      checkpoint: point,
      latitude: sample.latitude,
      longitude: sample.longitude,
      gpsAltitude: sample.gpsAltitude,
      baroAltitude: sample.baroAltitude,
      validateBaroAltitude: validateBaro,
      horizontalAccuracyM: netIncrementalAccuracyM(
        pos.accuracy,
        point.accuracy,
      ),
      gpsAltitudeAccuracyM: netIncrementalAccuracyM(
        pos.altitudeAccuracy,
        point.altitudeAccuracy,
      ),
    );
  }

  _CheckPointProximityScan _scanCheckPointsProximity(
    List<CheckPoint> points,
    DeviceLocationSample sample,
    bool baroListening, {
    CheckPointMatchOrder matchOrder = CheckPointMatchOrder.sequenceOrder,
  }) {
    if (points.isEmpty) return const _CheckPointProximityScan();

    if (matchOrder == CheckPointMatchOrder.sequenceOrder) {
      final evaluation = _evaluatePointProximity(
        point: points.first,
        sample: sample,
        baroListening: baroListening,
      );
      if (evaluation.result.ok) {
        return _CheckPointProximityScan(matched: points.first);
      }
      return _CheckPointProximityScan(feedback: evaluation);
    }

    CheckPoint? bestMatch;
    double? bestMatchDistanceM;
    CheckPointProximityEvaluation? nearestFeedback;
    double? nearestFeedbackDistanceM;

    for (final point in points) {
      final evaluation = _evaluatePointProximity(
        point: point,
        sample: sample,
        baroListening: baroListening,
      );
      if (evaluation.result.ok) {
        final distanceM = evaluation.snapshot?.horizontalM;
        if (distanceM == null) {
          bestMatch ??= point;
          continue;
        }
        if (bestMatchDistanceM == null || distanceM < bestMatchDistanceM) {
          bestMatchDistanceM = distanceM;
          bestMatch = point;
        }
      } else {
        final distanceM = evaluation.result.distanceM;
        if (distanceM == null) continue;
        if (nearestFeedbackDistanceM == null ||
            distanceM < nearestFeedbackDistanceM) {
          nearestFeedbackDistanceM = distanceM;
          nearestFeedback = evaluation;
        }
      }
    }

    if (bestMatch != null) {
      return _CheckPointProximityScan(matched: bestMatch);
    }
    return _CheckPointProximityScan(feedback: nearestFeedback);
  }

  Future<void> _completeAutoScanAfterMatch({
    required CheckPoint point,
    required int roundId,
    required DeviceLocationSample sample,
  }) async {
    if (!mounted) {
      await _cancelQrScanWait();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final photoPaths = await _confirmPhotoDialog(l10n: l10n, point: point);
    if (!mounted) {
      await _cancelQrScanWait();
      return;
    }
    if (photoPaths == null) {
      await _cancelQrScanWait();
      return;
    }

    if (!mounted) {
      _resumeAutoScanAfterCheckpoint();
      return;
    }
    setState(() => _scanningCheckpointId = point.id);
    _syncBackgroundAutoScanSuppression();

    await _submitPatrolLogAfterProximity(
      point: point,
      roundId: roundId,
      sample: sample,
      photoPaths: photoPaths,
      resumeAutoScan: true,
    );
  }

  /// Normalizes QR payload and matches `CheckPoint.qrCode` on the current route.
  CheckPoint? _findCheckPointByQrCode(List<CheckPoint> points, String raw) {
    var payload = raw.trim();
    if (payload.isEmpty) return null;
    for (final p in points) {
      if (p.qrCode?.trim() == payload) return p;
    }
    return null;
  }

  Future<void> _onRoundNfcScan(ActivePatrolRound data) async {
    if (_roundActionBusy) return;

    final l10n = AppLocalizations.of(context)!;
    if (!isNfcScanSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.patrolPointNfcUnavailable)),
      );
      return;
    }

    setState(() => _manualScanKind = _RoundManualScanKind.nfc);
    _syncBackgroundAutoScanSuppression();
    try {
      final result = await readNfcTagIdentifier(
        iosAlertMessage: l10n.patrolPointNfcScanning,
      );
      if (!mounted || !result.ok || result.identifier == null) {
        if (mounted && result.failure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_nfcScanFailureMessage(l10n, result.failure!)),
            ),
          );
        }
        return;
      }

      final point = _findCheckPointByNfc(data.checkPoints, result.identifier!);
      if (point == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.patrolRoundNfcNotFound)),
        );
        return;
      }
      if (_isCheckpointScanned(point)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.patrolRoundNfcAlreadyScanned)),
        );
        return;
      }

      await _onQrScanCheckpoint(point, data.round.id);
    } finally {
      if (mounted && _scanningCheckpointId == null) {
        setState(() => _manualScanKind = null);
        _syncBackgroundAutoScanSuppression();
      }
    }
  }

  Future<void> _onRoundQrScan(ActivePatrolRound data) async {
    if (_roundActionBusy) return;

    final l10n = AppLocalizations.of(context)!;
    setState(() => _manualScanKind = _RoundManualScanKind.qr);
    _syncBackgroundAutoScanSuppression();
    try {
      final payload = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => QrCodeScannerPage(l10n: l10n),
        ),
      );
      if (!mounted || payload == null || payload.trim().isEmpty) return;

      final point = _findCheckPointByQrCode(data.checkPoints, payload);
      if (point == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.patrolRoundQrNotFound)),
        );
        return;
      }
      if (_isCheckpointScanned(point)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.patrolRoundQrAlreadyScanned)),
        );
        return;
      }

      await _onQrScanCheckpoint(point, data.round.id);
    } finally {
      if (mounted && _scanningCheckpointId == null) {
        setState(() => _manualScanKind = null);
        _syncBackgroundAutoScanSuppression();
      }
    }
  }

  bool get _roundActionBusy =>
      _refreshing ||
      _scanningCheckpointId != null ||
      _autoScanActive ||
      _manualScanKind != null;

  /// After QR match: photo popup, one-shot GPS read, submit patrol log.
  Future<void> _onQrScanCheckpoint(CheckPoint point, int roundId) async {
    if (_scanningCheckpointId != null || _autoScanActive) return;
    final l10n = AppLocalizations.of(context)!;

    final photoPaths = await _confirmPhotoDialog(l10n: l10n, point: point);
    if (!mounted || photoPaths == null) {
      setState(() => _manualScanKind = null);
      return;
    }

    setState(() {
      _scanningCheckpointId = point.id;
      _qrScanSubmitting = true;
    });
    _syncBackgroundAutoScanSuppression();
    /*
    final needsBaro = point.baroAltitude != null;
    final gps = await readDeviceGpsOnce(
      timeout: const Duration(seconds: 1),
      enableBarometer: needsBaro,
      targetAccuracyM: kCheckpointGpsTargetAccuracyM,
    );

    if (!mounted) return;

    if (gps.position == null) {
      context.showTopToast(
        _gpsMessageFromKey(gps.messageKey, l10n),
        backgroundColor: const Color(0xFFF59E0B),
        duration: const Duration(milliseconds: 800),
      );
    }

    final pos = gps.position;
    final DeviceLocationSample sample;
    if (pos != null) {
      final gpsAlt = pos.altitude.isFinite ? pos.altitude : null;
      sample = (
        position: pos,
        latitude: pos.latitude,
        longitude: pos.longitude,
        gpsAltitude: gpsAlt,
        baroAltitude: gps.barometricAltitude,
      );
    } else {
      sample = _fallbackLocationSampleForCheckpoint(point);
    }*/
    final DeviceLocationSample sample = _fallbackLocationSampleForCheckpoint(point);
    await _submitPatrolLogAfterProximity(
      point: point,
      roundId: roundId,
      sample: sample,
      photoPaths: photoPaths,
    );
  }

  Future<void> _onAutoScanGps(ActivePatrolRound data) async {
    if (_roundActionBusy) return;

    final l10n = AppLocalizations.of(context)!;
    final eligible = _eligibleCheckPoints(data);
    if (eligible.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.patrolRoundAutoScanNone)),
      );
      return;
    }

    final roundId = data.round.id;

    setState(() {
      _autoScanActive = true;
      _autoScanKind = _RoundAutoScanKind.gps;
      _qrScanSubmitting = false;
    });
    _syncBackgroundAutoScanSuppression();

    final statusNotifier = ValueNotifier<_QrScanProximityStatus>(
      _QrScanProximityStatus(headline: l10n.patrolRoundQrWaitingPosition),
    );
    _autoScanStatusNotifier = statusNotifier;

    if (!mounted) return;

    final needsBaroValidation = eligible.any((p) => p.baroAltitude != null);
    final watch = await DeviceLocationWatch.create();
    if (!mounted) return;
    _qrLocationWatch = watch;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              16 + MediaQuery.paddingOf(sheetContext).bottom,
            ),
            child: Material(
              color: PatrolShellColors.surface,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ValueListenableBuilder<_QrScanProximityStatus>(
                      valueListenable: statusNotifier,
                      builder: (_, status, _) {
                        final bodyStyle = Theme.of(sheetContext)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.45,
                            );
                        final detail = status.snapshot;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              status.headline,
                              textAlign: TextAlign.center,
                              style: bodyStyle,
                            ),
                            if (detail != null) ...[
                              const SizedBox(height: 14),
                              _QrProximityDetailPanel(
                                l10n: l10n,
                                snapshot: detail,
                                baroPending: status.baroPending,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF34D399),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(_cancelQrScanWait());
                      },
                      child: Text(l10n.patrolRoundCancel),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ).whenComplete(() {
        if (_autoScanStatusNotifier == statusNotifier) {
          _autoScanStatusNotifier = null;
          statusNotifier.dispose();
        }
        if (_autoScanActive && !_qrScanSubmitting) {
          unawaited(_cancelQrScanWait());
        }
      }),
    );

    final gpsError = await watch.start(
      enableBarometer: needsBaroValidation,
      onSample: (sample) {
        if (!mounted || !_autoScanActive || _qrScanSubmitting) {
          return false;
        }

        final active = _active;
        if (active == null) return false;

        final pending = _eligibleCheckPoints(active);
        if (pending.isEmpty) {
          unawaited(
            _finishAutoScanSession(
              message: l10n.patrolRoundAutoScanComplete,
            ),
          );
          return false;
        }

        final validateBaro = needsBaroValidation && watch.barometerListening;
        const matchOrder = CheckPointMatchOrder.sequenceOrder;
        final scan = _scanCheckPointsProximity(
          pending,
          sample,
          validateBaro,
          matchOrder: matchOrder,
        );

        if (scan.matched == null) {
          final feedback = scan.feedback;
          if (feedback != null) {
            statusNotifier.value = _qrScanProximityStatus(
              l10n: l10n,
              proximity: feedback.result,
              snapshot: feedback.snapshot,
            );
          }
          return false;
        }

        _qrScanSubmitting = true;
        statusNotifier.value = _QrScanProximityStatus(
          headline: l10n.patrolRoundQrPositionOkSaving,
        );
        unawaited(
          _completeAutoScanAfterMatch(
            point: scan.matched!,
            roundId: roundId,
            sample: sample,
          ),
        );
        return false;
      },
    );

    if (!mounted) return;

    if (gpsError != null) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      await _cancelQrScanWait();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_gpsMessageFromKey(gpsError, l10n))),
      );
    }
  }

  Future<void> _completeBluetoothAutoScanAfterMatch({
    required CheckPoint point,
    required int roundId,
  }) async {
    if (!mounted) {
      await _cancelQrScanWait();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final photoPaths = await _confirmPhotoDialog(l10n: l10n, point: point);
    if (!mounted) {
      await _cancelQrScanWait();
      return;
    }
    if (photoPaths == null) {
      await _cancelQrScanWait();
      return;
    }

    if (!mounted) {
      _resumeAutoScanAfterCheckpoint();
      return;
    }
    setState(() => _scanningCheckpointId = point.id);

    final needsBaro = point.baroAltitude != null;
    final gps = await readDeviceGpsOnce(
      timeout: const Duration(seconds: 2),
      enableBarometer: needsBaro,
      targetAccuracyM: kCheckpointGpsTargetAccuracyM,
    );

    if (!mounted) return;

    if (gps.position == null) {
      context.showTopToast(
        _gpsMessageFromKey(gps.messageKey, l10n),
        backgroundColor: const Color(0xFFF59E0B),
        duration: const Duration(milliseconds: 800),
      );
    }

    final pos = gps.position;
    final DeviceLocationSample sample;
    if (pos != null) {
      final gpsAlt = pos.altitude.isFinite ? pos.altitude : null;
      sample = (
        position: pos,
        latitude: pos.latitude,
        longitude: pos.longitude,
        gpsAltitude: gpsAlt,
        baroAltitude: gps.barometricAltitude,
      );
    } else {
      sample = _fallbackLocationSampleForCheckpoint(point);
    }

    await _submitPatrolLogAfterProximity(
      point: point,
      roundId: roundId,
      sample: sample,
      photoPaths: photoPaths,
      resumeAutoScan: true,
    );
  }

  Future<void> _runBluetoothAutoScanLoop({
    required int roundId,
    required ValueNotifier<_QrScanProximityStatus> statusNotifier,
  }) async {
    final l10n = AppLocalizations.of(context)!;

    while (mounted && _autoScanActive && _autoScanKind == _RoundAutoScanKind.bluetooth) {
      if (_qrScanSubmitting) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        continue;
      }

      final active = _active;
      if (active == null) break;

      final pending = _eligibleBluetoothCheckPoints(active);
      if (pending.isEmpty) {
        unawaited(
          _finishAutoScanSession(message: l10n.patrolRoundAutoScanComplete),
        );
        return;
      }

      final remoteIds = pending
          .map((p) => p.bluetooth!.trim())
          .where((id) => id.isNotEmpty)
          .toList();

      statusNotifier.value = _QrScanProximityStatus(
        headline: l10n.patrolRoundBluetoothWaiting,
      );

      if (!isBluetoothScanSupported) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.patrolPointBluetoothUnavailable)),
        );
        await _cancelQrScanWait();
        return;
      }

      final result = await readBluetoothBeaconIdentifier(
        remoteIds: remoteIds,
        stableHits: 1,
        successRssi: -85,
      );

      if (!mounted || !_autoScanActive || _autoScanKind != _RoundAutoScanKind.bluetooth) {
        return;
      }

      if (!result.ok) {
        if (result.failure != null) {
          statusNotifier.value = _QrScanProximityStatus(
            headline: _bluetoothScanFailureMessage(l10n, result.failure!),
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 400));
        continue;
      }

      final matched = _matchBluetoothCheckPoint(
        pending,
        identifier: result.identifier!,
        deviceAddress: result.beacon?.deviceAddress,
      );
      if (matched == null) {
        statusNotifier.value = _QrScanProximityStatus(
          headline: l10n.patrolRoundBluetoothScanFailed,
        );
        await Future<void>.delayed(const Duration(milliseconds: 400));
        continue;
      }

      setState(() => _qrScanSubmitting = true);
      statusNotifier.value = _QrScanProximityStatus(
        headline: l10n.patrolRoundQrPositionOkSaving,
      );
      await _completeBluetoothAutoScanAfterMatch(
        point: matched,
        roundId: roundId,
      );
    }
  }

  Future<void> _onAutoScanBluetooth(ActivePatrolRound data) async {
    if (_roundActionBusy) return;

    final l10n = AppLocalizations.of(context)!;
    final eligible = _eligibleBluetoothCheckPoints(data);
    if (eligible.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.patrolRoundAutoScanBluetoothNone)),
      );
      return;
    }

    final roundId = data.round.id;

    setState(() {
      _autoScanActive = true;
      _autoScanKind = _RoundAutoScanKind.bluetooth;
      _qrScanSubmitting = false;
    });
    _syncBackgroundAutoScanSuppression();

    final statusNotifier = ValueNotifier<_QrScanProximityStatus>(
      _QrScanProximityStatus(headline: l10n.patrolRoundBluetoothWaiting),
    );
    _autoScanStatusNotifier = statusNotifier;

    if (!mounted) return;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              16 + MediaQuery.paddingOf(sheetContext).bottom,
            ),
            child: Material(
              color: PatrolShellColors.surface,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ValueListenableBuilder<_QrScanProximityStatus>(
                      valueListenable: statusNotifier,
                      builder: (_, status, _) {
                        final bodyStyle = Theme.of(sheetContext)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.45,
                            );
                        return Text(
                          status.headline,
                          textAlign: TextAlign.center,
                          style: bodyStyle,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF34D399),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(_cancelQrScanWait());
                      },
                      child: Text(l10n.patrolRoundCancel),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ).whenComplete(() {
        if (_autoScanStatusNotifier == statusNotifier) {
          _autoScanStatusNotifier = null;
          statusNotifier.dispose();
        }
        if (_autoScanActive &&
            _autoScanKind == _RoundAutoScanKind.bluetooth &&
            !_qrScanSubmitting) {
          unawaited(_cancelQrScanWait());
        }
      }),
    );

    unawaited(
      _runBluetoothAutoScanLoop(
        roundId: roundId,
        statusNotifier: statusNotifier,
      ),
    );
  }

  Future<void> _openRouteMapOverlay() async {
    final data = _active;
    if (data == null || !mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: AppLocalizations.of(context)!.patrolRoundMap,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        void close() {
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        }

        return _RouteMapOverlay(
          routeRevision: _routeMapRevision,
          checkPointsProvider: () => _active?.checkPoints ?? const [],
          isScanned: _isCheckpointScanned,
          onDismiss: close,
        );
      },
    );
  }

  Future<void> _openScheduleOverlay() async {
    final theme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (sheetContext) {
        final pad = MediaQuery.paddingOf(sheetContext);
        final h = MediaQuery.sizeOf(sheetContext).height;

        void closeSheet() {
          if (sheetContext.mounted) {
            Navigator.of(sheetContext).pop();
          }
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + pad.bottom),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: StatefulBuilder(
              builder: (modalContext, setSheetState) {
                const handleReserve = 40.0;
                final maxBodyHeight =
                    (h * 0.88 - handleReserve).clamp(120.0, h);
                final scrollPhysics = AlwaysScrollableScrollPhysics(
                  parent: Theme.of(sheetContext).platform ==
                          TargetPlatform.iOS
                      ? const BouncingScrollPhysics()
                      : const ClampingScrollPhysics(),
                );

                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: h * 0.88),
                  child: Material(
                    color: PatrolShellColors.surface,
                    elevation: 12,
                    shadowColor: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SheetVerticalDismissHandle(onDismiss: closeSheet),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: maxBodyHeight,
                          ),
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (ScrollNotification n) {
                              if (n is! OverscrollNotification) {
                                return false;
                              }
                              if (n.overscroll.abs() >= 20) {
                                closeSheet();
                                return true;
                              }
                              return false;
                            },
                            child: ListView(
                              shrinkWrap: true,
                              physics: scrollPhysics,
                              padding: const EdgeInsets.all(4),
                              children: [
                                _ScheduleCard(
                                  theme: theme,
                                  l10n: AppLocalizations.of(modalContext)!,
                                  loading: _loading,
                                  failure: _failure,
                                  data: _active,
                                  failureMessage: _failure != null
                                      ? _messageForFailure(
                                          _failure!,
                                          AppLocalizations.of(modalContext)!,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return l10n.patrolRoundStatusPending;
      case 'IN_PROGRESS':
      case 'INPROGRESS':
        return l10n.patrolRoundStatusInProgress;
      case 'COMPLETED':
      case 'DONE':
        return l10n.patrolRoundStatusCompleted;
      case 'CANCELLED':
      case 'CANCELED':
        return l10n.patrolRoundStatusCancelled;
      default:
        return status.isEmpty ? l10n.patrolRoundStatusOther : status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return const Color(0xFFFBBF24);
      case 'IN_PROGRESS':
      case 'INPROGRESS':
        return const Color(0xFF34D399);
      case 'COMPLETED':
      case 'DONE':
        return PatrolShellColors.accent;
      case 'CANCELLED':
      case 'CANCELED':
        return Colors.white54;
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);
    final l10n = AppLocalizations.of(context)!;
    final data = _active;

    final subtitle = _loading
        ? l10n.patrolRoundLoading
        : data == null
            ? l10n.patrolRoundSubtitle
            : l10n.patrolRoundSubtitleActive(
                data.schedule.name,
                _statusLabel(data.round.status, l10n),
              );

    return PatrolFeatureScaffold(
      useOuterScaffold: !widget.embedded,
      locale: widget.locale,
      title: widget.embedded ? null : l10n.patrolRoundTitle,
      heroIcon: Icons.shield_moon_rounded,
      heroColor: const Color(0xFF34D399),
      subtitle: data == null ? l10n.patrolRoundSubtitle : null,
      subtitleSlot: data != null || _loading
          ? Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
                letterSpacing: 0.3,
                height: 1.2,
              ),
            )
          : null,
      heroRowTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.map_rounded),
            color: Colors.white.withValues(alpha: 0.92),
            tooltip: l10n.patrolRoundMap,
            onPressed: data != null && !_loading && _failure == null
                ? () => unawaited(_openRouteMapOverlay())
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            color: Colors.white.withValues(alpha: 0.92),
            tooltip: l10n.patrolRoundScheduleHeading,
            onPressed: _openScheduleOverlay,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading) ...[
            const SizedBox(height: 28),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF34D399),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.patrolRoundLoading,
                    textAlign: TextAlign.center,
                    style: theme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_failure != null) ...[
            const SizedBox(height: 16),
            Text(
              _messageForFailure(_failure!, l10n),
              style: theme.bodyMedium?.copyWith(
                color: Colors.orangeAccent.withValues(alpha: 0.9),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(l10n.patrolRoundReload),
              ),
            ),
          ] else if (data == null) ...[
            const SizedBox(height: 16),
            Text(
              l10n.patrolRoundEmpty,
              style: theme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
                height: 1.5,
              ),
            ),
          ],
          if (_failure == null && data != null) ...[
            const SizedBox(height: 12),
            _RoundCard(
              key: ValueKey(
                'round-${data.round.id}-${data.round.status}-'
                '${data.round.expectedStartTime}-${data.round.expectedEndTime}-'
                '${data.round.assignedName}-$_reloadToken',
              ),
              theme: theme,
              l10n: l10n,
              round: data.round,
              statusLabel: _statusLabel(data.round.status, l10n),
              statusColor: _statusColor(data.round.status),
              loading: _refreshing,
              onReload: _load,
              qrScanBusy: _manualScanKind == _RoundManualScanKind.qr,
              onQrScan: _autoScanCheckPoint(data) != null ? () => unawaited(_onRoundQrScan(data)) : null,
              nfcScanBusy: _manualScanKind == _RoundManualScanKind.nfc,
              onNfcScan: _autoScanCheckPoint(data) != null && isNfcScanSupported
                  ? () => unawaited(_onRoundNfcScan(data))
                  : null,
              autoScanBusy:
                  _autoScanActive && _autoScanKind == _RoundAutoScanKind.gps,
              onAutoScan: _autoScanCheckPoint(data) != null
                  ? () => unawaited(_onAutoScanGps(data))
                  : null,
              autoScanBluetoothBusy: _autoScanActive &&
                  _autoScanKind == _RoundAutoScanKind.bluetooth,
              onAutoScanBluetooth: _autoScanCheckPoint(data) != null  && isBluetoothScanSupported
                  ? () => unawaited(_onAutoScanBluetooth(data))
                  : null,
            ),
          ],
          if (!_loading && _failure == null && data != null) ...[
            const SizedBox(height: 20),
            Text(
              l10n.patrolRoundRouteHeading,
              style: theme.titleSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (data.checkPoints.isEmpty)
              Text(
                l10n.patrolPointEmpty,
                style: theme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.65),
                  height: 1.5,
                ),
              )
            else
              ...data.checkPoints.map(
                (p) => Padding(
                  key: ValueKey(
                    'route-${p.id}-${p.verified}-${p.updatedDate}-'
                    '${p.latitude}-${p.longitude}-${p.name}-$_reloadToken',
                  ),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RoutePointCard(
                    theme: theme,
                    l10n: l10n,
                    point: p,
                    scanned: _isCheckpointScanned(p),
                    qrBusy: _scanningCheckpointId == p.id,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

