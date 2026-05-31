import 'dart:async';
import 'dart:io';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../services/patrol_active_round_cache.dart';
import '../services/patrol_foreground_notification.dart';
import 'patrol_background_constants.dart';
import 'patrol_background_entry.dart';
import 'patrol_fgs_invoke_events.dart';
import 'patrol_fgs_isolate_bridge.dart';
import 'patrol_fgs_main_relay.dart';
import 'patrol_fgs_notifications.dart';
import 'patrol_fgs_relay_state.dart';

/// Patrol tracking via [FlutterBackgroundService].
///
/// **Android:** foreground service (`location` type) with a persistent notification;
/// checkpoint updates use [AndroidServiceInstance.setForegroundNotificationInfo].
///
/// **iOS:** no FGS equivalent — tracking notification uses
/// [PatrolForegroundNotification] and background execution relies on
/// `UIBackgroundModes` (`location`, `fetch`, `remote-notification`). Expect shorter
/// background windows than Android when the app is suspended.
abstract final class PatrolBackgroundService {
  PatrolBackgroundService._();

  static const String notificationChannelId =
      PatrolBackgroundConstants.notificationChannelId;
  static const int foregroundNotificationId =
      PatrolBackgroundConstants.foregroundNotificationId;

  static bool _initialized = false;
  static FlutterBackgroundService? _service;
  static Future<void>? _initFuture;
  static Future<void>? _startServiceFuture;
  static Future<void>? _startTrackingFuture;
  static Future<void>? _refreshPatrolTrackingChain;
  static DateTime? _lastBackgroundRefreshInvoke;
  static void Function()? get relayFgsMockLocationAlert =>
      PatrolFgsRelayState.relayFgsMockLocationAlert;

  static set relayFgsMockLocationAlert(void Function()? handler) {
    PatrolFgsRelayState.relayFgsMockLocationAlert = handler;
  }

  /// True while the background-service isolate is running patrol tracking.
  static bool get isBackgroundIsolate => PatrolFgsIsolateBridge.isBackgroundIsolate;

  static void relayCheckpointSuccessToUi(String checkpointName) =>
      PatrolFgsIsolateBridge.relayCheckpointSuccessToUi(checkpointName);

  /// Local mock GPS in FGS — relays to UI via [mockLocationAlert] (same as STOMP).
  static void notifyMockLocationFromFgs() =>
      PatrolFgsIsolateBridge.notifyMockLocationFromFgs();

  /// Throttled GPS sample from FGS — map/UI on main isolate (not STOMP).
  static void notifyPositionUpdateFromFgs(Position position) =>
      PatrolFgsIsolateBridge.notifyPositionUpdateFromFgs(position);

  /// Updates the patrol notification to show a scanned checkpoint.
  static Future<void> showCheckpointScannedNotification(
    String checkpointName,
  ) =>
      PatrolFgsNotifications.showCheckpointScannedNotification(
        checkpointName,
        foregroundNotificationId: foregroundNotificationId,
        isRunningSafe: isRunningSafe,
      );

  /// `true` after [configureAtAppStart] succeeded in [main].
  static bool get isConfigured => _initialized;

  /// Configures [FlutterBackgroundService] once after the first frame ([main]).
  ///
  /// Socket/login flows should call [_awaitConfigured] then start/refresh only.
  static Future<bool> configureAtAppStart() => _configureOnce();

  /// Ensures main isolate listens for FGS checkpoint TTS relay (call after [configureAtAppStart]).
  static Future<void> ensureCheckpointTtsRelayAttached() async {
    if (!await _awaitConfigured()) return;
    _attachCheckpointSuccessListener();
  }

  /// Waits for or starts the single app-launch [configure] (deduped by [_configureOnce]).
  static Future<bool> _awaitConfigured() async {
    if (_initialized) return true;
    final inFlight = _initFuture;
    if (inFlight != null) {
      await inFlight;
      return _initialized;
    }
    // Socket/login may run before post-frame callback — still only one configure.
    return configureAtAppStart();
  }

