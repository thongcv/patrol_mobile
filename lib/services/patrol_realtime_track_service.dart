import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import '../models/patrol_location_track_payload.dart';
import '../utils/device_location.dart';
import '../utils/super_gps_service.dart';

import 'patrol_background_service.dart';
import 'patrol_track_offline_queue.dart';
import 'patrol_track_socket_client.dart';
import 'patrol_tracking_config_store.dart';

/// Coordinates realtime positioning: Super GPS + STOMP/SockJS + offline queue.
class PatrolRealtimeTrackService {
  PatrolRealtimeTrackService._();
  static final PatrolRealtimeTrackService instance = PatrolRealtimeTrackService._();

  StreamSubscription<SuperGpsEvent>? _gpsSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  int? _roundId;
  bool _sessionTrackingActive = false;
  bool _socketEnabled = true;
  bool _backgroundEnabled = false;

  final StreamController<bool> _mockViolation = StreamController<bool>.broadcast();

  /// `true` when mock GPS is detected — UI shows a red warning.
  Stream<bool> get mockViolationAlerts => _mockViolation.stream;

  bool get isSessionTracking => _sessionTrackingActive;

  /// `true` when GPS emit is on and an active patrol round id is set (socket sync).
  bool get isTrackingRound => _sessionTrackingActive && _roundId != null;

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
      if (_sessionTrackingActive) {
        unawaited(_connectTrackingSocket());
      }
    });

    PatrolTrackSocketClient.instance.onMockLocationAlert =
        notifyServerMockLocationAlert;
  }

  /// Server STOMP mock-GPS alert from the main socket.
  void notifyServerMockLocationAlert() {
    if (!_mockViolation.isClosed) _mockViolation.add(true);
  }

  /// Bật GPS + socket + FGS khi có phiên — không phụ thuộc vòng tuần tra.
  Future<void> startSessionTracking() async {
    if (_sessionTrackingActive) {
      await refreshActiveTracking();
      return;
    }

    _sessionTrackingActive = true;
    await _refreshTrackingConfigCache();
    if (_backgroundEnabled) {
      // Start FGS as early as possible so status-bar notification appears sooner.
      unawaited(PatrolBackgroundService.startPatrolTracking());
    }

    final prefs = await SharedPreferences.getInstance();
    await Future.wait<void>([
      prefs.setBool(StorageKeys.patrolTrackEmitEnabled, true),
      prefs.setBool(StorageKeys.patrolTrackBackgroundAutoScanEnabled, false),
      prefs.setBool(StorageKeys.patrolTrackForegroundScanBusy, false),
    ]);
    if (_roundId != null) {
      await prefs.setInt(StorageKeys.patrolTrackRoundId, _roundId!);
    }
    await _refreshTrackingConfigCache();

    if (_socketEnabled) {
      unawaited(_connectTrackingSocket());
    }

    await _ensureGpsPipeline();
  }

  /// Main STOMP when not using FGS; FGS isolate STOMP when background mode is on.
  Future<void> _connectTrackingSocket() async {
    if (_backgroundEnabled) {
      await PatrolTrackSocketClient.instance.disconnect();
      if (await PatrolBackgroundService.isRunningSafe()) {
        await PatrolBackgroundService.refreshPatrolTracking();
      } else {
        unawaited(PatrolBackgroundService.startPatrolTracking());
      }
      return;
    }
    await PatrolTrackSocketClient.instance.connect();
  }

  /// Đọc `roundId` / auto-scan từ prefs ([PatrolActiveRoundSync]) rồi bật GPS hoặc FGS.
  Future<void> syncTrackingAfterRoundPersisted() async {
    if (!_sessionTrackingActive) return;

    final prefs = await SharedPreferences.getInstance();
    final roundId = prefs.getInt(StorageKeys.patrolTrackRoundId);
    _roundId = (roundId != null && roundId > 0) ? roundId : null;

    await _refreshTrackingConfigCache();
    if (_backgroundEnabled) {
      unawaited(_refreshBackgroundAfterRoundUpdate());
      return;
    }
    await _startForegroundGpsFanOut();
  }

  Future<void> _refreshBackgroundAfterRoundUpdate() async {
    await PatrolBackgroundService.refreshPatrolTracking(
      startIfNotRunning: true,
    );
    if (!await PatrolBackgroundService.isRunningSafe()) {
      await _startForegroundGpsFanOut();
    }
  }

  Future<void> stopSessionTracking() async {
    _sessionTrackingActive = false;
    _roundId = null;

    await _gpsSub?.cancel();
    _gpsSub = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.patrolTrackEmitEnabled, false);
    await prefs.setBool(StorageKeys.patrolTrackBackgroundAutoScanEnabled, false);
    await prefs.setBool(StorageKeys.patrolTrackForegroundScanBusy, false);
    await prefs.remove(StorageKeys.patrolTrackRoundId);

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

    // Start foreground GPS immediately for first fixes, then hand off to FGS.
    await _startForegroundGpsFanOut();
    unawaited(_handOffToBackgroundIfEnabled(waitForStart: true));
  }

  /// Returns `true` when GPS runs in FGS (foreground subscription cancelled).
  Future<bool> _handOffToBackgroundIfEnabled({bool waitForStart = false}) async {
    await _refreshTrackingConfigCache();
    if (!_backgroundEnabled) return false;

    try {
      if (await PatrolBackgroundService.isRunningSafe()) {
        await PatrolBackgroundService.refreshPatrolTracking();
        await _gpsSub?.cancel();
        _gpsSub = null;
        return true;
      }

      unawaited(PatrolBackgroundService.startPatrolTracking());
      if (!waitForStart) return false;

      for (var i = 0; i < 15; i++) {
        if (await PatrolBackgroundService.isRunningSafe()) {
          await _gpsSub?.cancel();
          _gpsSub = null;
          return true;
        }
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    } catch (_) {
    }
    return false;
  }

  /// Pauses background auto-scan while the user uses the four scan buttons on the round screen.
  ///
  /// Socket tracking continues.
  Future<void> setForegroundRoundScanBusy(bool busy) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.patrolTrackForegroundScanBusy, busy);

    if (!_sessionTrackingActive) return;

    if (busy) {
      await PatrolBackgroundService.pauseBackgroundAutoScan();
    } else {
      await PatrolBackgroundService.resumeBackgroundAutoScan();
    }
  }

  Future<void> onSessionEnded() async {
    await stopSessionTracking();

    await _connectivitySub?.cancel();
    _connectivitySub = null;

    PatrolTrackSocketClient.instance.onMockLocationAlert = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.patrolTrackRoundId);
    await prefs.remove(StorageKeys.patrolTrackEmitEnabled);
  }

  Future<void> _startForegroundGpsFanOut() async {
    await _gpsSub?.cancel();

    if (!_sessionTrackingActive) return;
    if (!SuperGpsService.isSupported) return;

    final minMoveM = await PatrolTrackingConfigStore.minMoveM();

    _gpsSub = listenDeviceGpsForMap(
      minMoveM: minMoveM,
      streamOptions: SuperGpsStreamOptions(
        updateIntervalMs: 1000,
        minUpdateIntervalMs: 800,
        minUpdateDistanceMeters: minMoveM.round(),
        enableBarometer: false,
      ),
      onPosition: (position) {
        unawaited(_handlePosition(position));
      },
    );
  }

  Future<void> handlePositionFromBackground(Position position) async {
    final prefs = await SharedPreferences.getInstance();
    final emit = prefs.getBool(StorageKeys.patrolTrackEmitEnabled) ?? false;
    if (!emit) return;

    final roundId = prefs.getInt(StorageKeys.patrolTrackRoundId);
    if (roundId == null) return;

    await _dispatchPosition(roundId: roundId, position: position);
  }

  Future<void> _handlePosition(Position position) async {
    if (!_sessionTrackingActive) return;

    final roundId = _roundId;
    if (roundId == null) return;

    await _dispatchPosition(roundId: roundId, position: position);
  }

  Future<void> _dispatchPosition({
    required int roundId,
    required Position position,
  }) async {
    if (position.isMocked) {
      if (!_mockViolation.isClosed) _mockViolation.add(true);
      return;
    }

    if (!_socketEnabled) return;

    final payload = PatrolLocationTrackPayload.fromPosition(
      roundId: roundId,
      position: position,
    );

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
