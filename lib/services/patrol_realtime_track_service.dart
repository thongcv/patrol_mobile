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



/// Coordinates realtime positioning: Super GPS + STOMP/SockJS + offline queue.

class PatrolRealtimeTrackService {

  PatrolRealtimeTrackService._();

  static final PatrolRealtimeTrackService instance = PatrolRealtimeTrackService._();

  static const double _minMoveM = 5.0;

  StreamSubscription<SuperGpsEvent>? _gpsSub;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<void>? _serverMockAlertSub;

  int? _roundId;

  bool _emitEnabled = false;

  final StreamController<bool> _mockViolation = StreamController<bool>.broadcast();

  /// `true` when mock GPS is detected — UI shows a red warning.
  Stream<bool> get mockViolationAlerts => _mockViolation.stream;

  bool get isTrackingRound => _emitEnabled && _roundId != null;

  Future<void> onAuthenticated() async {

    await PatrolTrackSocketClient.instance.connect();

    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((_) {
      unawaited(PatrolTrackSocketClient.instance.connect());

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

    await PatrolTrackSocketClient.instance.connect();

    await PatrolBackgroundService.startPatrolTracking();

    var bgRunning = await FlutterBackgroundService().isRunning();
    if (!bgRunning) {
      for (var i = 0; i < 30 && !bgRunning; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        bgRunning = await FlutterBackgroundService().isRunning();
      }
    }

    if (!bgRunning) {
      await _startForegroundGpsFanOut();
    } else {
      await _gpsSub?.cancel();
      _gpsSub = null;
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

    await PatrolBackgroundService.stopPatrolTracking();

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

    await PatrolTrackSocketClient.instance.disconnect();

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(StorageKeys.patrolTrackRoundId);

    await prefs.remove(StorageKeys.patrolTrackEmitEnabled);

  }

  Future<void> _startForegroundGpsFanOut() async {

    await _gpsSub?.cancel();

    if (!_emitEnabled || _roundId == null) return;

    if (!SuperGpsService.isSupported) return;

    _gpsSub = listenDeviceGpsForMap(
      minMoveM: _minMoveM,
      streamOptions: const SuperGpsStreamOptions(
        updateIntervalMs: 1000,
        minUpdateIntervalMs: 800,
        minUpdateDistanceMeters: 5,
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

