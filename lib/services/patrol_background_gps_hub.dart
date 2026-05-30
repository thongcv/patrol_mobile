import 'dart:async';

import '../utils/device_location.dart';
import '../utils/super_gps_service.dart';
import 'patrol_tracking_config_store.dart';

typedef PatrolBackgroundGpsHandler = void Function(SuperGpsEvent event);

/// Single Super GPS stream in FGS — fan-out to track emit and auto-scan separately.
class PatrolBackgroundGpsHub {
  PatrolBackgroundGpsHub();

  StreamSubscription<SuperGpsEvent>? _gpsSub;
  var _enableBarometer = false;
  var _scanWantsBarometer = false;
  var _listening = false;
  var _stopped = true;
  double _minMoveM = 5.0;

  PatrolBackgroundGpsHandler? autoScanHandler;
  PatrolBackgroundGpsHandler? trackHandler;

  bool get isListening => _listening;
  bool get hasAutoScanHandler => autoScanHandler != null;

  /// Starts or reconfigures GPS when either handler is set; stops when both are null.
  Future<void> ensureRunning({bool? scanWantsBarometer}) async {
    if (scanWantsBarometer != null) {
      _scanWantsBarometer = scanWantsBarometer;
    }
    if (autoScanHandler == null && trackHandler == null) {
      await stop();
      return;
    }

    final needsBaro = _scanWantsBarometer;
    final optionsChanged = _listening && _enableBarometer != needsBaro;
    _enableBarometer = needsBaro;

    if (_listening && !optionsChanged) return;

    _stopped = false;
    await _cancelSubscription();

    final denied = await checkPatrolBackgroundLocationForTracking();
    if (denied != null) return;

    if (!SuperGpsService.isSupported) return;

    _minMoveM = await PatrolTrackingConfigStore.minMoveM();

    SuperGpsService.configureStream(
      SuperGpsStreamOptions(
        updateIntervalMs: 1000,
        minUpdateIntervalMs: 800,
        minUpdateDistanceMeters: _minMoveM.round(),
        enableBarometer: needsBaro,
      ),
    );

    _gpsSub = SuperGpsService.instance.locationEventStream.listen(
      _dispatchEvent,
      onError: (Object error, StackTrace stack) {},
      cancelOnError: false,
    );

    _listening = true;
  }

  Future<void> stop() async {
    _stopped = true;
    autoScanHandler = null;
    trackHandler = null;
    _scanWantsBarometer = false;
    _enableBarometer = false;
    await _cancelSubscription();
    await SuperGpsService.shutdown();
  }

  Future<void> _cancelSubscription() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
    _listening = false;
  }

  void _dispatchEvent(SuperGpsEvent event) {
    if (_stopped) return;
    // Auto-scan before track so proximity is not delayed by STOMP emit.
    autoScanHandler?.call(event);
    if (_stopped) return;
    trackHandler?.call(event);
  }
}
