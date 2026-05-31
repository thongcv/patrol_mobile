import 'dart:async';

import '../utils/device_location.dart';
import '../utils/super_gps_service.dart';
import 'patrol_tracking_config_store.dart';

typedef PatrolBackgroundGpsHandler = void Function(SuperGpsEvent event);

/// Single Super GPS stream in FGS — fan-out to track emit and auto-scan separately.
class PatrolBackgroundGpsHub {
  PatrolBackgroundGpsHub();

  StreamSubscription<SuperGpsEvent>? _gpsSub;
  var _scanWantsBarometer = false;
  var _listening = false;
  var _stopped = true;
  SuperGpsStreamOptions? _streamOptions;

  PatrolBackgroundGpsHandler? autoScanHandler;
  PatrolBackgroundGpsHandler? trackHandler;

  bool get isListening => _listening;
  bool get hasAutoScanHandler => autoScanHandler != null;

  /// Starts or reconfigures GPS when either handler is set; shuts down stream when both are null.
  ///
  /// [trackHandler] / [autoScanHandler] are owned by [PatrolBackgroundTrackEmitter] and
  /// [PatrolBackgroundAutoScan] — [stop] does not clear them (avoids wiping a handler
  /// another module just assigned before this call runs).
  Future<void> ensureRunning({bool? scanWantsBarometer}) async {
    if (scanWantsBarometer != null) {
      _scanWantsBarometer = scanWantsBarometer;
    }
    if (autoScanHandler == null && trackHandler == null) {
      _stopped = true;
      await _shutdownStream();
      return;
    }

    final denied = await checkPatrolBackgroundLocationForTracking();
    if (denied != null) return;

    if (!SuperGpsService.isSupported) return;

    final nextOptions = await _streamOptionsFromConfig(
      enableBarometer: _scanWantsBarometer,
    );

    if (_listening && _streamOptions != null) {
      final baroChanged = _streamOptions!.enableBarometer != nextOptions.enableBarometer;
      final streamParamsChanged = _streamParamsChanged(_streamOptions!, nextOptions);

      if (!baroChanged && !streamParamsChanged) return;

      if (!baroChanged && streamParamsChanged) {
        _streamOptions = nextOptions;
        SuperGpsService.configureStream(nextOptions);
        return;
      }
    }

    _stopped = false;
    await _cancelSubscription();

    _streamOptions = nextOptions;
    SuperGpsService.configureStream(nextOptions);

    _gpsSub = SuperGpsService.instance.locationEventStream.listen(
      _dispatchEvent,
      onError: (Object error, StackTrace stack) {},
      cancelOnError: false,
    );

    _listening = true;
  }

  /// Stops the GPS stream only — handlers are cleared by their owning modules.
  Future<void> stop() async {
    _stopped = true;
    _scanWantsBarometer = false;
    _streamOptions = null;
    await _shutdownStream();
  }

  Future<void> _shutdownStream() async {
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

  static bool _streamParamsChanged(
    SuperGpsStreamOptions current,
    SuperGpsStreamOptions next,
  ) {
    return current.updateIntervalMs != next.updateIntervalMs ||
        current.minUpdateIntervalMs != next.minUpdateIntervalMs ||
        current.minUpdateDistanceMeters != next.minUpdateDistanceMeters;
  }

  static Future<SuperGpsStreamOptions> _streamOptionsFromConfig({
    required bool enableBarometer,
  }) async {
    final config = await PatrolTrackingConfigStore.load();
    return SuperGpsStreamOptions(
      updateIntervalMs: config.updateIntervalMs,
      minUpdateIntervalMs: config.minUpdateIntervalMs,
      minUpdateDistanceMeters: config.minMoveM.round(),
      enableBarometer: enableBarometer,
    );
  }
}
