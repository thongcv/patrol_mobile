import 'dart:async';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../utils/patrol_background_plugin_registrant.dart';
import 'app_locale_store.dart';
import 'patrol_active_round_coordinator.dart';
import 'patrol_background_isolate_flags.dart';
import 'patrol_background_runner.dart';
import '../utils/patrol_checkpoint_tts.dart';
import 'patrol_fgs_invoke_events.dart';
import 'patrol_foreground_notification.dart';

/// iOS background entry from [flutter_background_service] — OS may wake the app briefly.
///
/// Unlike Android FGS, iOS does not keep a long-lived Dart isolate here. Patrol GPS,
/// socket emit, and auto-scan run from [patrolBackgroundOnStart] while the app is
/// foreground or while `UIBackgroundModes` location keeps the process eligible.
/// Full patrol logic is not restarted in this callback by design.
@pragma('vm:entry-point')
Future<bool> patrolBackgroundOnIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  ensurePatrolBackgroundPlugins();
  return true;
}

@pragma('vm:entry-point')
void patrolBackgroundOnStart(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  _installBackgroundServiceErrorFilter();
  unawaited(_runPatrolBackground(service));
}

void _installBackgroundServiceErrorFilter() {
  final previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final exception = details.exception;
    final isPluginRace = exception is MissingPluginException &&
        details.library == 'services library' &&
        details.context.toString().contains(
              'platform stream on channel id.flutter/background_service/android/event',
            );
    if (isPluginRace) {
      // flutter_background_service may race with plugin registration on some
      // Android starts; suppress noisy non-fatal listen/cancel channel errors.
      return;
    }
    previous?.call(details);
  };
}

