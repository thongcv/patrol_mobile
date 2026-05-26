import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import '../models/patrol_location_track_payload.dart';
import '../utils/device_location.dart';
import '../utils/super_gps_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

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
  StreamSubscription<void>? _serverMockAlertSub;

  int? _roundId;
  bool _emitEnabled = false;

  final StreamController<bool> _mockViolation = StreamController<bool>.broadcast();

  /// `true` when mock GPS is detected — UI shows a red warning.
  Stream<bool> get mockViolationAlerts => _mockViolation.stream;

  bool get isTrackingRound => _emitEnabled && _roundId != null;

  /// Re-attach GPS after location permission / background service is ready.
  Future<void> refreshActiveTracking() async {
    if (!_emitEnabled || _roundId == null) return;

    if (await PatrolTrackingConfigStore.socketEnabled()) {
      await PatrolTrackSocketClient.instance.connect();
    }

    final background = await PatrolTrackingConfigStore.backgroundEnabled();
    if (background) {
      final flutterBg = FlutterBackgroundService();
      if (await flutterBg.isRunning()) {
        await PatrolBackgroundService.refreshPatrolTracking();
        await _gpsSub?.cancel();
        _gpsSub = null;
        return;
      }
      await PatrolBackgroundService.startPatrolTracking();
    }
    await _startForegroundGpsFanOut();
  }

  Future<void> onAuthenticated() async {
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((_) {
      if (isTrackingRound) {
        unawaited(PatrolTrackSocketClient.instance.connect());
      }
    });

    _serverMockAlertSub ??=
        PatrolTrackSocketClient.instance.mockLocationAlerts.listen((_) {
      if (!_mockViolation.isClosed) _mockViolation.add(true);
    });
  }

  /// Enables location emit when an active patrol round exists (foreground + background service).
  Future<void> startRoundTracking({required int roundId}) async {
    _roundId = roundId;
    _emitEnabled = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(StorageKeys.patrolTrackRoundId, roundId);
    await prefs.setBool(StorageKeys.patrolTrackEmitEnabled, true);
    await prefs.setBool(
      StorageKeys.patrolTrackBackgroundAutoScanEnabled,
      true,
    );

    if (await PatrolTrackingConfigStore.socketEnabled()) {
      await PatrolTrackSocketClient.instance.connect();
    }

    final background = await PatrolTrackingConfigStore.backgroundEnabled();
    if (background) {
      final flutterBg = FlutterBackgroundService();
      if (await flutterBg.isRunning()) {
        await PatrolBackgroundService.refreshPatrolTracking();
      } else {
        await PatrolBackgroundService.startPatrolTracking();
      }

      var bgRunning = await flutterBg.isRunning();
      if (!bgRunning) {
        for (var i = 0; i < 30 && !bgRunning; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          bgRunning = await flutterBg.isRunning();
        }
      }

      if (!bgRunning) {
        await _startForegroundGpsFanOut();
      } else {
        await _gpsSub?.cancel();
        _gpsSub = null;
      }
    } else {
      await _startForegroundGpsFanOut();
    }
  }

  Future<void> stopRoundTracking() async {
    _emitEnabled = false;
    _roundId = null;

    await _gpsSub?.cancel();
    _gpsSub = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.patrolTrackEmitEnabled, false);
    await prefs.setBool(StorageKeys.patrolTrackBackgroundAutoScanEnabled, false);
    await prefs.setBool(StorageKeys.patrolTrackForegroundScanBusy, false);
    await prefs.remove(StorageKeys.patrolTrackRoundId);

    if (await PatrolTrackingConfigStore.backgroundEnabled()) {
      // Re-read prefs in FGS (emit=false → stop GPS); full FGS stop on [onSessionEnded].
      await PatrolBackgroundService.refreshPatrolTracking();
    } else {
      await PatrolBackgroundService.stopPatrolTracking();
    }
  }

  /// Pauses background auto-scan while the user uses the four scan buttons on the round screen.
  ///
  /// Socket tracking continues.
  Future<void> setForegroundRoundScanBusy(bool busy) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.patrolTrackForegroundScanBusy, busy);

    if (!_emitEnabled) return;

    if (busy) {
      await PatrolBackgroundService.pauseBackgroundAutoScan();
    } else {
      await PatrolBackgroundService.resumeBackgroundAutoScan();
    }
  }

  Future<void> onSessionEnded() async {
    await stopRoundTracking();

    await _connectivitySub?.cancel();
    _connectivitySub = null;

    await _serverMockAlertSub?.cancel();
    _serverMockAlertSub = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.patrolTrackRoundId);
    await prefs.remove(StorageKeys.patrolTrackEmitEnabled);
  }

  Future<void> _startForegroundGpsFanOut() async {
    await _gpsSub?.cancel();

    if (!_emitEnabled || _roundId == null) return;
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
    if (!_emitEnabled) return;

    await _dispatchPosition(roundId: _roundId ?? 0, position: position);
  }

  Future<void> _dispatchPosition({
    required int roundId,
    required Position position,
  }) async {
    if (position.isMocked) {
      if (!_mockViolation.isClosed) _mockViolation.add(true);
      return;
    }

    if (!await PatrolTrackingConfigStore.socketEnabled()) return;

    final payload = PatrolLocationTrackPayload.fromPosition(
      roundId: roundId,
      position: position,
    );
    final sent = await PatrolTrackSocketClient.instance.sendTrackLocation(payload);
    if (!sent && kDebugMode) {
      final pending = await PatrolTrackOfflineQueue.pendingCount();
      debugPrint('Patrol track queued (offline). pending=$pending');
    }
  }
}
