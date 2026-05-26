import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../config/app_config.dart';
import '../models/patrol_location_track_payload.dart';
import 'account_session_store.dart';
import 'patrol_track_offline_queue.dart';
import 'patrol_tracking_config_store.dart';

/// STOMP client over SockJS — matches Spring `addEndpoint("/notification").withSockJS()`.
///
/// Contract (backend should mirror):
/// - `@MessageMapping("/patrol/track-location")` ← `/app/patrol/track-location`
/// - Push mock GPS → `/user/queue/patrol/mock-location-alert`
/// - Active round changed → `/user/queue/patrol/active-round-changed`
class PatrolTrackSocketClient {
  PatrolTrackSocketClient._();

  static final PatrolTrackSocketClient instance = PatrolTrackSocketClient._();

  StompClient? _client;
  bool _connecting = false;
  bool _manualClose = false;

  final StreamController<bool> _connectionState =
      StreamController<bool>.broadcast();

  final StreamController<void> _mockLocationAlert =
      StreamController<void>.broadcast();

  final StreamController<void> _activeRoundChanged =
      StreamController<void>.broadcast();

  Stream<bool> get connectionChanges => _connectionState.stream;

  /// Server-pushed mock GPS alert (STOMP).
  Stream<void> get mockLocationAlerts => _mockLocationAlert.stream;

  /// Active patrol round changed — coordinator calls GET `/me/active`.
  Stream<void> get activeRoundSignals => _activeRoundChanged.stream;

  bool get isConnected => _client?.connected ?? false;

  /// Kết nối STOMP cho phiên đăng nhập (nhận vòng tuần tra + gửi vị trí khi emit bật).
  Future<void> connect() async {
    if (_connecting || isConnected) return;
    if (!await PatrolTrackingConfigStore.socketEnabled()) return;

    final url = AppConfig.effectiveStompEndpointUrl;
    if (url.isEmpty) return;

    final bearer = await AccountSessionStore.instance.getStoredAccessToken();
    if (bearer == null || bearer.isEmpty) return;

    _connecting = true;
    _manualClose = false;
    try {
      await _tearDownClient(notifyDisconnected: false);
      _client = StompClient(
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
          onConnect: _onStompConnect,
          onWebSocketDone: _onTransportClosed,
          onWebSocketError: (_) => _onTransportClosed(),
          onStompError: (_) => _onTransportClosed(),
          onDisconnect: (_) {
            if (!_connectionState.isClosed) _connectionState.add(false);
          },
        ),
      );
      _client!.activate();
    } catch (_) {
      if (!_connectionState.isClosed) _connectionState.add(false);
    } finally {
      _connecting = false;
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

  Future<bool> sendTrackLocation(PatrolLocationTrackPayload payload) async {
    if (payload.isMocked) return false;
    if (!await PatrolTrackingConfigStore.socketEnabled()) return false;
    if (!isConnected) {
      await PatrolTrackOfflineQueue.enqueue(payload);
      return false;
    }
    try {
      _client!.send(
        destination: AppConfig.stompTrackLocationDestination,
        body: jsonEncode(payload.toJson()),
        headers: <String, String>{'content-type': 'application/json'},
      );
      return true;
    } catch (_) {
      await PatrolTrackOfflineQueue.enqueue(payload);
      if (!_manualClose) {
        await _tearDownClient();
        if (!_manualClose) unawaited(connect());
      }
      return false;
    }
  }

  void _onStompConnect(StompFrame frame) {
    if (!_connectionState.isClosed) _connectionState.add(true);
    _client?.subscribe(
      destination: AppConfig.stompMockLocationAlertDestination,
      callback: _onMockAlertFrame,
    );
    _client?.subscribe(
      destination: AppConfig.stompActiveRoundChangedDestination,
      callback: _onActiveRoundChangedFrame,
    );
    unawaited(_flushOfflineQueue());
  }

  void _onActiveRoundChangedFrame(StompFrame frame) {
    if (_activeRoundChanged.isClosed) return;
    _activeRoundChanged.add(null);
  }

  void _onMockAlertFrame(StompFrame frame) {
    final body = frame.body?.trim();
    if (body != null && body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map &&
            decoded['event'] != null &&
            decoded['event'] != 'mock_location_alert') {
          return;
        }
      } catch (_) {
        //
      }
    }
    if (!_mockLocationAlert.isClosed) _mockLocationAlert.add(null);
  }

  void _onTransportClosed() {
    if (!_connectionState.isClosed) _connectionState.add(false);
    if (_manualClose) return;
    // stomp_dart_client reconnects on its own when _isActive; do not call connect() again.
  }

  Future<void> _flushOfflineQueue() async {
    final pending = await PatrolTrackOfflineQueue.drainAll();
    for (final item in pending) {
      if (item.isMocked) continue;
      final ok = await sendTrackLocation(item);
      if (!ok) break;
    }
  }

  Future<void> _tearDownClient({bool notifyDisconnected = true}) async {
    final client = _client;
    _client = null;
    client?.deactivate();
    if (notifyDisconnected && !_connectionState.isClosed) {
      _connectionState.add(false);
    }
  }

}
