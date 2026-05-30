import 'dart:async';



import 'package:flutter/services.dart';

import 'package:flutter_background_service/flutter_background_service.dart';

import 'package:shared_preferences/shared_preferences.dart';



import '../config/storage_keys.dart';
import '../models/check_point.dart';
import 'patrol_background_auto_scan.dart';

import 'patrol_background_gps_hub.dart';

import 'patrol_background_service.dart';

import 'patrol_background_track_emitter.dart';

import 'patrol_fgs_invoke_events.dart';

import 'patrol_track_socket_client.dart';

import 'patrol_track_token_sync.dart';

import 'patrol_tracking_config_store.dart';



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

  Future<void>? _refreshChain;

  Timer? _prefsPollTimer;



  /// Register invoke handlers before slow FGS / notification init (UI may invoke early).

  void prepare() {

    PatrolBackgroundService.attachBackgroundService(_service);

    PatrolBackgroundService.setRelayCheckpointSuccess(_relayCheckpointSuccess);



    _registerCommands();

    _prefsPollTimer = Timer.periodic(const Duration(minutes: 45), (_) {

      if (!_shuttingDown) unawaited(refreshTracking());

    });



    PatrolTrackSocketClient.instance.configureFgsBridge(

      service: _service,

      onRoundSynced: _onActiveRoundSyncedFromStomp,

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await prefs.setBool(StorageKeys.patrolTrackPendingFgsReloadAfterRound, false);
    unawaited(_autoScan.reloadAfterRoundPersist());
  }



  /// After [prepare] — apply pending main refresh or prefs (invoke may have fired too early).

  Future<void> startTracking() async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.reload();

    final pending = prefs.getBool(StorageKeys.patrolTrackPendingFgsReloadAfterRound) ??

            false;

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

      final afterRound = payload is Map &&

          payload['afterRoundPersist'] == true;

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

      if (!_shuttingDown) unawaited(_autoScan.resume());

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



    final prefs = await SharedPreferences.getInstance();

    await prefs.reload();



    final emit = prefs.getBool(StorageKeys.patrolTrackEmitEnabled) ?? false;

    if (!emit) {

      await _autoScan.stop();

      await _trackEmitter.stop();

      await _gpsHub.stop();

      return;

    }



    await _trackEmitter.start();



    if (reloadAutoScanAfterRound) {

      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(StorageKeys.patrolTrackPendingFgsReloadAfterRound, false);

      // Pick up new checkpoints even if FGS survived — do not block refresh chain.

      unawaited(_autoScan.reloadAfterRoundPersist());

    } else {

      // Periodic refresh / emit toggle — skip GPS reattach when already active.

      await _autoScan.refresh();

    }



    await PatrolTrackTokenSync.reconnectIfTokenChangedFromPrefs();



    if (await PatrolTrackingConfigStore.socketEnabled()) {

      await PatrolTrackSocketClient.instance.connect();

    }

  }



  Future<void> shutdown() async {

    if (_shuttingDown) return;

    _shuttingDown = true;



    _prefsPollTimer?.cancel();

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

    PatrolBackgroundService.detachBackgroundService();

    PatrolBackgroundService.cancelNotificationRevertTimer();

    await PatrolBackgroundService.cancelForegroundNotification();

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


