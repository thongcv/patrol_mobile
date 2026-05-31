import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:geolocator/geolocator.dart';

import '../models/patrol_location_track_payload.dart';

import '../utils/device_location.dart';

import '../utils/super_gps_service.dart';

import 'patrol_active_round_cache.dart';
import '../background/patrol_background_service.dart';

import 'patrol_track_offline_queue.dart';

import 'patrol_active_round_sync.dart';
import 'patrol_track_socket_client.dart';

import 'patrol_tracking_config_store.dart';

/// Coordinates realtime positioning: Super GPS + STOMP/SockJS + offline queue.

class PatrolRealtimeTrackService {
  PatrolRealtimeTrackService._();

  static final PatrolRealtimeTrackService instance =
      PatrolRealtimeTrackService._();

  StreamSubscription<SuperGpsEvent>? _gpsSub;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  Timer? _connectivityReconnectDebounce;

  Future<void>? _startSessionChain;

  bool _sessionTrackingActive = false;

  bool _socketEnabled = true;

  bool _backgroundEnabled = false;

  final StreamController<bool> _mockViolation =
      StreamController<bool>.broadcast();

  final StreamController<Position> _uiPositionUpdates =
      StreamController<Position>.broadcast();

  Position? _lastKnownUiPosition;

  /// `true` when mock GPS is detected — UI shows a red warning.

  Stream<bool> get mockViolationAlerts => _mockViolation.stream;

  /// Last throttled GPS sample from session tracking (main or FGS relay).
  Stream<Position> get positionUpdates => _uiPositionUpdates.stream;

  Position? get lastKnownPosition => _lastKnownUiPosition;

  bool get isSessionTracking => _sessionTrackingActive;

  /// Re-attach GPS after location permission / background service is ready.

  Future<void> refreshActiveTracking() async {
    if (!_sessionTrackingActive) return;

    await _refreshTrackingConfigCache();

    if (_socketEnabled) {
      unawaited(_connectTrackingSocket());
    }

    if (await _handOffToBackgroundIfEnabled()) return;

    await _startForegroundGpsFanOut();
  }

  Future<void> onAuthenticated() async {
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((_) {
      if (!_sessionTrackingActive) return;

      _connectivityReconnectDebounce?.cancel();

      _connectivityReconnectDebounce = Timer(
        const Duration(seconds: 2),

        () => unawaited(_onConnectivityRestored()),
      );
    });

    PatrolTrackSocketClient.instance.onMockLocationAlert =
        notifyServerMockLocationAlert;
  }

  /// Server STOMP mock-GPS alert from the main socket.

  void notifyServerMockLocationAlert() {
    if (!_mockViolation.isClosed) _mockViolation.add(true);
  }

  /// Bật GPS + socket + FGS khi có phiên — không phụ thuộc vòng tuần tra.
  ///
  /// Serialized — [PatrolSessionListen.resumeIfSession] may run more than once
  /// (attach + location gate). Re-entry must re-bootstrap FGS/GPS, not only refresh.

  Future<void> startSessionTracking() {
    _startSessionChain =
        (_startSessionChain ?? Future<void>.value()).then((_) => _startSessionTrackingImpl());
    return _startSessionChain!;
  }

  Future<void> _startSessionTrackingImpl() async {
    _sessionTrackingActive = true;

    await _refreshTrackingConfigCache();

    await Future.wait<void>([
      PatrolActiveRoundCache.setTrackEmitEnabled(true),
      PatrolActiveRoundCache.setForegroundScanBusy(false),
      PatrolActiveRoundSync.clearBackgroundAutoScanArmed(),
    ]);
    // Round cache from GET; auto-scan armed only via STOMP active-round-changed.

    await _refreshTrackingConfigCache();

    if (_backgroundEnabled) {
      if (!await PatrolBackgroundService.isRunningSafe()) {
        unawaited(PatrolBackgroundService.startPatrolTracking());
      }
    }

    if (_socketEnabled) {
      unawaited(_connectTrackingSocket());
    }

    await _ensureGpsPipeline();
  }