  static Future<bool> _configureOnce() async {
    if (_initialized) return true;
    final inFlight = _initFuture;
    if (inFlight != null) {
      await inFlight;
      return _initialized;
    }

    final future = () async {
      _service ??= _tryCreateService();
      if (_service == null) {
        _initialized = false;
        return;
      }
      final service = _service!;
      // Always [configure] on the UI isolate — even when FGS is already running.
      // Skipping it leaves the EventChannel unsubscribed; FGS [invoke] then succeeds
      // natively but events never reach [FlutterBackgroundService.on] (silent drop).
      final l10n = await PatrolFgsNotifications.l10nFromPrefs();
      final androidConfiguration = AndroidConfiguration(
        onStart: patrolBackgroundOnStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: l10n.patrolBackgroundNotificationTitle,
        initialNotificationContent: l10n.patrolBackgroundNotificationInitialContent,
        foregroundServiceNotificationId: foregroundNotificationId,
        foregroundServiceTypes: [AndroidForegroundType.location],
      );
      final iosConfiguration = IosConfiguration(
        autoStart: false,
        onForeground: patrolBackgroundOnStart,
        onBackground: patrolBackgroundOnIosBackground,
      );
      await PatrolForegroundNotification.ensureInitialized(
        channelId: notificationChannelId,
        channelName: l10n.patrolBackgroundNotificationTitle,
        channelDescription: l10n.patrolBackgroundNotificationInitialContent,
      );
      const maxAttempts = 3;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        try {
          await service.configure(
            androidConfiguration: androidConfiguration,
            iosConfiguration: iosConfiguration,
          );
          _attachCheckpointSuccessListener();
          _initialized = true;
          return;
        } on MissingPluginException {
          final retry = attempt < maxAttempts - 1;
          _initialized = false;
          if (!retry) {
            return;
          }
          await _configureRetryDelay(attempt);
          continue;
        } on PlatformException {
          final retry = attempt < maxAttempts - 1;
          _initialized = false;
          if (!retry) {
            return;
          }
          await _configureRetryDelay(attempt);
          continue;
        } catch (_) {
          _initialized = false;
          return;
        }
      }
    }();

