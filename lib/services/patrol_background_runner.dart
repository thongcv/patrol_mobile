import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import 'patrol_background_auto_scan.dart';
import 'patrol_background_service.dart';
import 'patrol_background_socket_emitter.dart';
import 'patrol_fgs_invoke_events.dart';
import 'patrol_track_socket_client.dart';
import 'patrol_track_token_sync.dart';
import 'patrol_tracking_config_store.dart';

/// FGS isolate runtime: prefs-driven GPS emit, auto-scan, and STOMP.
final class PatrolBackgroundRunner {
  PatrolBackgroundRunner(this._service);

  final ServiceInstance _service;

  final _socketEmitter = PatrolBackgroundSocketEmitter();
  late final PatrolBackgroundAutoScan _autoScan =
      PatrolBackgroundAutoScan(_socketEmitter);

  final _commandSubscriptions = <StreamSubscription<dynamic>>[];
  var _shuttingDown = false;
  Future<void>? _refreshChain;
  Timer? _prefsPollTimer;

  /// Register invoke handlers before slow FGS / notification init (UI may invoke early).
  void prepare() {
    PatrolBackgroundService.attachBackgroundService(_service);
    PatrolBackgroundService.setRelayCheckpointSuccess(_relayCheckpointSuccess);

    _registerCommands();
    _prefsPollTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!_shuttingDown) unawaited(refreshTracking());
    });

    PatrolTrackSocketClient.instance.configureFgsBridge(
      service: _service,
      onRoundSynced: refreshTracking,
    );
  }

  Future<void> startTracking() => refreshTracking();

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

  void _registerCommands() {
    _safeListen(PatrolFgsInvokeEvents.stop, (_) => unawaited(shutdown()));
    _safeListen(PatrolFgsInvokeEvents.refresh, (_) {
      if (!_shuttingDown) unawaited(refreshTracking());
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

  Future<void> refreshTracking() {
    _refreshChain =
        (_refreshChain ?? Future<void>.value()).then((_) => _applyRefreshTracking());
    return _refreshChain!;
  }

  Future<void> _applyRefreshTracking() async {
    if (_shuttingDown) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final emit = prefs.getBool(StorageKeys.patrolTrackEmitEnabled) ?? false;
    if (!emit) {
      await _autoScan.stop();
      return;
    }

    await _autoScan.refresh();
    if (!_socketEmitter.isListening) {
      await _socketEmitter.start();
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
    await _socketEmitter.stop();
    PatrolBackgroundService.detachBackgroundService();
    PatrolBackgroundService.cancelNotificationRevertTimer();
    await PatrolBackgroundService.cancelForegroundNotification();
    await _service.stopSelf();
  }

  void _safeListen(String event, void Function(dynamic payload) onData) {
    try {
      final sub = _service
          .on(event)
          .handleError((Object _, StackTrace __) {})
          .listen(
            onData,
            onError: (Object _, StackTrace __) {},
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