  Future<void> _onConnectivityRestored() async {
    if (!_sessionTrackingActive) return;

    await _refreshTrackingConfigCache();

    if (_backgroundEnabled) {
      // FGS STOMP auto-reconnects; only start FGS if it dropped entirely.

      if (await PatrolBackgroundService.isRunningSafe()) return;

      unawaited(
        PatrolBackgroundService.refreshPatrolTracking(startIfNotRunning: true),
      );

      return;
    }

    if (_socketEnabled) {
      await _connectTrackingSocket();
    }
  }

  /// Main STOMP when not using FGS; FGS isolate STOMP when background mode is on.

  Future<void> _connectTrackingSocket() async {
    if (_backgroundEnabled) {
      await PatrolTrackSocketClient.instance.disconnect();
      if (!await PatrolBackgroundService.isRunningSafe()) {
        unawaited(PatrolBackgroundService.startPatrolTracking());
      }
      return;
    }

    await PatrolTrackSocketClient.instance.connect();
  }

  /// Refresh FGS/GPS sau khi [PatrolActiveRoundSync] persist (auto-scan prefs).

  Future<void> syncTrackingAfterRoundPersisted() async {
    if (!_sessionTrackingActive) return;

    await _refreshTrackingConfigCache();

    if (_backgroundEnabled) {
      await _refreshBackgroundAfterRoundUpdate();

      return;
    }

    await _startForegroundGpsFanOut();
  }

  Future<void> _refreshBackgroundAfterRoundUpdate() async {
    await PatrolBackgroundService.refreshPatrolTracking(
      startIfNotRunning: true,
      afterRoundPersist: true,
    );

    if (!await PatrolBackgroundService.isRunningSafe()) {
      await _startForegroundGpsFanOut();
    }
  }

  Future<void> stopSessionTracking() async {
    _sessionTrackingActive = false;
    _startSessionChain = null;
    _lastKnownUiPosition = null;

    await _gpsSub?.cancel();

    _gpsSub = null;

    await PatrolActiveRoundCache.setTrackEmitEnabled(false);

    await PatrolActiveRoundSync.clearBackgroundAutoScanArmed();

    await PatrolActiveRoundCache.setForegroundScanBusy(false);

    await _refreshTrackingConfigCache();

    if (_backgroundEnabled) {
      // Re-read prefs in FGS (emit=false → stop GPS); full FGS stop on [onSessionEnded].

      await PatrolBackgroundService.refreshPatrolTracking();
    } else {
      await PatrolBackgroundService.stopPatrolTracking();
    }
  }

  Future<void> _ensureGpsPipeline() async {
    await _refreshTrackingConfigCache();

    if (!_backgroundEnabled) {
      await _startForegroundGpsFanOut();

      return;
    }

    // Background mode: FGS owns GPS + STOMP — main only starts/refreshes the service.
    await _cancelMainGps();

    if (await PatrolBackgroundService.isRunningSafe()) {
      return;
    }

    unawaited(PatrolBackgroundService.startPatrolTracking());

    for (var i = 0; i < 15; i++) {
      if (await PatrolBackgroundService.isRunningSafe()) return;
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    // FGS failed to start — fall back to foreground GPS on main.
    await _startForegroundGpsFanOut();
  }

  Future<void> _cancelMainGps() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
  }

  /// Returns `true` when GPS runs in FGS (foreground subscription cancelled).

