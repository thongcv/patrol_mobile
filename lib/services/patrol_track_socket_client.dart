import 'dart:async';

import 'dart:convert';

import 'package:flutter_background_service/flutter_background_service.dart';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../config/app_config.dart';

import '../models/patrol_location_track_payload.dart';

import 'account_session_store.dart';

import 'patrol_active_round_sync.dart';

import 'patrol_background_isolate_flags.dart';

import 'patrol_fgs_invoke_events.dart';

import 'patrol_track_offline_queue.dart';

import 'patrol_track_socket_dispatch.dart';

import 'patrol_tracking_config_store.dart';

/// STOMP/SockJS — one implementation for main and FGS isolates.

///

/// Each isolate has its own [instance] (Dart isolates do not share memory).

/// Configure [configureFgsBridge] only in the background-service entrypoint.

class PatrolTrackSocketClient {
  PatrolTrackSocketClient._();

  static final PatrolTrackSocketClient instance = PatrolTrackSocketClient._();

  StompClient? _client;

  bool _connecting = false;

  bool _manualClose = false;

  Future<void>? _connectFuture;

  ServiceInstance? _fgsService;

  Future<void> Function()? _onFgsRoundSynced;

  bool get isConnected => _client?.connected ?? false;

  bool get _runsInFgs =>
      PatrolBackgroundIsolateFlags.active || _fgsService != null;


  /// Main isolate — mock GPS alert từ STOMP (không dùng khi FGS owns socket).

  void Function()? onMockLocationAlert;

  /// Call once from [patrolBackgroundOnStart] before [connect].

  void configureFgsBridge({
    required ServiceInstance service,

    required Future<void> Function() onRoundSynced,
  }) {
    _fgsService = service;

    _onFgsRoundSynced = onRoundSynced;
  }

  Future<void> connect() async {
    final inFlight = _connectFuture;

    if (inFlight != null) {
      await inFlight;

      return;
    }

    final future = _connectImpl();

    _connectFuture = future;

    try {
      await future;
    } finally {
      if (identical(_connectFuture, future)) {
        _connectFuture = null;
      }
    }
  }

  Future<void> disconnect() async {
    _manualClose = true;

    await _tearDownClient();
  }

  Future<void> reconnectAfterTokenRefresh() async {
    await disconnect();

    _manualClose = false;

    await connect();
  }

  Future<bool> sendTrackLocation(
    PatrolLocationTrackPayload payload, {
    bool reconnectOnFailure = true,
  }) async {
    if (payload.isMocked) return false;

    if (!await PatrolTrackingConfigStore.socketEnabled()) return false;

    if (!isConnected) {
      if (!_runsInFgs && await PatrolTrackingConfigStore.backgroundEnabled()) {
        return false;
      }

      await PatrolTrackOfflineQueue.enqueue(payload);

      if (reconnectOnFailure && !_manualClose) {
        unawaited(connect());
      }

      return false;
    }

    try {
      _client!.send(
        destination: AppConfig.stompTrackLocationDestination,

        body: jsonEncode(payload.toJson()),

        headers: <String, String>{'content-type': 'application/json'},
      );

      return true;
    } catch (e) {
      await PatrolTrackOfflineQueue.enqueue(payload);

      if (reconnectOnFailure && !_manualClose) {
        await _tearDownClient();

        if (!_manualClose) unawaited(connect());
      }

      return false;
    }
  }

  Future<void> flushPendingLocations() => _flushOfflineQueue();

