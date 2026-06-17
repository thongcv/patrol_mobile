import 'dart:async';

import 'package:flutter/services.dart';

import 'package:flutter_background_service/flutter_background_service.dart';

import '../models/check_point.dart';
import '../services/account_session_store.dart';
import '../services/patrol_foreground_notification.dart';
import '../services/patrol_active_round_cache.dart';
import '../services/patrol_active_round_sync.dart';
import '../services/patrol_track_socket_client.dart';
import '../services/patrol_track_token_sync.dart';
import '../services/patrol_tracking_config_store.dart';
import 'patrol_background_auto_scan.dart';
import 'patrol_background_constants.dart';
import 'patrol_background_gps_hub.dart';
import 'patrol_background_track_emitter.dart';
import 'patrol_fgs_invoke_events.dart';
import 'patrol_fgs_isolate_bridge.dart';
import 'patrol_fgs_notifications.dart';

/// FGS isolate runtime: prefs-driven GPS emit, auto-scan, and STOMP.

final class PatrolBackgroundRunner {
  PatrolBackgroundRunner(this._service);

  final ServiceInstance _service;

  final _gpsHub = PatrolBackgroundGpsHub();

  late final PatrolBackgroundTrackEmitter _trackEmitter =
      PatrolBackgroundTrackEmitter(_gpsHub);

  late final PatrolBackgroundAutoScan _autoScan = PatrolBackgroundAutoScan(
    _gpsHub,
    onCheckpointVerified: _relayActiveRoundChanged,
  );

  final _commandSubscriptions = <StreamSubscription<dynamic>>[];

  var _shuttingDown = false;

  Timer? _nextRoundConfirmPollTimer;
  Timer? _nextRoundConfirmExpiryTimer;

  Future<void>? _refreshChain;
  Future<void>? _confirmNextRoundChain;
  Future<void>? _cancelNextRoundChain;
  Future<void>? _offerNextRoundChain;

  Timer? _prefsPollTimer;

  Timer? _shiftBoundaryTimer;

  /// Register invoke handlers before slow FGS / notification init (UI may invoke early).

  void prepare() {
    PatrolFgsIsolateBridge.attachBackgroundService(_service);

    PatrolFgsIsolateBridge.setRelayCheckpointSuccess(_relayCheckpointSuccess);
    PatrolFgsIsolateBridge.setRelayProximityNavigation(_relayProximityNavigation);
    PatrolFgsIsolateBridge.setOnSessionExpired(_shutdownOnSessionExpired);

    _registerCommands();

    _prefsPollTimer = Timer.periodic(const Duration(minutes: 45), (_) {
      if (!_shuttingDown) unawaited(refreshTracking());
    });

    PatrolTrackSocketClient.instance.configureFgsBridge(
      service: _service,

      onRoundSynced: _onActiveRoundSyncedFromStomp,

      onConfigUpdated: _onTrackingConfigUpdatedFromStomp,
    );
  }

  /// STOMP pushed active-round change — [PatrolTrackSocketClient] already ran
  /// [PatrolActiveRoundSync.fetchAndPersist]. Only reload auto-scan here; not
  /// [refreshTracking] (socket/token reconnect would loop with STOMP connect).
  Future<void> _onActiveRoundSyncedFromStomp() async {
    if (_shuttingDown) return;
    unawaited(_handleActiveRoundSyncedFromStomp());
  }

  Future<void> _handleActiveRoundSyncedFromStomp() async {
    if (await PatrolActiveRoundCache.load() == null) return;
    // [PatrolActiveRoundSync.fetchAndPersist] already ran
    // [ensureAwaitingNextRoundIfRoundChanged] — only latch awaiting on a real round
    // transition. Do not force awaiting/disarm on every STOMP push (same-round
    // checkpoint updates would undo a user confirm and block auto-scan).
    if (await PatrolActiveRoundCache.isAwaitingNextRoundAutoScanConfirm()) {
      PatrolFgsIsolateBridge.notifyAwaitingNextRoundAutoScanConfirm(true);
      await _autoScan.holdForNextRoundConfirm();
      await _enqueueOfferNextRoundAutoScanPrompt();
      return;
    }
    await _reloadAutoScanAfterRoundSilently();
  }