Future<void> _runPatrolBackground(ServiceInstance service) async {
  ensurePatrolBackgroundPlugins();
  try {
    DartPluginRegistrant.ensureInitialized();
  } catch (_) {
    // Best effort — enables flutter_tts and other plugins in the FGS isolate.
  }

  // Promote to foreground as early as possible on Android so the status-bar
  // notification appears sooner, then continue heavier setup work.
  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
  }

  final runner = PatrolBackgroundRunner(service);
  runner.prepare();

  final l10n = await PatrolBackgroundService._l10nFromPrefs();
  await PatrolForegroundNotification.ensureInitialized(
    channelId: PatrolBackgroundService.notificationChannelId,
    channelName: l10n.patrolBackgroundNotificationTitle,
    channelDescription: l10n.patrolBackgroundNotificationInitialContent,
  );

  if (service is! AndroidServiceInstance) {
    await PatrolBackgroundService._showForegroundNotification(
      title: l10n.patrolBackgroundNotificationTitle,
      body: l10n.patrolBackgroundNotificationContent,
    );
  }

  await runner.startTracking();
}

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

  static const String notificationChannelId = 'sps_patrol_track';
  static const int foregroundNotificationId = 8812;
  static bool _initialized = false;
  static FlutterBackgroundService? _service;
  static Future<void>? _initFuture;
  static Future<void>? _startServiceFuture;
  static Future<void>? _startTrackingFuture;
  static void Function(String checkpointName)? _relayCheckpointSuccessToUi;
  static void Function()? relayFgsMockLocationAlert;
  static Timer? _notificationRevertTimer;
  static ServiceInstance? _backgroundServiceInstance;

  /// True while the background-service isolate is running patrol tracking.
  static bool get isBackgroundIsolate => PatrolBackgroundIsolateFlags.active;

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

  static void cancelNotificationRevertTimer() {
    _notificationRevertTimer?.cancel();
    _notificationRevertTimer = null;
  }

  static Future<void> cancelForegroundNotification() => PatrolForegroundNotification.cancel(
        foregroundNotificationId,
      );

  static void relayCheckpointSuccessToUi(String checkpointName) =>
      _relayCheckpointSuccessToUi?.call(checkpointName);

  /// Notifies main isolate that [PatrolActiveRoundCache] changed (after FGS auto-scan).
  static void notifyActiveRoundChangedFromFgs() {
    try {
      _backgroundServiceInstance?.invoke(
        PatrolFgsInvokeEvents.activeRoundChanged,
      );
    } on MissingPluginException {
      //
    } on PlatformException {
      //
    }
  }

  /// Updates the patrol notification to show a scanned checkpoint.
  static Future<void> showCheckpointScannedNotification(
    String checkpointName,
  ) async {
    final name = checkpointName.trim();
    if (name.isEmpty) return;

    final l10n = await _l10nFromPrefs();
    final title = l10n.patrolBackgroundNotificationTitle;
    final body = l10n.patrolBackgroundCheckpointScanned(name);

    // Android FGS notification is owned by flutter_background_service — update
    // it via [AndroidServiceInstance], not flutter_local_notifications.
    final bg = _backgroundServiceInstance;
    if (bg is AndroidServiceInstance) {
      await bg.setForegroundNotificationInfo(title: title, content: body);
      await _showCheckpointAlertNotification(title: title, body: body);
      _schedulePatrolNotificationRevert(android: bg);
      return;
    }

    if (!isBackgroundIsolate && !await isRunningSafe()) {
      return;
    }

    await _showCheckpointAlertNotification(title: title, body: body);
    await _showForegroundNotification(
      title: title,
      body: body,
      checkpointPulse: true,
    );
    _schedulePatrolNotificationRevert();
  }

  static void _schedulePatrolNotificationRevert({
    AndroidServiceInstance? android,
  }) {
    _notificationRevertTimer?.cancel();
    _notificationRevertTimer = Timer(const Duration(seconds: 8), () async {
      final l = await _l10nFromPrefs();
      final title = l.patrolBackgroundNotificationTitle;
      final body = l.patrolBackgroundNotificationContent;
      if (android != null) {
        await android.setForegroundNotificationInfo(
          title: title,
          content: body,
        );
        return;
      }
      // iOS background isolate: revert via flutter_local_notifications.
      if (isBackgroundIsolate && !Platform.isAndroid) {
        await _showForegroundNotification(title: title, body: body);
        return;
      }
      if (!await isRunningSafe()) return;
      await _showForegroundNotification(title: title, body: body);
    });
  }

  static Future<void> _showForegroundNotification({
    required String title,
    required String body,
    bool checkpointPulse = false,
  }) async {
    await PatrolForegroundNotification.show(
      notificationId: foregroundNotificationId,
      title: title,
      body: body,
      checkpointPulse: checkpointPulse,
    );
  }

  static Future<void> _showCheckpointAlertNotification({
    required String title,
    required String body,
  }) async {
    await PatrolForegroundNotification.showCheckpointScanAlert(
      title: title,
      body: body,
    );
  }

  static Future<AppLocalizations> _l10nFromPrefs() async {
    final locale = await AppLocaleStore.readLocale();
    return lookupAppLocalizations(locale);
  }

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
      if (await _isServiceRunning(service)) {
        _attachCheckpointSuccessListener();
        _initialized = true;
        return;
      }
      final l10n = await _l10nFromPrefs();
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

  /// Starts FGS when needed, waits briefly, then pushes `refresh` to background isolate.
  static Future<void> _syncTrackingWithBackground(
    FlutterBackgroundService service,
  ) async {
    final wasRunning = await _isServiceRunning(service);
    if (!wasRunning) {
      await _ensureServiceRunning(service);
      // Fast path: fire refresh immediately after start request.
      unawaited(_invoke(service, PatrolFgsInvokeEvents.refresh));
      // Verify running state asynchronously and refresh again when fully up.
      unawaited(_waitAndRefreshAfterStart(service));
      return;
    }
    await _invoke(service, PatrolFgsInvokeEvents.refresh);
  }

  static Future<void> _waitAndRefreshAfterStart(
    FlutterBackgroundService service,
  ) async {
    if (!await _waitForServiceRunning(service)) {
      return;
    }
    await _invoke(service, PatrolFgsInvokeEvents.refresh);
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
    String event,
  ) async {
    try {
      service.invoke(event);
    } on MissingPluginException {
      // Plugin may be temporarily unavailable during startup races.
    } on PlatformException {
    }
  }

  static Future<void> _startService(FlutterBackgroundService service) async {
    try {
      await service.startService();
    } on MissingPluginException {
      // Plugin may be temporarily unavailable during startup races.
    } on PlatformException {
    }
  }

  static final List<StreamSubscription<dynamic>> _mainFgsRelaySubs = [];
  static StreamSubscription<dynamic>? _checkpointSuccessSub;

  /// Relay FGS → UI when main isolate is alive (app in foreground).
  static void _attachMainFgsRelay() {
    final fgs = _service;
    if (fgs == null) return;
    for (final sub in _mainFgsRelaySubs) {
      unawaited(sub.cancel());
    }
    _mainFgsRelaySubs.clear();
    unawaited(_checkpointSuccessSub?.cancel());
    _checkpointSuccessSub = null;

    void safeRelay(String event, void Function(dynamic payload) onEvent) {
      try {
        final sub = FlutterBackgroundService()
            .on(event)
            .listen((payload) => onEvent(payload));
        _mainFgsRelaySubs.add(sub);
      } on MissingPluginException {
        // Event channel may be unavailable in startup plugin races.
      } on PlatformException {
      }
    }

    try {
      _checkpointSuccessSub = FlutterBackgroundService()
          .on(PatrolFgsInvokeEvents.checkpointSuccess)
          .listen((payload) {
        final map = payload is Map
            ? Map<Object?, Object?>.from(payload as Map)
            : null;
        if (map == null) return;
        final checkpointName = (map['checkpointName'] as String?)?.trim() ?? '';
        if (checkpointName.isEmpty) return;
        unawaited(_speakCheckpointOnMainIsolate(checkpointName));
      });
    } on MissingPluginException {
      //
    } on PlatformException {
      //
    }

    safeRelay(
      PatrolFgsInvokeEvents.activeRoundChanged,
      (_) => unawaited(PatrolActiveRoundCoordinator.applyFgsRoundUpdate()),
    );
    safeRelay(
      PatrolFgsInvokeEvents.socketConnected,
      (_) => unawaited(PatrolActiveRoundCoordinator.syncFromServer()),
    );
    safeRelay(
      PatrolFgsInvokeEvents.mockLocationAlert,
      (_) => relayFgsMockLocationAlert?.call(),
    );
  }

  static void _attachCheckpointSuccessListener() {
    _attachMainFgsRelay();
  }

  static Future<void> _speakCheckpointOnMainIsolate(String checkpointName) async {
    final locale = await AppLocaleStore.readLocale();
    await PatrolCheckpointTts.speakCheckpoint(
      checkpointName: checkpointName,
      locale: locale,
    );
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
  }) async {
    if (!await _awaitConfigured()) return;
    final service = _service;
    if (service == null) return;
    if (await _isServiceRunning(service)) {
      await _invoke(service, PatrolFgsInvokeEvents.refresh);
      return;
    }
    if (startIfNotRunning) {
      await _syncTrackingWithBackground(service);
    }
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
    await _syncTrackingWithBackground(service);
    if (!Platform.isIOS) return;
    if (!await _isServiceRunning(service)) return;
    final l10n = await _l10nFromPrefs();
    await _showForegroundNotification(
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
      await PatrolForegroundNotification.cancel(foregroundNotificationId);
      return;
    }
    if (!await _isServiceRunning(service)) {
      await PatrolForegroundNotification.cancel(foregroundNotificationId);
      return;
    }
    await _invoke(service, PatrolFgsInvokeEvents.stop);
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!await _isServiceRunning(service)) return;
    }
    await PatrolForegroundNotification.cancel(foregroundNotificationId);
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