    _initFuture = future;
    try {
      await future;
    } finally {
      if (identical(_initFuture, future)) {
        _initFuture = null;
      }
    }
    return _initialized;
  }

  static Future<void> _configureRetryDelay(int attempt) async {
    await Future<void>.delayed(Duration(milliseconds: 200 * (attempt + 1)));
  }

  static Future<bool> _waitForServiceRunning(
    FlutterBackgroundService service, {
    int attempts = 10,
    Duration delay = const Duration(milliseconds: 80),
  }) async {
    for (var i = 0; i < attempts; i++) {
      if (await _isServiceRunning(service)) return true;
      await Future<void>.delayed(delay);
    }
    return false;
  }

  /// Starts FGS when needed and waits until running (no `refresh` — caller owns that).
  static Future<void> _ensureBackgroundServiceRunning(
    FlutterBackgroundService service,
  ) async {
    if (await _isServiceRunning(service)) return;
    await _ensureServiceRunning(service);
    await _waitForServiceRunning(service);
  }

  /// One `refresh` in the background isolate (FGS must already be running).
  static Future<void> _invokeBackgroundRefresh(
    FlutterBackgroundService service, {
    bool afterRoundPersist = false,
  }) async {
    if (!await _isServiceRunning(service)) return;
    // Round-persist reload must reach FGS even if a generic refresh ran <1.5s ago.
    if (!afterRoundPersist) {
      final now = DateTime.now();
      final last = _lastBackgroundRefreshInvoke;
      if (last != null &&
          now.difference(last) < const Duration(milliseconds: 1500)) {
        return;
      }
    }
    _lastBackgroundRefreshInvoke = DateTime.now();
    await _invoke(
      service,
      PatrolFgsInvokeEvents.refresh,
      afterRoundPersist
          ? <String, dynamic>{'afterRoundPersist': true}
          : null,
    );
  }

  static Future<bool> _isServiceRunning(FlutterBackgroundService service) async {
    try {
      return await service.isRunning();
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> isRunningSafe() async {
    final service = _service;
    if (service == null) return false;
    return _isServiceRunning(service);
  }

  static FlutterBackgroundService? _tryCreateService() {
    try {
      return FlutterBackgroundService();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<void> _invoke(
    FlutterBackgroundService service,
    String event, [
    Map<String, dynamic>? args,
  ]) async {
    try {
      if (args == null || args.isEmpty) {
        service.invoke(event);
      } else {
        service.invoke(event, args);
      }
    } on MissingPluginException {
      // Plugin may be temporarily unavailable during startup races.
    } on PlatformException {
      // Plugin may be temporarily unavailable during startup races.
    }
  }

  static Future<void> _startService(FlutterBackgroundService service) async {
    try {
      await service.startService();
    } on MissingPluginException {
      // Plugin may be temporarily unavailable during startup races.
    } on PlatformException {
      // Plugin may be temporarily unavailable during startup races.
    }
  }

  static void _attachCheckpointSuccessListener() {
    final fgs = _service;
    if (fgs == null) return;
    PatrolFgsMainRelay.attach(fgs: fgs);
  }

  /// Re-reads prefs in the background isolate (emit / auto-scan) without stopping FGS.
  /// If [startIfNotRunning] is true, starts service first and then refreshes.
  /// Main isolate: FGS should reconnect STOMP with the new Bearer after refresh.
  static Future<void> notifyTokenRefreshed() async {
    if (!await _awaitConfigured()) return;
    final service = _service;
    if (service == null) return;
    if (!await _isServiceRunning(service)) return;
    await _invoke(service, PatrolFgsInvokeEvents.tokenRefreshed);
  }

  static Future<void> refreshPatrolTracking({
    bool startIfNotRunning = false,
    bool afterRoundPersist = false,
  }) async {
    if (!await _awaitConfigured()) return;
    _refreshPatrolTrackingChain =
        (_refreshPatrolTrackingChain ?? Future<void>.value()).then(
      (_) => _refreshPatrolTrackingImpl(
        startIfNotRunning: startIfNotRunning,
        afterRoundPersist: afterRoundPersist,
      ),
    );
    await _refreshPatrolTrackingChain!;
  }

  static Future<void> _refreshPatrolTrackingImpl({
    required bool startIfNotRunning,
    required bool afterRoundPersist,
  }) async {
    final starting = _startTrackingFuture;
    if (starting != null) {
      await starting;
    }
    final service = _service;
    if (service == null) return;
    if (!await _isServiceRunning(service)) {
      if (!startIfNotRunning) return;
      await _ensureBackgroundServiceRunning(service);
      await _waitForServiceRunning(service);
    }
    if (afterRoundPersist) {
      await PatrolActiveRoundCache.setPendingFgsReloadAfterRound(true);
    }
    await _invokeBackgroundRefresh(
      service,
      afterRoundPersist: afterRoundPersist,
    );
    // FGS may start after first [configureAtAppStart] — re-bind main listeners.
    _attachCheckpointSuccessListener();
  }

  static Future<void> startPatrolTracking() async {
    final inFlight = _startTrackingFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final future = _startPatrolTrackingImpl();
    _startTrackingFuture = future;
    try {
      await future;
    } finally {
      if (identical(_startTrackingFuture, future)) {
        _startTrackingFuture = null;
      }
    }
  }

  static Future<void> _startPatrolTrackingImpl() async {
    if (!await _awaitConfigured()) return;
    final service = _service;
    if (service == null) return;
    await _ensureBackgroundServiceRunning(service);
    if (!Platform.isIOS) return;
    if (!await _isServiceRunning(service)) return;
    final l10n = await PatrolFgsNotifications.l10nFromPrefs();
    await PatrolFgsNotifications.showForegroundNotification(
      notificationId: foregroundNotificationId,
      title: l10n.patrolBackgroundNotificationTitle,
      body: l10n.patrolBackgroundNotificationContent,
    );
  }

  static Future<void> _ensureServiceRunning(FlutterBackgroundService service) async {
    if (await _isServiceRunning(service)) return;
    final inFlight = _startServiceFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _startService(service);
    _startServiceFuture = future;
    try {
      await future;
    } finally {
      if (identical(_startServiceFuture, future)) {
        _startServiceFuture = null;
      }
    }
  }

  static Future<void> stopPatrolTracking() async {
    final service = _service;
    if (service == null) {
      await PatrolFgsNotifications.cancelForegroundNotification(
        foregroundNotificationId,
      );
      return;
    }
    if (!await _isServiceRunning(service)) {
      await PatrolFgsNotifications.cancelForegroundNotification(
        foregroundNotificationId,
      );
      return;
    }
    await _invoke(service, PatrolFgsInvokeEvents.stop);
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!await _isServiceRunning(service)) return;
    }
    await PatrolFgsNotifications.cancelForegroundNotification(
      foregroundNotificationId,
    );
  }

  static Future<void> pauseBackgroundAutoScan() async {
    final service = _service;
    if (service == null) return;
    if (await _isServiceRunning(service)) {
      await _invoke(service, PatrolFgsInvokeEvents.pauseAutoScan);
    }
  }

  static Future<void> resumeBackgroundAutoScan() async {
    final service = _service;
    if (service == null) return;
    if (await _isServiceRunning(service)) {
      await _invoke(service, PatrolFgsInvokeEvents.resumeAutoScan);
    }
  }
}
