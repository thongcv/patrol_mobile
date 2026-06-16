import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n/app_localizations.dart';
import '../services/app_locale_store.dart';
import '../services/patrol_foreground_notification.dart';
import '../utils/super_gps_service.dart';
import 'patrol_background_isolate_flags.dart';
import 'patrol_fgs_invoke_events.dart';

/// FGS isolate ↔ main cross-isolate invoke and shared runtime state.
abstract final class PatrolFgsIsolateBridge {
  PatrolFgsIsolateBridge._();

  static ServiceInstance? _backgroundServiceInstance;
  static void Function(String checkpointName)? _relayCheckpointSuccessToUi;
  static void Function(String message)? _relayProximityNavigationToUi;
  static Future<void> Function()? _onSessionExpiredInFgs;
  static var _sessionExpiredRelayed = false;

  /// True while the background-service isolate is running patrol tracking.
  static bool get isBackgroundIsolate => PatrolBackgroundIsolateFlags.active;

  static ServiceInstance? get backgroundServiceInstance =>
      _backgroundServiceInstance;

  static void attachBackgroundService(ServiceInstance service) {
    _backgroundServiceInstance = service;
    PatrolBackgroundIsolateFlags.active = true;
    _sessionExpiredRelayed = false;
  }

  static void detachBackgroundService() {
    _backgroundServiceInstance = null;
    PatrolBackgroundIsolateFlags.active = false;
    _relayCheckpointSuccessToUi = null;
    _relayProximityNavigationToUi = null;
    _onSessionExpiredInFgs = null;
    _sessionExpiredRelayed = false;
  }

  /// [PatrolBackgroundRunner] — stop GPS/STOMP immediately on 401/403 in FGS.
  static void setOnSessionExpired(Future<void> Function()? handler) {
    _onSessionExpiredInFgs = handler;
  }

  /// REST 401/403 in FGS — relay to main (login) and tear down this isolate.
  static void notifySessionExpiredToMain() {
    if (_sessionExpiredRelayed) return;
    _sessionExpiredRelayed = true;
    try {
      _backgroundServiceInstance?.invoke(PatrolFgsInvokeEvents.sessionExpired);
    } on MissingPluginException {
      //
    } on PlatformException {
      //
    }
    unawaited(_postSessionExpiredNotification());
    final handler = _onSessionExpiredInFgs;
    if (handler != null) {
      unawaited(handler());
    }
  }

  static Future<void> _postSessionExpiredNotification() async {
    try {
      final locale = await AppLocaleStore.readLocale();
      final l10n = lookupAppLocalizations(locale);
      await PatrolForegroundNotification.showSessionExpiredRelaunch(
        title: l10n.patrolBackgroundNotificationTitle,
        body: l10n.signOutSessionInvalid,
      );
    } catch (_) {
      //
    }
  }

  /// Called from [PatrolBackgroundRunner] when a checkpoint is auto-scanned in FGS.
  static void setRelayCheckpointSuccess(void Function(String name)? handler) {
    _relayCheckpointSuccessToUi = handler;
  }

  static void setRelayProximityNavigation(void Function(String message)? handler) {
    _relayProximityNavigationToUi = handler;
  }

  static void relayCheckpointSuccessToUi(String checkpointName) =>
      _relayCheckpointSuccessToUi?.call(checkpointName);

  static void relayProximityNavigationToUi(String message) =>
      _relayProximityNavigationToUi?.call(message);

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

  /// Full Super GPS sample for foreground auto-scan UI (not throttled by track emit).
  static void notifyBackgroundAutoScanRunning(bool running) {
    try {
      _backgroundServiceInstance?.invoke(
        PatrolFgsInvokeEvents.backgroundAutoScanRunning,
        {'running': running},
      );
    } on MissingPluginException {
      //
    } on PlatformException {
      //
    }
  }

  static void notifyAwaitingNextRoundAutoScanConfirm(bool awaiting) {
    try {
      _backgroundServiceInstance?.invoke(
        PatrolFgsInvokeEvents.awaitingNextRoundAutoScanConfirm,
        {'awaiting': awaiting},
      );
    } on MissingPluginException {
      //
    } on PlatformException {
      //
    }
  }

  static void notifyScanGpsSampleFromFgs(SuperGpsEvent event) {
    final position = event.position;
    if (position.isMocked) return;
    try {
      _backgroundServiceInstance?.invoke(
        PatrolFgsInvokeEvents.scanGpsSample,
        {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': position.timestamp.millisecondsSinceEpoch,
          'accuracy': position.accuracy,
          'altitude': position.altitude,
          'altitudeAccuracy': position.altitudeAccuracy,
          'barometricAltitude': event.barometricAltitude,
          'barometerHardwareSupported': event.barometerHardwareSupported,
        },
      );
    } on MissingPluginException {
      //
    } on PlatformException {
      //
    }
  }
}