  Future<void> _enqueueOfferNextRoundAutoScanPrompt() {
    _offerNextRoundChain =
        (_offerNextRoundChain ?? Future<void>.value()).then(
      (_) => _offerNextRoundAutoScanPrompt(),
    );
    return _offerNextRoundChain!;
  }

  /// Notify + TTS — once per round while [awaiting]; not on UI re-sync.
  Future<void> _offerNextRoundAutoScanPrompt() async {
    if (!await PatrolActiveRoundCache.isCachedRoundPendingOrInProgress()) {
      return;
    }
    if (!await PatrolActiveRoundCache.tryAcquireNextRoundPromptOffer()) {
      return;
    }
    _stopNextRoundConfirmExpiryTimer();
    await PatrolActiveRoundCache.clearConfirmNextRoundAutoScan();
    await PatrolActiveRoundCache.takeCancelNextRoundAutoScan();
    await PatrolFgsNotifications.showNextRoundAutoScanPrompt();
    _startNextRoundConfirmPoll();
    _startNextRoundConfirmExpiryTimer();
  }

  /// Re-hold auto-scan when UI opens — no repeat heads-up / TTS.
  Future<void> _syncNextRoundAutoScanHoldOnly() async {
    if (!await PatrolActiveRoundCache.isAwaitingNextRoundAutoScanConfirm()) {
      return;
    }
    if (await PatrolActiveRoundCache.load() == null) {
      await PatrolActiveRoundCache.setAwaitingNextRoundAutoScanConfirm(false);
      await PatrolForegroundNotification.cancelNextRoundConfirm();
      return;
    }
    await _autoScan.holdForNextRoundConfirm();
    if (_nextRoundConfirmPollTimer == null) {
      _startNextRoundConfirmPoll();
    }
    if (_nextRoundConfirmExpiryTimer == null) {
      _startNextRoundConfirmExpiryTimer();
    }
  }

  /// Reload auto-scan after round cache changed (no notification).
  Future<void> _reloadAutoScanAfterRoundSilently() async {
    if (await PatrolActiveRoundCache.isAwaitingNextRoundAutoScanConfirm()) {
      await _autoScan.holdForNextRoundConfirm();
      return;
    }
    await PatrolActiveRoundCache.setPendingFgsReloadAfterRound(false);
    await _autoScan.reloadAfterRoundPersist();
    if (await PatrolActiveRoundCache.isBackgroundAutoScanArmed()) {
      await _trackEmitter.start();
    }
  }

