import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import 'patrol_background_isolate_flags.dart';
import 'patrol_fgs_invoke_events.dart';

/// FGS isolate ↔ main cross-isolate invoke and shared runtime state.
abstract final class PatrolFgsIsolateBridge {
  PatrolFgsIsolateBridge._();

  static ServiceInstance? _backgroundServiceInstance;
  static void Function(String checkpointName)? _relayCheckpointSuccessToUi;

  /// True while the background-service isolate is running patrol tracking.
  static bool get isBackgroundIsolate => PatrolBackgroundIsolateFlags.active;

  static ServiceInstance? get backgroundServiceInstance =>
      _backgroundServiceInstance;

  static void attachBackgroundService(ServiceInstance service) {
    _backgroundServiceInstance = service;
    PatrolBackgroundIsolateFlags.active = true;
  }

  static void detachBackgroundService() {
    _backgroundServiceInstance = null;
    PatrolBackgroundIsolateFlags.active = false;
    _relayCheckpointSuccessToUi = null;
  }

  /// Called from [PatrolBackgroundRunner] when a checkpoint is auto-scanned in FGS.
  static void setRelayCheckpointSuccess(void Function(String name)? handler) {
    _relayCheckpointSuccessToUi = handler;
  }

  static void relayCheckpointSuccessToUi(String checkpointName) =>
      _relayCheckpointSuccessToUi?.call(checkpointName);

  /// Local mock GPS in FGS — relays to UI via [mockLocationAlert] (same as STOMP).
  static void notifyMockLocationFromFgs() {
    try {
      _backgroundServiceInstance?.invoke(
        PatrolFgsInvokeEvents.mockLocationAlert,
      );
    } on MissingPluginException {
      //
    } on PlatformException {
      //
    }
  }

  /// Throttled GPS sample from FGS — map/UI on main isolate (not STOMP).
  static void notifyPositionUpdateFromFgs(Position position) {
    if (position.isMocked) return;
    try {
      _backgroundServiceInstance?.invoke(
        PatrolFgsInvokeEvents.positionUpdate,
        {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': position.timestamp.millisecondsSinceEpoch,
          'accuracy': position.accuracy,
        },
      );
    } on MissingPluginException {
      //
    } on PlatformException {
      //
    }
  }
}