  Future<void> _connectImpl() async {
    if (_connecting || isConnected) return;

    if (!await PatrolTrackingConfigStore.socketEnabled()) return;

    if (!_runsInFgs && await PatrolTrackingConfigStore.backgroundEnabled()) {
      return;
    }

    final url = AppConfig.effectiveStompEndpointUrl;

    if (url.isEmpty) return;

    final bearer = await AccountSessionStore.instance.getStoredAccessToken();

    if (bearer == null || bearer.isEmpty) return;

    _connecting = true;

    _manualClose = false;

    try {
      await _tearDownClient();

      late final StompClient client;

      client = StompClient(
        config: StompConfig.sockJS(
          url: url,
          reconnectDelay: const Duration(seconds: 5),
          webSocketConnectHeaders: <String, dynamic>{
            'Authorization': 'Bearer $bearer',
          },
          stompConnectHeaders: <String, String>{
            'Authorization': 'Bearer $bearer',

            'accept-version': '1.1,1.2',

            'heart-beat': '0,0',
          },

          onConnect: (frame) => _onStompConnect(client, frame),

          onWebSocketDone: _onTransportClosed,

          onWebSocketError: (_) => _onTransportClosed(),

          onStompError: (_) => _onTransportClosed(),

          onDisconnect: (_) {},
        ),
      );

      _client = client;

      client.activate();
    } catch (_) {
      //
    } finally {
      _connecting = false;
    }
  }

  void _onStompConnect(StompClient connectedClient, StompFrame frame) {
    if (!identical(_client, connectedClient)) return;

    if (_runsInFgs) {
      _invokeMain(PatrolFgsInvokeEvents.socketConnected);

      connectedClient.subscribe(
        destination: AppConfig.stompMockLocationAlertDestination,

        callback: (_) => _invokeMain(PatrolFgsInvokeEvents.mockLocationAlert),
      );

      connectedClient.subscribe(
        destination: AppConfig.stompActiveRoundChangedDestination,

        callback: _onActiveRoundChangedFrame,
      );

      unawaited(_flushOfflineQueue());

      return;
    }

    PatrolTrackSocketDispatch.onSocketConnected?.call();

    connectedClient.subscribe(
      destination: AppConfig.stompMockLocationAlertDestination,

      callback: _onMockAlertFrame,
    );

    connectedClient.subscribe(
      destination: AppConfig.stompActiveRoundChangedDestination,

      callback: _onActiveRoundChangedFrame,
    );
  }

  void _onActiveRoundChangedFrame(StompFrame frame) {
    if (_runsInFgs) {
      unawaited(_syncActiveRoundInFgs());

      return;
    }

    PatrolTrackSocketDispatch.onActiveRoundChanged?.call();
  }

  Future<void> _syncActiveRoundInFgs() async {
    try {
      final r = await PatrolActiveRoundSync.fetchAndPersist();
      if (!r.ok) return;

      await _onFgsRoundSynced?.call();

      _invokeMain(PatrolFgsInvokeEvents.activeRoundChanged);
    } catch (_) {
      //
    }
  }

  void _invokeMain(String event) {
    final service = _fgsService;

    if (service == null) return;

    try {
      service.invoke(event);
    } catch (_) {
      //
    }
  }

  void _onMockAlertFrame(StompFrame frame) {
    if (!_isMockLocationAlertFrame(frame)) return;

    onMockLocationAlert?.call();
  }

  bool _isMockLocationAlertFrame(StompFrame frame) {
    final body = frame.body?.trim();

    if (body == null || body.isEmpty) return true;

    try {
      final decoded = jsonDecode(body);

      if (decoded is Map &&
          decoded['event'] != null &&
          decoded['event'] != 'mock_location_alert') {
        return false;
      }
    } catch (_) {
      //
    }

    return true;
  }

  void _onTransportClosed() {
    if (_manualClose) return;
  }

  Future<void> _flushOfflineQueue() async {
    if (!isConnected) return;

    final pending = await PatrolTrackOfflineQueue.drainAll();

    for (final item in pending) {
      if (item.isMocked) continue;

      final ok = await sendTrackLocation(item, reconnectOnFailure: false);

      if (!ok) {
        await PatrolTrackOfflineQueue.enqueue(item);

        break;
      }
    }
  }

  Future<void> _tearDownClient() async {
    final client = _client;

    _client = null;

    client?.deactivate();
  }
}
