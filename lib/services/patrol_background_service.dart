import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import '../l10n/app_localizations.dart';
import '../utils/patrol_background_plugin_registrant.dart';
import '../utils/patrol_checkpoint_success_feedback.dart';
import 'app_locale_store.dart';
import 'patrol_background_auto_scan.dart';
import 'patrol_background_socket_emitter.dart';
import 'patrol_foreground_notification.dart';
import 'patrol_track_socket_client.dart';
import 'patrol_tracking_config_store.dart';

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
  unawaited(_runPatrolBackground(service));
}

Future<void> _runPatrolBackground(ServiceInstance service) async {
  ensurePatrolBackgroundPlugins();
  PatrolBackgroundService.attachBackgroundService(service);
  PatrolBackgroundService._relayCheckpointSuccessToUi = (String name) {
    service.invoke(
      PatrolBackgroundService.checkpointSuccessEvent,
      <String, dynamic>{'checkpointName': name},
    );
  };

  final socketEmitter = PatrolBackgroundSocketEmitter();
  final autoScan = PatrolBackgroundAutoScan(socketEmitter);
  var shuttingDown = false;

  Future<void> refreshTracking() async {
    final prefs = await SharedPreferences.getInstance();
    final emit = prefs.getBool(StorageKeys.patrolTrackEmitEnabled) ?? false;
    if (!emit) {
      await autoScan.stop();
      if (await PatrolTrackingConfigStore.socketEnabled()) {
        await PatrolTrackSocketClient.instance.disconnect();
      }
      return;
    }
    if (await PatrolTrackingConfigStore.socketEnabled()) {
      await PatrolTrackSocketClient.instance.connect();
    }
    await autoScan.refresh();
    if (!socketEmitter.isListening) {
      await socketEmitter.start();
    }
  }

  final l10n = await PatrolBackgroundService._l10nFromPrefs();
  await PatrolForegroundNotification.ensureInitialized(
    channelId: PatrolBackgroundService.notificationChannelId,
    channelName: l10n.patrolBackgroundNotificationTitle,
    channelDescription: l10n.patrolBackgroundNotificationInitialContent,
  );

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    // FGS notification is built in native BackgroundService (no large icon).
    // Do not call flutter_local_notifications here — it used to override with largeIcon.
  } else {
    await PatrolBackgroundService._showForegroundNotification(
      title: l10n.patrolBackgroundNotificationTitle,
      body: l10n.patrolBackgroundNotificationContent,
    );
  }

  Future<void> shutdown() async {
    if (shuttingDown) return;
    shuttingDown = true;
    await autoScan.stop();
    await socketEmitter.stop();
    PatrolBackgroundService.detachBackgroundService();
    PatrolBackgroundService._notificationRevertTimer?.cancel();
    PatrolBackgroundService._notificationRevertTimer = null;
    await PatrolForegroundNotification.cancel(
      PatrolBackgroundService.foregroundNotificationId,
    );
    await service.stopSelf();
  }

  service.on('stop').listen((_) => unawaited(shutdown()));

  service.on('refresh').listen((_) {
    if (!shuttingDown) unawaited(refreshTracking());
  });
  service.on('pauseAutoScan').listen((_) {
    if (!shuttingDown) autoScan.pause();
  });
  service.on('resumeAutoScan').listen((_) {
    if (!shuttingDown) unawaited(autoScan.resume());
  });

  await refreshTracking();
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
  static const String checkpointSuccessEvent = 'checkpointSuccess';
  static bool _initialized = false;
  static bool _checkpointSuccessListenerAttached = false;
  static void Function(String checkpointName)? _relayCheckpointSuccessToUi;
  static Timer? _notificationRevertTimer;
  static ServiceInstance? _backgroundServiceInstance;

  /// True while the background-service isolate is running patrol tracking.
  static bool isBackgroundIsolate = false;

  static void attachBackgroundService(ServiceInstance service) {
    _backgroundServiceInstance = service;
    isBackgroundIsolate = true;
  }

  static void detachBackgroundService() {
    _backgroundServiceInstance = null;
    isBackgroundIsolate = false;
    _relayCheckpointSuccessToUi = null;
  }

  static void relayCheckpointSuccessToUi(String checkpointName) =>
      _relayCheckpointSuccessToUi?.call(checkpointName);

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
      _schedulePatrolNotificationRevert(android: bg);
      return;
    }

    if (!isBackgroundIsolate &&
        !await FlutterBackgroundService().isRunning()) {
      return;
    }

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
      if (!await FlutterBackgroundService().isRunning()) return;
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

  static Future<AppLocalizations> _l10nFromPrefs() async {
    final locale = await AppLocaleStore.readLocale();
    return lookupAppLocalizations(locale);
  }

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    final l10n = await _l10nFromPrefs();
    await PatrolForegroundNotification.ensureInitialized(
      channelId: notificationChannelId,
      channelName: l10n.patrolBackgroundNotificationTitle,
      channelDescription: l10n.patrolBackgroundNotificationInitialContent,
    );
    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart: patrolBackgroundOnStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: l10n.patrolBackgroundNotificationTitle,
        initialNotificationContent:
            l10n.patrolBackgroundNotificationInitialContent,
        foregroundServiceNotificationId: foregroundNotificationId,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: patrolBackgroundOnStart,
        onBackground: patrolBackgroundOnIosBackground,
      ),
    );
    _attachCheckpointSuccessListener();
    _initialized = true;
  }

  static void _attachCheckpointSuccessListener() {
    if (_checkpointSuccessListenerAttached) return;
    _checkpointSuccessListenerAttached = true;
    FlutterBackgroundService().on(checkpointSuccessEvent).listen((_) {
      if (isBackgroundIsolate) return;
      unawaited(PatrolCheckpointSuccessFeedback.vibrate());
      // Background isolate already showed a time-sensitive notification; UI isolate
      // adds haptic when the app is still active.
    });
  }

  /// Re-reads prefs in the background isolate (emit / auto-scan) without stopping FGS.
  static Future<void> refreshPatrolTracking() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('refresh');
    }
  }

  static Future<void> startPatrolTracking() async {
    await ensureInitialized();
    final service = FlutterBackgroundService();
    final wasRunning = await service.isRunning();
    await service.startService();
    if (wasRunning) {
      service.invoke('refresh');
    } else if (Platform.isIOS) {
      final l10n = await _l10nFromPrefs();
      for (var i = 0; i < 30; i++) {
        if (await service.isRunning()) {
          await _showForegroundNotification(
            title: l10n.patrolBackgroundNotificationTitle,
            body: l10n.patrolBackgroundNotificationContent,
          );
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  static Future<void> stopPatrolTracking() async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await PatrolForegroundNotification.cancel(foregroundNotificationId);
      return;
    }
    service.invoke('stop');
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!await service.isRunning()) return;
    }
    await PatrolForegroundNotification.cancel(foregroundNotificationId);
  }

  static Future<void> pauseBackgroundAutoScan() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('pauseAutoScan');
    }
  }

  static Future<void> resumeBackgroundAutoScan() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('resumeAutoScan');
    }
  }
}
