import 'dart:async';

import 'dart:convert';

import 'package:flutter_background_service/flutter_background_service.dart';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../config/app_config.dart';

import '../models/patrol_location_track_payload.dart';

import '../http/patrol_cookie_jar.dart';
import '../http/patrol_dio.dart';
import '../http/patrol_session_refresh.dart';

import 'patrol_active_round_sync.dart';

import '../background/patrol_background_isolate_flags.dart';

import '../background/patrol_fgs_invoke_events.dart';

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

  Future<void>? _reconnectFuture;

  ServiceInstance? _fgsService;

  Future<void> Function()? _onFgsRoundSynced;

  Future<void> Function()? _onFgsConfigUpdated;

  bool get isConnected => _client?.connected ?? false;

  bool get _runsInFgs =>
      PatrolBackgroundIsolateFlags.active || _fgsService != null;


  /// Main isolate — mock GPS alert từ STOMP (không dùng khi FGS owns socket).

  void Function()? onMockLocationAlert;

  /// Call once from [patrolBackgroundOnStart] before [connect].

  void configureFgsBridge({
    required ServiceInstance service,

    required Future<void> Function() onRoundSynced,

    required Future<void> Function() onConfigUpdated,
  }) {
    _fgsService = service;

    _onFgsRoundSynced = onRoundSynced;

    _onFgsConfigUpdated = onConfigUpdated;
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
        unawaited(_reconnectAfterFailure());
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

    await PatrolDio.ensureReady();

    if (!await PatrolSessionRefresh.ensureFreshForSocket()) return;

    final auth = await PatrolCookieJar.stompAuthHeaders();
    if (auth == null) return;

    final reconnectSec =
        (await PatrolTrackingConfigStore.load()).socketReconnectSec;

    final webSocketHeaders = <String, dynamic>{};
    final stompHeaders = <String, String>{};
    _applyStompAuthHeaders(auth, webSocketHeaders, stompHeaders);

    _connecting = true;

    _manualClose = false;

    try {
      await _tearDownClient();

      late final StompClient client;

      client = StompClient(
        config: StompConfig.sockJS(
          url: url,
          reconnectDelay: Duration(seconds: reconnectSec),
          webSocketConnectHeaders: webSocketHeaders,
          stompConnectHeaders: stompHeaders,
          beforeConnect: () => _refreshStompHeaders(
            webSocketHeaders,
            stompHeaders,
          ),

          onConnect: (frame) => _onStompConnect(client, frame),

          onWebSocketDone: _onTransportClosed,

          onWebSocketError: (_) => _onTransportClosed(),

          onStompError: (frame) => unawaited(_onStompError(frame)),

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

    try {
      _subscribeAll(connectedClient);
    } catch (_) {
      unawaited(_reconnectAfterFailure());
      return;
    }

    if (_runsInFgs) {
      _invokeMain(PatrolFgsInvokeEvents.socketConnected);
      unawaited(_flushOfflineQueue());
      return;
    }

    PatrolTrackSocketDispatch.onSocketConnected?.call();
  }

  void _subscribeAll(StompClient client) {
    client.subscribe(
      destination: AppConfig.stompMockLocationAlertDestination,
      callback: _runsInFgs
          ? (_) => _invokeMain(PatrolFgsInvokeEvents.mockLocationAlert)
          : _onMockAlertFrame,
    );

    client.subscribe(
      destination: AppConfig.stompActiveRoundChangedDestination,
      callback: _onActiveRoundChangedFrame,
    );

    client.subscribe(
      destination: AppConfig.stompTrackingConfigChangedDestination,
      callback: _onTrackingConfigChangedFrame,
    );
  }

  void _onTrackingConfigChangedFrame(StompFrame frame) {
    unawaited(_handleTrackingConfigChangedFrame(frame));
  }

  Future<void> _handleTrackingConfigChangedFrame(StompFrame frame) async {
    final updated = await _applyConfigFromActiveRoundFrame(frame);
    if (!updated) return;
    if (_runsInFgs) {
      unawaited(_onFgsConfigUpdated?.call());
      _invokeMain(PatrolFgsInvokeEvents.trackingConfigChanged);
      return;
    }
    PatrolTrackSocketDispatch.onTrackingConfigChanged?.call();
  }
  void _onActiveRoundChangedFrame(StompFrame frame) {
    if (_runsInFgs) {
      unawaited(_syncActiveRoundInFgs());
      return;
    }
    PatrolTrackSocketDispatch.onActiveRoundChanged?.call();
  }

  Future<bool> _applyConfigFromActiveRoundFrame(StompFrame frame) async {
    final body = frame.body?.trim();
    if (body == null || body.isEmpty) return false;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return false;
      final result = await PatrolTrackingConfigStore.applyFromActiveRoundFrame(
        Map<String, dynamic>.from(decoded),
      );
      return result?.updated ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncActiveRoundInFgs() async {
    try {
      await PatrolDio.ensureReady();
      final r = await PatrolActiveRoundSync.fetchAndPersist();
      if (!r.ok) return;

      await _onFgsRoundSynced?.call();

      _invokeMain(
        PatrolFgsInvokeEvents.activeRoundChanged,
        const {'fullSync': true},
      );
    } catch (_) {
      //
    }
  }

  void _invokeMain(String event, [Map<String, dynamic>? data]) {
    final service = _fgsService;

    if (service == null) return;

    try {
      service.invoke(event, data);
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

  Future<void> _onStompError(StompFrame frame) async {
    await _reconnectAfterFailure(
      forceRefresh: _isAuthStompError(frame),
    );
  }

  /// SUBSCRIBE / STOMP ERROR auth failure — same recovery as [sendTrackLocation].
  Future<void> _reconnectAfterFailure({bool forceRefresh = false}) async {
    if (_manualClose) return;

    final inFlight = _reconnectFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _reconnectAfterFailureImpl(forceRefresh: forceRefresh);
    _reconnectFuture = future;
    try {
      await future;
    } finally {
      if (identical(_reconnectFuture, future)) {
        _reconnectFuture = null;
      }
    }
  }

  Future<void> _reconnectAfterFailureImpl({required bool forceRefresh}) async {
    if (_manualClose) return;

    await _tearDownClient();
    if (_manualClose) return;

    await PatrolSessionRefresh.ensureFreshForSocket(force: forceRefresh);
    if (_manualClose) return;

    await connect();
  }

  static bool _isAuthStompError(StompFrame frame) {
    final parts = <String>[
      frame.body ?? '',
      frame.headers['message'] ?? '',
    ];
    final text = parts.join(' ').toLowerCase();
    return text.contains('401') ||
        text.contains('403') ||
        text.contains('unauthorized') ||
        text.contains('forbidden') ||
        text.contains('expired') ||
        text.contains('access_token') ||
        text.contains('access token');
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

  static void _applyStompAuthHeaders(
    PatrolStompAuthHeaders auth,
    Map<String, dynamic> webSocketHeaders,
    Map<String, String> stompHeaders,
  ) {
    webSocketHeaders
      ..clear()
      ..addAll(auth.webSocketConnectHeaders);
    stompHeaders
      ..clear()
      ..addAll(auth.stompConnectHeaders);
  }

  /// Runs before every SockJS/WebSocket attempt (including library auto-reconnect).
  static Future<void> _refreshStompHeaders(
    Map<String, dynamic> webSocketHeaders,
    Map<String, String> stompHeaders,
  ) async {
    if (!await PatrolSessionRefresh.ensureFreshForSocket()) return;

    final auth = await PatrolCookieJar.stompAuthHeaders();
    if (auth == null) return;

    _applyStompAuthHeaders(auth, webSocketHeaders, stompHeaders);
  }
}