  Future<bool> _handOffToBackgroundIfEnabled({
    bool waitForStart = false,
  }) async {
    await _refreshTrackingConfigCache();

    if (!_backgroundEnabled) return false;

    try {
      if (await PatrolBackgroundService.isRunningSafe()) {
        await _cancelMainGps();

        return true;
      }

      unawaited(PatrolBackgroundService.startPatrolTracking());

      if (!waitForStart) return false;

      for (var i = 0; i < 15; i++) {
        if (await PatrolBackgroundService.isRunningSafe()) {
          await _cancelMainGps();

          return true;
        }

        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    } catch (_) {}

    return false;
  }

  /// Pauses background auto-scan while the user uses the four scan buttons on the round screen.

  ///

  /// Socket tracking continues.

  Future<void> setForegroundRoundScanBusy(bool busy) async {
    final was = await PatrolActiveRoundCache.isForegroundScanBusy();
    if (was == busy) return;
    await PatrolActiveRoundCache.setForegroundScanBusy(busy);

    if (!_sessionTrackingActive) return;

    if (busy) {
      await PatrolBackgroundService.pauseBackgroundAutoScan();
    } else {
      await PatrolBackgroundService.resumeBackgroundAutoScan();
    }
  }

  /// Clears foreground busy and invokes FGS resume even if already not busy.
  Future<void> forceResumeBackgroundAutoScan() async {
    await PatrolActiveRoundCache.setForegroundScanBusy(false);
    await PatrolActiveRoundSync.armBackgroundAutoScanIfConfigured();
    if (!_sessionTrackingActive) return;
    await PatrolBackgroundService.resumeBackgroundAutoScan();
  }

  Future<void> onSessionEnded() async {
    await stopSessionTracking();

    _connectivityReconnectDebounce?.cancel();

    _connectivityReconnectDebounce = null;

    await _connectivitySub?.cancel();

    _connectivitySub = null;

    PatrolTrackSocketClient.instance.onMockLocationAlert = null;

    await PatrolActiveRoundCache.clearTrackEmitEnabled();
  }

  Future<void> _startForegroundGpsFanOut() async {
    await _gpsSub?.cancel();

    if (!_sessionTrackingActive) return;

    if (!SuperGpsService.isSupported) return;

    final config = await PatrolTrackingConfigStore.load();
    final enableBarometer =
        await SuperGpsService.isBarometerHardwareSupported();
    _gpsSub = listenDeviceGpsForMap(
      minMoveM: config.minMoveM,
      streamOptions: SuperGpsStreamOptions(
        updateIntervalMs: config.updateIntervalMs,
        minUpdateIntervalMs: config.minUpdateIntervalMs,
        minUpdateDistanceMeters: config.minMoveM.round(),
        enableBarometer: enableBarometer,
      ),
      onPosition: (position) {
        unawaited(_handlePosition(position));
      },
    );
  }

  Future<void> handlePositionFromBackground(Position position) async {
    if (!await PatrolActiveRoundCache.isTrackEmitEnabled()) return;

    await _dispatchPosition(position);
  }

  Future<void> _handlePosition(Position position) async {
    if (!_sessionTrackingActive) return;

    _publishUiPosition(position);
    await _dispatchPosition(position);
  }

  /// FGS isolate → main relay for map and other UI (STOMP already handled in FGS).
  void notifyPositionFromFgsRelay(dynamic payload) {
    if (!_sessionTrackingActive) return;
    if (payload is! Map) return;
    final map = Map<Object?, Object?>.from(payload);
    final lat = (map['latitude'] as num?)?.toDouble();
    final lng = (map['longitude'] as num?)?.toDouble();
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite) {
      return;
    }
    final tsMs = (map['timestamp'] as num?)?.toInt();
    final accuracy = (map['accuracy'] as num?)?.toDouble();
    _publishUiPosition(
      Position(
        latitude: lat,
        longitude: lng,
        timestamp: tsMs != null
            ? DateTime.fromMillisecondsSinceEpoch(tsMs)
            : DateTime.now(),
        accuracy: accuracy != null && accuracy.isFinite
            ? accuracy
            : double.maxFinite,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      ),
    );
  }

  void _publishUiPosition(Position position) {
    if (position.isMocked) return;
    _lastKnownUiPosition = position;
    if (!_uiPositionUpdates.isClosed) {
      _uiPositionUpdates.add(position);
    }
  }

  Future<void> _dispatchPosition(Position position) async {
    if (position.isMocked) {
      if (PatrolBackgroundService.isBackgroundIsolate) {
        PatrolBackgroundService.notifyMockLocationFromFgs();
      } else if (!_mockViolation.isClosed) {
        _mockViolation.add(true);
      }
      return;
    }

    if (!_socketEnabled) return;

    final payload = PatrolLocationTrackPayload.fromPosition(position: position);

    // Background mode: FGS isolate owns GPS + STOMP — main must not enqueue here.

    if (_backgroundEnabled) {
      if (!PatrolBackgroundService.isBackgroundIsolate) return;
      if (await PatrolTrackSocketClient.instance.sendTrackLocation(payload)) {
        return;
      }
      await PatrolTrackOfflineQueue.enqueue(payload);

      return;
    }

    await PatrolTrackSocketClient.instance.sendTrackLocation(payload);
  }

  Future<void> _refreshTrackingConfigCache() async {
    final config = await PatrolTrackingConfigStore.load();

    _socketEnabled = config.socket;

    _backgroundEnabled = config.background;
  }
}