  void _startNextRoundConfirmPoll() {
    _nextRoundConfirmPollTimer?.cancel();
    _nextRoundConfirmPollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_shuttingDown) {
        _stopNextRoundConfirmPoll();
        return;
      }
      unawaited(_pollNextRoundConfirmFromPrefs());
    });
  }

  void _stopNextRoundConfirmPoll() {
    _nextRoundConfirmPollTimer?.cancel();
    _nextRoundConfirmPollTimer = null;
  }

  void _startNextRoundConfirmExpiryTimer() {
    _nextRoundConfirmExpiryTimer?.cancel();
    _nextRoundConfirmExpiryTimer = Timer(
      PatrolBackgroundConstants.nextRoundConfirmVisibleDuration,
      () {
        if (_shuttingDown) return;
        unawaited(_onNextRoundConfirmExpired());
      },
    );
  }

  void _stopNextRoundConfirmExpiryTimer() {
    _nextRoundConfirmExpiryTimer?.cancel();
    _nextRoundConfirmExpiryTimer = null;
  }

  /// Without Xác nhận / Hủy in time — dismiss like cancel (no auto-scan).
  Future<void> _onNextRoundConfirmExpired() async {
    if (!await PatrolActiveRoundCache.isAwaitingNextRoundAutoScanConfirm()) {
      return;
    }
    await _enqueueCancelNextRoundAutoScan();
  }

  Future<void> _pollNextRoundConfirmFromPrefs() async {
    if (!await PatrolActiveRoundCache.isAwaitingNextRoundAutoScanConfirm()) {
      _stopNextRoundConfirmPoll();
      return;
    }
    if (await PatrolActiveRoundCache.takeCancelNextRoundAutoScan()) {
      await _enqueueCancelNextRoundAutoScan();
      return;
    }
    if (!await PatrolActiveRoundCache.takeConfirmNextRoundAutoScan()) return;
    await _enqueueConfirmNextRoundAutoScan();
  }

  Future<void> _enqueueConfirmNextRoundAutoScan() {
    _confirmNextRoundChain =
        (_confirmNextRoundChain ?? Future<void>.value()).then(
      (_) => _confirmNextRoundAutoScanImpl(),
    );
    return _confirmNextRoundChain!;
  }

  Future<void> _confirmNextRoundAutoScanImpl() async {
    if (!await PatrolActiveRoundCache.isAwaitingNextRoundAutoScanConfirm()) {
      return;
    }
    _stopNextRoundConfirmPoll();
    _stopNextRoundConfirmExpiryTimer();
    await PatrolActiveRoundCache.takeConfirmNextRoundAutoScan();
    await PatrolForegroundNotification.cancelNextRoundConfirm();
    await PatrolActiveRoundCache.markAutoScanConfirmedForCurrentRound();
    await PatrolActiveRoundCache.setAwaitingNextRoundAutoScanConfirm(false);
    PatrolFgsIsolateBridge.notifyAwaitingNextRoundAutoScanConfirm(false);
    await PatrolActiveRoundCache.setPendingFgsReloadAfterRound(false);
    await PatrolFgsNotifications.revertForegroundNotificationToPatrolDefault();
    await PatrolActiveRoundSync.armBackgroundAutoScanByUser();
    await _autoScan.resume();
    await _autoScan.reloadAfterRoundPersist();
    await _trackEmitter.start();
    await PatrolActiveRoundCache.signalNextRoundConfirmHandled();
  }

  /// Chỉ gỡ pause foreground — không xác nhận notify vòng mới.
  Future<void> _onResumeAutoScanRequested() async {
    if (await PatrolActiveRoundCache.isAwaitingNextRoundAutoScanConfirm()) {
      return;
    }
    if (await PatrolActiveRoundCache.isForegroundScanBusy()) {
      return;
    }
    await _autoScan.resume();
    if (await PatrolActiveRoundCache.isBackgroundAutoScanArmed()) {
      if (!_autoScan.isAutoScanActive) {
        await _autoScan.reloadAfterRoundPersist();
      }
      await _trackEmitter.start();
    } else if (!_autoScan.isAutoScanActive) {
      unawaited(_autoScan.refresh());
    }
  }

  Future<void> _enqueueCancelNextRoundAutoScan() {
    _cancelNextRoundChain = (_cancelNextRoundChain ?? Future<void>.value()).then(
      (_) => _cancelNextRoundAutoScanImpl(),
    );
    return _cancelNextRoundChain!;
  }

  Future<void> _cancelNextRoundAutoScanImpl() async {
    if (!await PatrolActiveRoundCache.isAwaitingNextRoundAutoScanConfirm()) {
      return;
    }
    _stopNextRoundConfirmPoll();
    _stopNextRoundConfirmExpiryTimer();
    await PatrolActiveRoundCache.takeConfirmNextRoundAutoScan();
    await PatrolActiveRoundCache.takeCancelNextRoundAutoScan();
    await PatrolForegroundNotification.cancelNextRoundConfirm();
    await PatrolActiveRoundCache.setAwaitingNextRoundAutoScanConfirm(false);
    PatrolFgsIsolateBridge.notifyAwaitingNextRoundAutoScanConfirm(false);
    // Cancel means "do not start auto-scan for this next round".
    // Do not write "last confirmed round id" here; that would break the
    // next-round awaiting logic and can cause auto-scan to resume later.
    await PatrolActiveRoundSync.clearBackgroundAutoScanArmed();
    await _autoScan.holdForNextRoundConfirm();
    await PatrolActiveRoundCache.setPendingFgsReloadAfterRound(false);
    await PatrolFgsNotifications.revertForegroundNotificationToPatrolDefault();
  }

  Future<void> _syncNextRoundAutoScanHoldFromPrefs() async {
    await _syncNextRoundAutoScanHoldOnly();
  }

  Future<void> _onTrackingConfigUpdatedFromStomp() async {
    if (_shuttingDown) return;
    unawaited(refreshTracking());
  }

  /// After [prepare] — apply pending main refresh or prefs (invoke may have fired too early).

  Future<void> startTracking() async {
    final pending = await PatrolActiveRoundCache.isPendingFgsReloadAfterRound();

    await refreshTracking(reloadAutoScanAfterRound: pending);
  }

  void _relayCheckpointSuccess(String name) {
    try {
      _service.invoke(
        PatrolFgsInvokeEvents.checkpointSuccess,

        <String, dynamic>{'checkpointName': name},
      );
    } on MissingPluginException {
      //
    } on PlatformException {
      //
    }
  }

  void _relayProximityNavigation(String message) {
    try {
      _service.invoke(
        PatrolFgsInvokeEvents.proximityNavigationHint,
        <String, dynamic>{'message': message},
      );
    } on MissingPluginException {
      //
    } on PlatformException {
      //
    }
  }

  void _relayActiveRoundChanged(CheckPoint point) {
    try {
      _service.invoke(
        PatrolFgsInvokeEvents.activeRoundChanged,

        <String, dynamic>{
          'checkPoint': point.copyWith(verified: true).toJson(),
        },
      );
    } on MissingPluginException {
      //
    } on PlatformException {
      //
    }
  }

  void _registerCommands() {
    _safeListen(PatrolFgsInvokeEvents.stop, (_) => unawaited(shutdown()));

    _safeListen(PatrolFgsInvokeEvents.refresh, (payload) {
      if (_shuttingDown) return;

      final afterRound = payload is Map && payload['afterRoundPersist'] == true;

      unawaited(refreshTracking(reloadAutoScanAfterRound: afterRound));
    });

    _safeListen(PatrolFgsInvokeEvents.tokenRefreshed, (_) {
      if (_shuttingDown) return;

      unawaited(_onTokenRefreshed());
    });

    _safeListen(PatrolFgsInvokeEvents.pauseAutoScan, (_) {
      if (!_shuttingDown) unawaited(_autoScan.pause());
    });

    _safeListen(PatrolFgsInvokeEvents.resumeAutoScan, (_) {
      if (!_shuttingDown) unawaited(_onResumeAutoScanRequested());
    });

    _safeListen(PatrolFgsInvokeEvents.confirmNextRoundAutoScan, (_) {
      if (!_shuttingDown) unawaited(_enqueueConfirmNextRoundAutoScan());
    });

    _safeListen(PatrolFgsInvokeEvents.cancelNextRoundAutoScan, (_) {
      if (!_shuttingDown) unawaited(_enqueueCancelNextRoundAutoScan());
    });

    _safeListen(PatrolFgsInvokeEvents.syncNextRoundAutoScanHold, (_) {
      if (!_shuttingDown) unawaited(_syncNextRoundAutoScanHoldFromPrefs());
    });

    _safeListen(PatrolFgsInvokeEvents.offerNextRoundAutoScan, (_) {
      if (!_shuttingDown) unawaited(_enqueueOfferNextRoundAutoScanPrompt());
    });

    _safeListen(PatrolFgsInvokeEvents.setForegroundScanRelay, (payload) {
      if (_shuttingDown) return;
      final map = payload is Map
          ? Map<String, dynamic>.from(payload)
          : const <String, dynamic>{};
      final enabled = map['enabled'] == true;
      final enableBarometer = map['enableBarometer'] == true;
      unawaited(
        _gpsHub.setForegroundScanRelay(
          enabled: enabled,
          wantsBarometer: enableBarometer,
        ),
      );
    });
  }

  Future<void> _onTokenRefreshed() async {
    await PatrolTrackTokenSync.reconnectAfterTokenStored();

    if (await PatrolTrackingConfigStore.socketEnabled() &&
        !PatrolTrackSocketClient.instance.isConnected) {
      await PatrolTrackSocketClient.instance.connect();
    }
  }

  Future<void> refreshTracking({bool reloadAutoScanAfterRound = false}) {
    _refreshChain = (_refreshChain ?? Future<void>.value()).then(
      (_) => _applyRefreshTracking(
        reloadAutoScanAfterRound: reloadAutoScanAfterRound,
      ),
    );

    return _refreshChain!;
  }

  Future<void> _applyRefreshTracking({
    bool reloadAutoScanAfterRound = false,
  }) async {
    if (_shuttingDown) return;

    await PatrolActiveRoundCache.refreshTrackingEmitGateCache();

    final awaitingConfirm =
        await PatrolActiveRoundCache.isAwaitingNextRoundAutoScanConfirm();

    final emit = await PatrolActiveRoundCache.isTrackEmitEnabled();

    if (!emit) {
      await _autoScan.stop();

      await _trackEmitter.stop();

      await _gpsHub.stop();

      return;
    }

    await _trackEmitter.start();

    if (awaitingConfirm) {
      await _autoScan.holdForNextRoundConfirm();
    } else if (reloadAutoScanAfterRound) {
      await _reloadAutoScanAfterRoundSilently();
    } else {
      // Periodic refresh / emit toggle — skip GPS reattach when already active.

      await _autoScan.refresh();
    }

    await PatrolTrackTokenSync.reconnectIfTokenChangedFromPrefs();

    if (await PatrolTrackingConfigStore.socketEnabled()) {
      await PatrolTrackSocketClient.instance.connect();
    }

    await _scheduleShiftBoundaryRefresh();
  }

  Future<void> _scheduleShiftBoundaryRefresh() async {
    _shiftBoundaryTimer?.cancel();
    _shiftBoundaryTimer = null;

    if (_shuttingDown) return;
    if (!await PatrolActiveRoundCache.isTrackEmitEnabled()) return;
    if (!await PatrolTrackingConfigStore.trackByShiftWindow()) return;

    final window = await PatrolActiveRoundCache.readShiftWindow(reload: false);
    if (window == null) return;

    final now = DateTime.now();
    final grace = await PatrolTrackingConfigStore.shiftWindowGrace();
    final next = window.nextBoundaryAfter(now, emitWindowGrace: grace);
    if (next == null) return;

    var delay = next.difference(now);
    if (delay.isNegative) delay = Duration.zero;
    delay += const Duration(seconds: 1);

    _shiftBoundaryTimer = Timer(delay, () {
      if (_shuttingDown) return;
      unawaited(refreshTracking());
    });
  }

  Future<void> _shutdownOnSessionExpired() async {
    if (_shuttingDown) return;
    await AccountSessionStore.instance.clearAccessToken();
    await shutdown();
  }

  Future<void> shutdown() async {
    if (_shuttingDown) return;

    _shuttingDown = true;

    _stopNextRoundConfirmPoll();
    _stopNextRoundConfirmExpiryTimer();
    unawaited(PatrolForegroundNotification.cancelNextRoundConfirm());
    // Keep [awaiting] across FGS stop — user may still need to confirm from notification.

    _prefsPollTimer?.cancel();
    _shiftBoundaryTimer?.cancel();

    for (final sub in _commandSubscriptions) {
      try {
        await sub.cancel();
      } on MissingPluginException {
        //
      } on PlatformException {
        //
      }
    }

    _commandSubscriptions.clear();

    await PatrolTrackSocketClient.instance.disconnect();

    await _autoScan.stop();

    await _trackEmitter.stop();

    await _gpsHub.stop();

    PatrolFgsIsolateBridge.detachBackgroundService();

    PatrolFgsNotifications.cancelNotificationRevertTimer();

    await PatrolFgsNotifications.cancelForegroundNotification(
      PatrolBackgroundConstants.foregroundNotificationId,
    );

    await _service.stopSelf();
  }

  void _safeListen(String event, void Function(dynamic payload) onData) {
    try {
      final sub = _service
          .on(event)
          .handleError((Object _, StackTrace _) {})
          .listen(
            onData,

            onError: (Object _, StackTrace _) {},

            cancelOnError: false,
          );

      _commandSubscriptions.add(sub);
    } on MissingPluginException {
      //
    } on PlatformException {
      //
    }
  }
}
