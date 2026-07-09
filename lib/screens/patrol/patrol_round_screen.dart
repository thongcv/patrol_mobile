import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../http/api_failure.dart';
import '../../l10n/app_localizations.dart';
import '../../models/active_patrol_round.dart';
import '../../models/check_point.dart';
import '../../models/patrol_round.dart';
import '../../models/patrol_tracking_config.dart';
import '../../services/account_session_store.dart';
import '../../services/patrol_foreground_gps_scan_session.dart';
import '../../services/patrol_log_service.dart';
import '../../services/patrol_round_service.dart';
import '../../services/patrol_tracking_config_store.dart';
import '../../background/patrol_background_service.dart';
import '../../services/patrol_background_auto_scan_ui_state.dart';
import '../../services/patrol_active_round_cache.dart';
import '../../services/patrol_active_round_coordinator.dart';
import '../../services/patrol_active_round_sync.dart';
import '../../services/patrol_realtime_track_coordinator.dart';
import '../../services/patrol_realtime_track_service.dart';
import '../../utils/beacon/bluetooth_beacon_reader.dart';
import '../../utils/check_point_proximity.dart';
import '../../utils/device_location.dart';
import '../../utils/map_pin_widget.dart';
import '../../utils/patrol_map_overlays.dart';
import '../../utils/patrol_proximity_navigation_speech.dart';
import '../../utils/nfc/nfc_tag_reader.dart';
import '../../widgets/patrol_osm_map.dart';
import '../../utils/patrol_datetime_format.dart';
import '../../utils/patrol_round_status.dart';
import '../../utils/top_toast.dart';
import '../../widgets/qr_code_scanner_page.dart';
import 'patrol_shell.dart';
part 'round/patrol_round_types.dart';
part 'round/patrol_round_sheet_handle.dart';
part 'round/patrol_round_schedule_card.dart';
part 'round/patrol_round_round_card.dart';
part 'round/patrol_round_qr_photo_dialog.dart';
part 'round/patrol_round_qr_proximity.dart';
part 'round/patrol_round_overdue_note_dialog.dart';
part 'round/patrol_round_route_point_card.dart';
part 'round/patrol_round_route_map_overlay.dart';
part 'round/patrol_round_common_widgets.dart';
part 'round/patrol_round_auto_scan_sheet.dart';
part 'round/patrol_round_schedule_overlay.dart';

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
  // --- Active round ---
  ActivePatrolRound? _active;
  bool _loading = true;
  bool _refreshing = false;
  ApiFailure? _failure;
  final Set<int> _scannedCheckpointIds = {};
  /// Incremented after each successful GET active — forces list / QR preview rebuild.
  int _reloadToken = 0;
  /// Notifies route map overlay to refresh checkpoint state (scan / reload active).
  final ValueNotifier<_RouteMapUpdate> _routeMapRevision =
      ValueNotifier(const _RouteMapUpdate(seq: 0));
  StreamSubscription<ActivePatrolRound?>? _activeRoundSocketSub;
  StreamSubscription<CheckPoint>? _checkpointVerifiedSub;
  Timer? _overdueUiRefreshTimer;
  /// One-shot at [PatrolRound.expectedEndTime] to reload when overdue chip appears.
  Timer? _overdueChipReloadTimer;
  /// Avoid duplicate silent reload after overdue chip is shown.
  bool _overdueChipReloadDone = false;
  late final VoidCallback _fgsAutoScanUiListener;
  /// Guards socket-driven policy while [_load] owns the round bootstrap sequence.
  var _localRoundLoadSeq = 0;
  /// STOMP round received while [_load] runs — applied after GET completes.
  ActivePatrolRound? _pendingExternalRound;

  // --- Scan flows (QR → NFC → auto GPS → auto Bluetooth) ---
  int? _scanningCheckpointId;
  _RoundManualScanKind? _manualScanKind;
  bool _qrScanSubmitting = false;
  int? _overdueNoteSubmittingId;
  bool _autoScanActive = false;
  _RoundAutoScanKind? _autoScanKind;
  PatrolForegroundGpsScanSession? _qrLocationWatch;
  BluetoothBeaconScanSession? _bluetoothScanWatch;
  ValueNotifier<_QrScanProximityStatus>? _autoScanStatusNotifier;
  /// `true` when user paused FGS scan (header radar or any of the four scan buttons).
  bool _preferManualScan = false;
  /// Login / STOMP tracking config — header radar hidden when false.
  bool _backgroundAutoScanConfigured = false;
  int _overdueGraceMinutes = PatrolTrackingConfig.defaultOverdueGraceMinutes;
  /// Clears in-memory scan UI — embedded / re-open must not reuse a prior session.
  void _resetStaleForegroundScanUiState() {
    _preferManualScan = false;
    _scanningCheckpointId = null;
    _manualScanKind = null;
    _qrScanSubmitting = false;
    _overdueNoteSubmittingId = null;
    _autoScanActive = false;
    _autoScanKind = null;
    _autoScanStatusNotifier?.dispose();
    _autoScanStatusNotifier = null;
    unawaited(_stopQrLocationWatch());
  }

  Future<void> _initRoundScreenTracking() async {
    // Release stale manual-scan suppression before bootstrap touches FGS prefs.
    await PatrolRealtimeTrackCoordinator.setRoundScanBusy(false);
    await _syncFgsAutoScanRunningFromPrefs();
    await _bootstrapRoundScreen();
  }

  Future<void> _bootstrapRoundScreen() async {
    _resetStaleForegroundScanUiState();
    await _load();
    if (!mounted) return;
    PatrolActiveRoundCoordinator.noteActiveRoundFromUiLoad(_active);
  }

  @override
  void initState() {
    super.initState();
    _fgsAutoScanUiListener = () {
      if (!mounted) return;
      setState(() {});
    };
    PatrolBackgroundAutoScanUiState.running
        .addListener(_fgsAutoScanUiListener);
    PatrolBackgroundAutoScanUiState.awaitingNextRoundConfirm
        .addListener(_fgsAutoScanUiListener);
    unawaited(_initRoundScreenTracking());
    _checkpointVerifiedSub =
        PatrolActiveRoundCoordinator.checkpointVerifiedChanges.listen(
      (point) {
        if (!mounted) return;
        setState(() {
          _applyFgsCheckpointVerified(point);
          _loading = false;
          _refreshing = false;
          _failure = null;
        });
        final active = _active;
        if (active != null && !_hasUnscannedCheckPoints(active)) {
          unawaited(_load(silent: true));
        }
        unawaited(_syncAwaitingNextRoundConfirmFromPrefs());
      },
    );
    _activeRoundSocketSub =
        PatrolActiveRoundCoordinator.activeRoundChanges.listen((round) {
      if (!mounted) return;
      if (round != null) {
        unawaited(_onExternalActiveRoundFromCoordinator(round));
        return;
      }
      _pendingExternalRound = null;
      unawaited(_load(silent: true));
    });
  }

  @override
  void dispose() {
    _overdueUiRefreshTimer?.cancel();
    _overdueChipReloadTimer?.cancel();
    PatrolBackgroundAutoScanUiState.running
        .removeListener(_fgsAutoScanUiListener);
    PatrolBackgroundAutoScanUiState.awaitingNextRoundConfirm
        .removeListener(_fgsAutoScanUiListener);
    TopToast.hide();
    _activeRoundSocketSub?.cancel();
    _checkpointVerifiedSub?.cancel();
    _routeMapRevision.dispose();
    unawaited(_stopQrLocationWatch());
    // Always release — busy only applies while this screen suppresses FGS.
    unawaited(PatrolRealtimeTrackCoordinator.setRoundScanBusy(false));
    super.dispose();
  }

  // --- Active round: load & checkpoint state ---

  void _notifyRouteMapRevision({Iterable<int>? checkpointIds}) {
    final prev = _routeMapRevision.value;
    _routeMapRevision.value = _RouteMapUpdate(
      seq: prev.seq + 1,
      checkpointIds: checkpointIds == null
          ? const {}
          : checkpointIds.map((id) => id).toSet(),
    );
  }
  Future<void> _load({bool silent = false}) async {
    final loadSeq = ++_localRoundLoadSeq;
    final showRefreshUi = silent && _active != null;
    setState(() {
      if (showRefreshUi) {
        _refreshing = true;
      } else if (!silent) {
        _loading = true;
      }
      _failure = null;
    });

    final r = await PatrolRoundService.instance.fetchMyActivePatrolRound();
    ActivePatrolRound? active = r.ok ? r.data : null;
    final bgAutoScanRunning =
        await PatrolActiveRoundCache.isBackgroundAutoScanRunning();
    if (active != null && bgAutoScanRunning) {
      active = await PatrolActiveRoundCache.mergeBackgroundVerified(active);
    }

    if (!mounted) return;
    if (r.ok) {
      await PatrolActiveRoundCache.save(
        active,
        preserveLocalVerified: bgAutoScanRunning,
      );
      if (await PatrolActiveRoundCache.ensureAwaitingNextRoundIfRoundChanged(
        active?.round.id,
        roundStatus: active?.round.status,
      )) {
        unawaited(PatrolBackgroundService.offerNextRoundAutoScanIfAwaiting());
      }
      final awaiting =
          await PatrolActiveRoundCache.isAwaitingNextRoundAutoScanConfirm();
      if (!mounted) return;
      PatrolBackgroundAutoScanUiState.setAwaitingNextRoundConfirm(awaiting);
      var activeToShow = active;
      var externalRefresh = silent;
      if (loadSeq == _localRoundLoadSeq && _pendingExternalRound != null) {
        activeToShow = _pendingExternalRound;
        _pendingExternalRound = null;
        externalRefresh = true;
      }
      setState(() {
        _applyLoadedActiveRound(activeToShow, fromRefresh: externalRefresh);
        _loading = false;
        _refreshing = false;
        _failure = null;
      });
      if (loadSeq == _localRoundLoadSeq) {
        await _applyFgsScanPolicyAfterRoundDataLoaded();
      }
    } else {
      setState(() {
        _applyLoadedActiveRound(null, fromRefresh: false);
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
  /// STOMP / coordinator push — trust server snapshot; defer if [_load] in flight.
  Future<void> _onExternalActiveRoundFromCoordinator(
    ActivePatrolRound round,
  ) async {
    final merged =
        await PatrolActiveRoundCache.mergeBackgroundVerifiedIfRunning(round);
    final bgAutoScanRunning =
        await PatrolActiveRoundCache.isBackgroundAutoScanRunning();
    await PatrolActiveRoundCache.save(
      merged,
      preserveLocalVerified: bgAutoScanRunning,
    );
    if (await PatrolActiveRoundCache.ensureAwaitingNextRoundIfRoundChanged(
      merged.round.id,
      roundStatus: merged.round.status,
    )) {
      unawaited(PatrolBackgroundService.offerNextRoundAutoScanIfAwaiting());
    }
    if (_localRoundLoadSeq > 0 && (_loading || _refreshing)) {
      _pendingExternalRound = merged;
      return;
    }
    await _applyExternalActiveRoundToUi(merged);
  }

  Future<void> _applyExternalActiveRoundToUi(ActivePatrolRound merged) async {
    final awaiting =
        await PatrolActiveRoundCache.isAwaitingNextRoundAutoScanConfirm();
    if (!mounted) return;
    PatrolBackgroundAutoScanUiState.setAwaitingNextRoundConfirm(awaiting);
    setState(() {
      _applyLoadedActiveRound(merged, fromRefresh: true);
      _loading = false;
      _refreshing = false;
      _failure = null;
    });
    await _syncRadarHeaderMirrorFromPrefs();
    if (!mounted) return;
    if (_localRoundLoadSeq == 0) {
      await _syncFgsScanPolicyFromExternalRoundUpdate();
    }
  }

  bool _isCheckpointScanned(CheckPoint p) =>
      p.verified == true || _scannedCheckpointIds.contains(p.id);

  bool _hasUnscannedCheckPoints(ActivePatrolRound data) {
    for (final p in data.checkPoints) {
      if (!_isCheckpointScanned(p)) return true;
    }
    return false;
  }

  bool _showHeaderRadar(ActivePatrolRound data) =>
      PatrolRoundStatus.isPendingOrInProgress(data.round.status) &&
      _hasUnscannedCheckPoints(data);

  /// FGS auto-scan — [point] đã verify; cache đã ghi trên FGS isolate.
  void _applyFgsCheckpointVerified(CheckPoint point) {
    _applyCheckpointVerified(point, persistCache: false);
  }
  void _applyCheckpointVerified(CheckPoint point, {required bool persistCache}) {
    final active = _active;
    if (active == null) return;
    
    _scannedCheckpointIds.add(point.id);
    _active = ActivePatrolRound(
      schedule: active.schedule,
      round: active.round,
      checkPoints: [
        for (final p in active.checkPoints)
          p.id == point.id ? p.copyWith(verified: true) : p,
      ],
    );
    _notifyRouteMapRevision(checkpointIds: {point.id});
    if (persistCache) {
      unawaited(PatrolActiveRoundCache.markCheckpointVerified(point.id));
    }
  }

  /// Sets [_active], syncs server `verified` into model + [_scannedCheckpointIds].
  void _applyLoadedActiveRound(
    ActivePatrolRound? active, {
    required bool fromRefresh,
  }) {
    final previousRoundId = _active?.round.id;
    _reloadToken++;
    if (active == null) {
      _resetStaleForegroundScanUiState();
      _active = null;
      _scannedCheckpointIds.clear();
      _overdueChipReloadDone = false;
      _notifyRouteMapRevision();
      _syncOverdueUiRefreshTimer();
      return;
    }

    if (previousRoundId != null && previousRoundId != active.round.id) {
      _resetStaleForegroundScanUiState();
      _overdueChipReloadDone = false;
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
    if (_active != null && _isWithinOverdueGracePeriod(_active!)) {
      _overdueChipReloadDone = true;
    }
    _syncOverdueUiRefreshTimer();
  }

  /// Silent GET active as soon as overdue chip would appear — server status may
  /// already hide scan buttons while local round snapshot is stale.
  void _maybeReloadForOverdueChipShown() {
    final active = _active;
    if (active == null) {
      _overdueChipReloadDone = false;
      return;
    }
    if (!_isWithinOverdueGracePeriod(active)) return;
    if (_overdueChipReloadDone) return;
    if (_loading || _refreshing || _overdueNoteSubmittingId != null) return;

    _overdueChipReloadDone = true;
    unawaited(_load(silent: true));
  }

  void _onOverdueChipDeadlineReached() {
    if (!mounted) return;
    _maybeReloadForOverdueChipShown();
    setState(() {});
  }

  void _scheduleOverdueChipReloadAtDeadline(ActivePatrolRound data) {
    _overdueChipReloadTimer?.cancel();
    _overdueChipReloadTimer = null;

    if (!_isRoundNotCompleted(data.round)) return;
    final end = _roundExpectedEndDeadline(data);
    if (end == null) return;

    final delay = end.difference(DateTime.now());
    if (delay.isNegative) {
      _maybeReloadForOverdueChipShown();
      return;
    }
    _overdueChipReloadTimer = Timer(delay, _onOverdueChipDeadlineReached);
  }

  void _markCheckpointVerified(int checkpointId) {
    final active = _active;
    if (active == null) return;
    CheckPoint? point;
    for (final p in active.checkPoints) {
      if (p.id == checkpointId) {
        point = p;
        break;
      }
    }
    if (point == null) return;
    final verifiedPoint = point;
    setState(() {
      _applyCheckpointVerified(verifiedPoint, persistCache: true);
    });
  }
  // --- Scan flows: shared ---

  bool get _roundActionBusy =>
      _refreshing ||
      _scanningCheckpointId != null ||
      _overdueNoteSubmittingId != null ||
      _autoScanActive ||
      _manualScanKind != null;

  DateTime? _roundOverdueGraceDeadline(ActivePatrolRound data) {
    final end = _roundExpectedEndDeadline(data);
    if (end == null) return null;
    return end.add(Duration(minutes: _overdueGraceMinutes));
  }

  bool _isWithinOverdueGracePeriod(ActivePatrolRound data) {
    if (!_isRoundNotCompleted(data.round) || !_isRoundOverdue(data)) {
      return false;
    }
    final graceDeadline = _roundOverdueGraceDeadline(data);
    if (graceDeadline == null) return false;
    return DateTime.now().isBefore(graceDeadline);
  }

  void _syncOverdueUiRefreshTimer() {
    _overdueUiRefreshTimer?.cancel();
    _overdueUiRefreshTimer = null;
    _overdueChipReloadTimer?.cancel();
    _overdueChipReloadTimer = null;

    final active = _active;
    if (active == null || !_isRoundNotCompleted(active.round)) return;
    if (_roundExpectedEndDeadline(active) == null) return;

    _scheduleOverdueChipReloadAtDeadline(active);

    _overdueUiRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _maybeReloadForOverdueChipShown();
      setState(() {});
    });
  }

  Future<String?> _promptOverdueNoteDialog({
    required AppLocalizations l10n,
    required CheckPoint point,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _OverdueNoteDialog(l10n: l10n, point: point),
    );
  }

  Future<DeviceLocationSample?> _locationSampleForOverdueNote(
    CheckPoint point,
    AppLocalizations l10n,
  ) async {
    final needsBaro = point.baroAltitude != null;
    final cfg = await PatrolTrackingConfigStore.load();
    final gps = await readDeviceGpsOnce(
      timeout: Duration(seconds: cfg.scanGpsFastSec),
      enableBarometer: needsBaro,
      targetAccuracyM: cfg.gpsAccM,
    );
    if (!mounted) return null;

    final pos = gps.position;
    if (pos != null) {
      final gpsAlt = pos.altitude.isFinite ? pos.altitude : null;
      return (
        position: pos,
        latitude: pos.latitude,
        longitude: pos.longitude,
        gpsAltitude: gpsAlt,
        baroAltitude: gps.barometricAltitude,
      );
    }

    if (point.hasCoordinates) {
      if (gps.position == null) {
        context.showTopToast(
          _gpsMessageFromKey(gps.messageKey, l10n),
          backgroundColor: const Color(0xFFF59E0B),
          duration: const Duration(milliseconds: 800),
        );
      }
      return _fallbackLocationSampleForCheckpoint(point);
    }

    context.showTopToast(
      l10n.patrolRoundOverdueNoteNoGps,
      backgroundColor: const Color(0xFFF59E0B),
      duration: const Duration(milliseconds: 1200),
    );
    return null;
  }

  Future<void> _onOverduePointNote(
    ActivePatrolRound data,
    CheckPoint point,
  ) async {
    if (_roundActionBusy) return;
    if (!_isWithinOverdueGracePeriod(data)) return;
    if (_isCheckpointScanned(point)) return;

    final l10n = AppLocalizations.of(context)!;
    final reason = await _promptOverdueNoteDialog(l10n: l10n, point: point);
    if (!mounted || reason == null) return;

    setState(() => _overdueNoteSubmittingId = point.id);
    try {
      final sample = await _locationSampleForOverdueNote(point, l10n);
      if (!mounted || sample == null) return;

      final note = '${l10n.patrolRoundOverdueNotePrefix}$reason';
      final ok = await _submitPatrolLogAfterProximity(
        point: point,
        roundId: data.round.id,
        sample: sample,
        note: note,
        successMessage: l10n.patrolRoundOverdueNoteSuccess,
        failureMessage: l10n.patrolRoundOverdueNoteFailed,
      );
      if (mounted && ok) {
        unawaited(_load(silent: true));
      }
    } finally {
      if (mounted) {
        setState(() => _overdueNoteSubmittingId = null);
      }
    }
  }

  /// Radar header — mirrors FGS listener attached and not soft-paused.
  bool get _backgroundFgsScanEnabled =>
      PatrolBackgroundAutoScanUiState.running.value &&
      !PatrolBackgroundAutoScanUiState.awaitingNextRoundConfirm.value;

  /// FGS auto-scan pause — only [_preferManualScan]; scan UI flags do not resume FGS.
  bool get _backgroundFgsScanPaused => _preferManualScan;

  Future<void> _syncFgsAutoScanRunningFromPrefs() async {
    final running = await PatrolActiveRoundCache.isBackgroundAutoScanRunning();
    PatrolBackgroundAutoScanUiState.setRunning(running);
  }

  /// Radar header only — prefs/config mirror; never pauses or recovers FGS.
  Future<void> _syncRadarHeaderMirrorFromPrefs() async {
    await _syncBackgroundAutoScanConfiguredFromPrefs();
    if (!mounted) return;
    await _syncOverdueGraceFromConfig();
    if (!mounted) return;
    await _syncFgsAutoScanRunningFromPrefs();
  }

  Future<void> _syncBackgroundAutoScanConfiguredFromPrefs() async {
    final enabled = await PatrolTrackingConfigStore.backgroundAutoScanEnabled();
    if (!mounted) return;
    if (_backgroundAutoScanConfigured == enabled) return;
    setState(() => _backgroundAutoScanConfigured = enabled);
  }

  Future<void> _syncOverdueGraceFromConfig() async {
    final minutes = (await PatrolTrackingConfigStore.load()).overdueGraceMinutes;
    if (!mounted) return;
    if (_overdueGraceMinutes == minutes) return;
    setState(() => _overdueGraceMinutes = minutes);
  }

  Future<void> _syncAwaitingNextRoundConfirmFromPrefs() async {
    final awaiting =
        await PatrolActiveRoundCache.isAwaitingNextRoundAutoScanConfirm();
    if (!mounted) return;
    if (awaiting) {
      PatrolBackgroundAutoScanUiState.setRunning(false);
    } else {
      await _syncFgsAutoScanRunningFromPrefs();
    }
    PatrolBackgroundAutoScanUiState.setAwaitingNextRoundConfirm(awaiting);
    if (!mounted) return;
    setState(() {});
  }

  /// Pauses FGS background auto-scan ([_preferManualScan]); emit vị trí không đổi.
  void _syncBackgroundAutoScanSuppression() {
    unawaited(_syncBackgroundAutoScanSuppressionAsync());
  }

  Future<void> _syncBackgroundAutoScanSuppressionAsync() async {
    await PatrolRealtimeTrackCoordinator.setRoundScanBusy(
      _backgroundFgsScanPaused,
    );
  }

  /// After local [_load] — hold next-round prompt or sync manual-scan busy.
  /// May recover FGS auto-scan when armed but not running; never reload a live scan.
  Future<void> _applyFgsScanPolicyAfterRoundDataLoaded() async {
    await _syncBackgroundAutoScanConfiguredFromPrefs();
    if (!mounted) return;
    await _syncOverdueGraceFromConfig();
    if (!mounted) return;
    await _syncAwaitingNextRoundConfirmFromPrefs();
    if (!mounted) return;
    if (PatrolBackgroundAutoScanUiState.awaitingNextRoundConfirm.value) {
      unawaited(PatrolBackgroundService.syncNextRoundAutoScanHoldIfAwaiting());
      return;
    }
    await _releaseForegroundScanBusyUnlessManual();
    await _recoverBackgroundAutoScanIfNeeded();
    await _syncFgsAutoScanRunningFromPrefs();
  }

  /// FGS/STOMP pushed round — sync UI only; FGS owns hold/reload while scan runs.
  Future<void> _syncFgsScanPolicyFromExternalRoundUpdate() async {
    await _syncAwaitingNextRoundConfirmFromPrefs();
    if (!mounted) return;
    if (PatrolBackgroundAutoScanUiState.awaitingNextRoundConfirm.value) {
      return;
    }
    await _releaseForegroundScanBusyUnlessManual();
    await _recoverBackgroundAutoScanIfNeeded();
    await _syncFgsAutoScanRunningFromPrefs();
  }

  Future<void> _releaseForegroundScanBusyUnlessManual() async {
    if (_preferManualScan) {
      await PatrolRealtimeTrackCoordinator.setRoundScanBusy(true);
    } else {
      await PatrolRealtimeTrackCoordinator.setRoundScanBusy(false);
    }
  }

  /// Starts FGS auto-scan only when user already armed it but listener is off.
  Future<void> _recoverBackgroundAutoScanIfNeeded() async {
    if (_preferManualScan) return;
    if (await PatrolActiveRoundCache.isAwaitingNextRoundAutoScanConfirm()) {
      return;
    }
    final active = _active;
    if (active != null &&
        !PatrolRoundStatus.isPendingOrInProgress(active.round.status)) {
      return;
    }
    final armed = await PatrolActiveRoundCache.isBackgroundAutoScanArmed();
    if (!armed) return;
    if (await PatrolActiveRoundCache.isBackgroundAutoScanRunning()) return;
    await PatrolRealtimeTrackCoordinator.triggerBackgroundAutoScan();
  }

  /// Header radar or four scan buttons — pause FGS until [_resumeBackgroundFgsScan].
  void _pauseBackgroundFgsScan() {
    unawaited(PatrolActiveRoundSync.clearBackgroundAutoScanArmed());
    if (!_preferManualScan) {
      setState(() => _preferManualScan = true);
    }
    _syncBackgroundAutoScanSuppression();
  }

  void _resumeBackgroundFgsScan() {
    if (!_preferManualScan) return;
    setState(() => _preferManualScan = false);
    _syncBackgroundAutoScanSuppression();
  }

  Future<void> _onToggleBackgroundFgsScan() async {
    final l10n = AppLocalizations.of(context)!;
    await _syncAwaitingNextRoundConfirmFromPrefs();
    if (!mounted) return;
    if (PatrolBackgroundAutoScanUiState.awaitingNextRoundConfirm.value) {
      _resumeBackgroundFgsScan();
      await PatrolRealtimeTrackCoordinator.setRoundScanBusy(false);
      await PatrolActiveRoundSync.confirmNextRoundAutoScanFromUser();
      if (!mounted) return;
      await _syncAwaitingNextRoundConfirmFromPrefs();
      if (!mounted) return;
      await _syncFgsAutoScanRunningFromPrefs();
      if (!mounted) return;
      setState(() {});
      context.showTopToast(
        l10n.patrolBackgroundNextRoundConfirmed,
        duration: const Duration(milliseconds: 800),
      );
      return;
    }
    if (!_backgroundFgsScanEnabled) {
      _resumeBackgroundFgsScan();
      if (!await PatrolActiveRoundSync.armBackgroundAutoScanByUser()) {
        if (await PatrolActiveRoundCache.isAwaitingNextRoundAutoScanConfirm()) {
          await PatrolRealtimeTrackCoordinator.setRoundScanBusy(false);
          await PatrolActiveRoundSync.confirmNextRoundAutoScanFromUser();
          if (!mounted) return;
          await _syncAwaitingNextRoundConfirmFromPrefs();
          if (!mounted) return;
          await _syncFgsAutoScanRunningFromPrefs();
          if (!mounted) return;
          setState(() {});
          context.showTopToast(
            l10n.patrolBackgroundNextRoundConfirmed,
            duration: const Duration(milliseconds: 800),
          );
        }
        return;
      }
      await PatrolRealtimeTrackCoordinator.triggerBackgroundAutoScan();
      if (!mounted) return;
      await _syncFgsAutoScanRunningFromPrefs();
      if (!mounted) return;
      setState(() {});
      context.showTopToast(
        l10n.patrolRoundBackgroundScanResumed,
        duration: const Duration(milliseconds: 800),
      );
      return;
    }

    _pauseBackgroundFgsScan();
    if (!mounted) return;
    context.showTopToast(
      l10n.patrolRoundBackgroundScanPaused,
      duration: const Duration(milliseconds: 800),
    );
  }
  Future<void> _stopQrLocationWatch() async {
    await _qrLocationWatch?.stop();
    _qrLocationWatch = null;
  }
  Future<void> _stopBluetoothScanWatch() async {
    await _bluetoothScanWatch?.stop();
    _bluetoothScanWatch = null;
  }
  Future<void> _cancelQrScanWait() async {
    PatrolProximityNavigationTts.reset();
    await _stopQrLocationWatch();
    await _stopBluetoothScanWatch();
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
  }
  Future<void> _finishAutoScanSession({String? message}) async {
    PatrolProximityNavigationTts.reset();
    await _stopQrLocationWatch();
    await _stopBluetoothScanWatch();
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

  Future<bool> _submitPatrolLogAfterProximity({
    required CheckPoint point,
    required int roundId,
    required DeviceLocationSample sample,
    List<String> photoPaths = const [],
    String? note,
    String? successMessage,
    String? failureMessage,
    bool resumeAutoScan = false,
  }) async {
    if (!mounted) return false;

    final l10n = AppLocalizations.of(context)!;

    if (await PatrolActiveRoundCache.isCheckpointVerified(point.id)) {
      _markCheckpointVerified(point.id);
      if (!mounted) return false;
      context.showTopToast(
        l10n.patrolRoundQrScanSuccess,
        duration: const Duration(milliseconds: 400),
      );
      if (resumeAutoScan) {
        _resumeAutoScanAfterCheckpoint();
      } else {
        setState(() {
          _scanningCheckpointId = null;
          _manualScanKind = null;
          _qrScanSubmitting = false;
          _autoScanActive = false;
          _autoScanKind = null;
        });
        await _stopQrLocationWatch();
      }
      return true;
    }

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
      note: note,
      photoPaths: photoPaths,
    );

    var ok = false;
    try {
      final logResult = await PatrolLogService.instance.createPatrolLog(submit);

      if (!mounted) return false;

      if (logResult.ok) {
        ok = true;
        _markCheckpointVerified(point.id);
        if (!mounted) return false;
        context.showTopToast(
          successMessage ?? l10n.patrolRoundQrScanSuccess,
         duration: const Duration(milliseconds: 400));
      } else {
        context.showTopToast(
          failureMessage ??
              _messageForScanFailure(logResult.failure!, l10n),
         duration: const Duration(milliseconds: 400));
      }
    } catch (_) {
      if (!resumeAutoScan) {
        await _cancelQrScanWait();
      }
      if (!mounted) return false;
      context.showTopToast(
        failureMessage ?? l10n.patrolRoundQrScanFailed,
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
            unawaited(_load(silent: true));
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
          await _stopQrLocationWatch();
        }
      }
    }
    return ok;
  }
  // --- Scan flow: QR (onQrScan) ---

  Future<void> _onRoundQrScan(ActivePatrolRound data) async {
    if (_roundActionBusy) return;

    final l10n = AppLocalizations.of(context)!;
    _pauseBackgroundFgsScan();
    setState(() => _manualScanKind = _RoundManualScanKind.qr);
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
      }
    }
  }

  /// After QR/NFC match: photo popup, one-shot GPS read, submit patrol log.
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
    
    final needsBaro = point.baroAltitude != null;
    final cfg = await PatrolTrackingConfigStore.load();
    final gps = await readDeviceGpsOnce(
      timeout: Duration(seconds: cfg.scanGpsFastSec),
      enableBarometer: needsBaro,
      targetAccuracyM: cfg.gpsAccM,
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
    );
  }

  // --- Scan flow: NFC (onNfcScan) ---

  Future<void> _onRoundNfcScan(ActivePatrolRound data) async {
    if (_roundActionBusy) return;

    final l10n = AppLocalizations.of(context)!;
    if (!isNfcScanSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.patrolPointNfcUnavailable)),
      );
      return;
    }

    _pauseBackgroundFgsScan();
    setState(() => _manualScanKind = _RoundManualScanKind.nfc);
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
      }
    }
  }

  // --- Scan flow: auto GPS (onAutoScan) ---

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

    await _submitPatrolLogAfterProximity(
      point: point,
      roundId: roundId,
      sample: sample,
      photoPaths: photoPaths,
      resumeAutoScan: true,
    );
  }

  /// Normalizes QR payload and matches `CheckPoint.qrCode` on the current route.
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

    _pauseBackgroundFgsScan();
    setState(() {
      _autoScanActive = true;
      _autoScanKind = _RoundAutoScanKind.gps;
      _qrScanSubmitting = false;
    });

    final statusNotifier = ValueNotifier<_QrScanProximityStatus>(
      _QrScanProximityStatus(headline: l10n.patrolRoundQrWaitingPosition),
    );
    _autoScanStatusNotifier = statusNotifier;

    if (!mounted) return;

    final needsBaroValidation = eligible.any((p) => p.baroAltitude != null);
    final trackingConfig = await PatrolTrackingConfigStore.load();
    final matchOrder = trackingConfig.checkPointMatchOrder;
    final defaultRadiusM = trackingConfig.radius;
    final watch = await PatrolForegroundGpsScanSession.create();
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
          return _AutoScanWaitingSheet(
            l10n: l10n,
            statusNotifier: statusNotifier,
            onCancel: () {
              Navigator.of(sheetContext).pop();
              unawaited(_cancelQrScanWait());
            },
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
        final scan = scanCheckPointsProximity(
          pending,
          sample,
          validateBaro,
          matchOrder: matchOrder,
          defaultRadiusM: defaultRadiusM,
        );

        if (scan.matched == null) {
          final feedback = scan.feedback;
          if (feedback != null) {
            statusNotifier.value = _qrScanProximityStatus(
              l10n: l10n,
              proximity: feedback.result,
              snapshot: feedback.snapshot,
            );
            final snapshot = feedback.snapshot;
            if (snapshot != null) {
              unawaited(
                PatrolProximityNavigationTts.maybeSpeak(
                  snapshot: snapshot,
                  speedMps: sample.position.speed,
                ),
              );
            }
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

  // --- Scan flow: auto Bluetooth (onAutoScanBluetooth) ---

  List<CheckPoint> _eligibleBluetoothCheckPoints(ActivePatrolRound data) {
    final out = <CheckPoint>[];
    for (final p in data.checkPoints) {
      if (_isCheckpointScanned(p)) continue;
      final uuid = p.uuid?.trim();
      final remoteId = p.remoteId?.trim();
      if ((uuid == null || uuid.isEmpty) &&
          (remoteId == null || remoteId.isEmpty)) {
        continue;
      }
      out.add(p);
    }
    out.sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));
    return out;
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
    final cfg = await PatrolTrackingConfigStore.load();
    final gps = await readDeviceGpsOnce(
      timeout: Duration(seconds: cfg.scanGpsSec),
      enableBarometer: needsBaro,
      targetAccuracyM: cfg.gpsAccM,
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

    _pauseBackgroundFgsScan();
    setState(() {
      _autoScanActive = true;
      _autoScanKind = _RoundAutoScanKind.bluetooth;
      _qrScanSubmitting = false;
    });

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
          return _AutoScanWaitingSheet(
            l10n: l10n,
            statusNotifier: statusNotifier,
            onCancel: () {
              Navigator.of(sheetContext).pop();
              unawaited(_cancelQrScanWait());
            },
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

    if (!isBluetoothScanSupported) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.patrolPointBluetoothUnavailable)),
      );
      await _cancelQrScanWait();
      return;
    }

    final scanUuids = eligible
        .map((p) => p.uuid?.trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    final watch = BluetoothBeaconScanSession();
    _bluetoothScanWatch = watch;

    final bluetoothRssiTolerance =
        (await PatrolTrackingConfigStore.load()).bluetoothRssiTolerance;
    if (!mounted) return;

    final btError = await watch.start(
      uuids: scanUuids.isEmpty ? null : scanUuids,
      stableHits: 1,
      successRssi: -85,
      onHit: (result) {
        if (!mounted ||
            !_autoScanActive ||
            _autoScanKind != _RoundAutoScanKind.bluetooth ||
            _qrScanSubmitting) {
          return false;
        }

        final active = _active;
        if (active == null) return true;

        final pending = _eligibleBluetoothCheckPoints(active);
        if (pending.isEmpty) {
          unawaited(
            _finishAutoScanSession(message: l10n.patrolRoundAutoScanComplete),
          );
          return true;
        }

        statusNotifier.value = _QrScanProximityStatus(
          headline: l10n.patrolRoundBluetoothWaiting,
        );

        if (!result.ok) {
          if (result.failure != null) {
            statusNotifier.value = _QrScanProximityStatus(
              headline: _bluetoothScanFailureMessage(l10n, result.failure!),
            );
          }
          return false;
        }

        final matched = _matchBluetoothCheckPoint(
          pending,
          uuid: result.uuid,
          major: result.beacon?.major,
          minor: result.beacon?.minor,
          rssi: result.beacon?.rssi,
          rssiTolerance: bluetoothRssiTolerance,
        );
        if (matched == null) return false;

        setState(() => _qrScanSubmitting = true);
        statusNotifier.value = _QrScanProximityStatus(
          headline: l10n.patrolRoundQrPositionOkSaving,
        );
        unawaited(
          _completeBluetoothAutoScanAfterMatch(
            point: matched,
            roundId: roundId,
          ),
        );
        return false;
      },
    );

    if (!mounted) return;

    if (btError != null) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      await _cancelQrScanWait();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_bluetoothScanFailureMessage(l10n, btError))),
      );
    }
  }

  // --- Overlays ---

  Future<void> _openRouteMapOverlay() async {
    final data = _active;
    if (data == null || !mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: AppLocalizations.of(context)!.patrolRoundMap,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 220),
      // Avoid FadeTransition: opacity < 1 leaves OSM tiles unloaded (dark map)
      // until the user touches and forces a camera event.
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
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
        return _ScheduleSheet(
          theme: theme,
          loading: _loading,
          failure: _failure,
          data: _active,
          messageForFailure: _messageForFailure,
        );
      },
    );
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
          if (data != null &&
              _failure == null &&
              _backgroundAutoScanConfigured &&
              _showHeaderRadar(data))
            IconButton.filledTonal(
              key: ValueKey(
                'bg-fgs-${_backgroundFgsScanEnabled ? 'on' : 'off'}-'
                '${PatrolBackgroundAutoScanUiState.running.value}',
              ),
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: _backgroundFgsScanEnabled
                    ? const Color(0xFF34D399).withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.1),
                foregroundColor: _backgroundFgsScanEnabled
                    ? const Color(0xFF34D399)
                    : Colors.white.withValues(alpha: 0.92),
              ),
              icon: Icon(
                _backgroundFgsScanEnabled
                    ? Icons.radar
                    : Icons.radar_rounded,
              ),
              tooltip: _backgroundFgsScanEnabled
                  ? l10n.patrolRoundPauseBackgroundScan
                  : l10n.patrolRoundResumeBackgroundScan,
              onPressed: () => unawaited(_onToggleBackgroundFgsScan()),
            ),
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
                '${data.round.assignedName}-'
                '${_isRoundActive(data.round.status)}-'
                '$_manualScanKind-$_autoScanKind-$_autoScanActive-'
                '$_refreshing-$_reloadToken-$_preferManualScan',
              ),
              theme: theme,
              l10n: l10n,
              round: data.round,
              statusLabel: _statusLabel(data.round.status, l10n),
              statusColor: _statusColor(data.round.status),
              loading: _refreshing,
              onReload: () => unawaited(_load(silent: true)),
              qrScanBusy: _manualScanKind == _RoundManualScanKind.qr,
              onQrScan: _isRoundOngoing(data.round)
                  ? () {
                      final current = _active;
                      if (current == null) return;
                      unawaited(_onRoundQrScan(current));
                    }
                  : null,
              nfcScanBusy: _manualScanKind == _RoundManualScanKind.nfc,
              onNfcScan: _isRoundOngoing(data.round) && isNfcScanSupported
                  ? () {
                      final current = _active;
                      if (current == null) return;
                      unawaited(_onRoundNfcScan(current));
                    }
                  : null,
              autoScanBusy:
                  _autoScanActive && _autoScanKind == _RoundAutoScanKind.gps,
              onAutoScan: _isRoundOngoing(data.round)
                  ? () {
                      final current = _active;
                      if (current == null) return;
                      unawaited(_onAutoScanGps(current));
                    }
                  : null,
              autoScanBluetoothBusy: _autoScanActive &&
                  _autoScanKind == _RoundAutoScanKind.bluetooth,
              onAutoScanBluetooth: _isRoundOngoing(data.round) &&
                      isBluetoothScanSupported
                  ? () {
                      final current = _active;
                      if (current == null) return;
                      unawaited(_onAutoScanBluetooth(current));
                    }
                  : null,
            ),
          ],
          if (!_loading && _failure == null && data != null) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.patrolRoundRouteHeading,
                    style: theme.titleSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_isWithinOverdueGracePeriod(data))
                  _StatusChip(
                    label: l10n.patrolRoundOverdue,
                    color: const Color(0xFFFBBF24),
                    filled: true,
                  ),
              ],
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
                (p) {
                  final showOverdueNote =
                      _isWithinOverdueGracePeriod(data) && !_isCheckpointScanned(p);
                  return Padding(
                  key: ValueKey(
                    'route-${p.id}-${p.verified}-'
                    '${p.latitude}-${p.longitude}-${p.name}-$_reloadToken',
                  ),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RoutePointCard(
                    theme: theme,
                    l10n: l10n,
                    point: p,
                    scanned: _isCheckpointScanned(p),
                    qrBusy: _scanningCheckpointId == p.id,
                    overdueNoteBusy: _overdueNoteSubmittingId == p.id,
                    onOverdueNote: showOverdueNote
                        ? () {
                            final current = _active;
                            if (current == null) return;
                            unawaited(_onOverduePointNote(current, p));
                          }
                        : null,
                  ),
                );
                },
              ),
          ],
        ],
      ),
    );
  }
}
