import 'dart:async';

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
  PatrolBackgroundService.isBackgroundIsolate = true;
  PatrolBackgroundService._androidService =
      service is AndroidServiceInstance ? service : null;
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
      await socketEmitter.stop();
      return;
    }
    await PatrolTrackSocketClient.instance.connect();
    await autoScan.refresh();
    if (!socketEmitter.isListening) {
      await socketEmitter.start();
    }
  }

  if (service is AndroidServiceInstance) {
    final l10n = await PatrolBackgroundService._l10nFromPrefs();
    await PatrolForegroundNotification.ensureInitialized(
      channelId: PatrolBackgroundService.notificationChannelId,
      channelName: l10n.patrolBackgroundNotificationTitle,
      channelDescription: l10n.patrolBackgroundNotificationInitialContent,
    );
    await service.setAsForegroundService();
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
    PatrolBackgroundService.isBackgroundIsolate = false;
    PatrolBackgroundService._relayCheckpointSuccessToUi = null;
    PatrolBackgroundService._androidService = null;
    PatrolBackgroundService._notificationRevertTimer?.cancel();
    PatrolBackgroundService._notificationRevertTimer = null;
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

/// Foreground [FlutterBackgroundService] — socket tracking + background auto-scan.
abstract final class PatrolBackgroundService {
  PatrolBackgroundService._();

  static const String notificationChannelId = 'sps_patrol_track';
  static const int foregroundNotificationId = 8812;
  static const String checkpointSuccessEvent = 'checkpointSuccess';
  static bool _initialized = false;
  static bool _checkpointSuccessListenerAttached = false;
  static void Function(String checkpointName)? _relayCheckpointSuccessToUi;
  static AndroidServiceInstance? _androidService;
  static Timer? _notificationRevertTimer;

  /// True while the background-service isolate is running patrol tracking.
  static bool isBackgroundIsolate = false;

  static void relayCheckpointSuccessToUi(String checkpointName) =>
      _relayCheckpointSuccessToUi?.call(checkpointName);

  /// Updates the foreground patrol notification to show a scanned checkpoint.
  static Future<void> showCheckpointScannedNotification(
    String checkpointName,
  ) async {
    final name = checkpointName.trim();
    if (name.isEmpty) return;

    if (_androidService == null) return;

    final l10n = await _l10nFromPrefs();
    await _showForegroundNotification(
      title: l10n.patrolBackgroundNotificationTitle,
      body: l10n.patrolBackgroundCheckpointScanned(name),
    );

    _notificationRevertTimer?.cancel();
    _notificationRevertTimer = Timer(const Duration(seconds: 8), () async {
      if (_androidService == null) return;
      final l = await _l10nFromPrefs();
      await _showForegroundNotification(
        title: l.patrolBackgroundNotificationTitle,
        body: l.patrolBackgroundNotificationContent,
      );
    });
  }

  static Future<void> _showForegroundNotification({
    required String title,
    required String body,
  }) async {
    await PatrolForegroundNotification.show(
      notificationId: foregroundNotificationId,
      title: title,
      body: body,
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
    FlutterBackgroundService().on(checkpointSuccessEvent).listen((event) {
      if (isBackgroundIsolate) return;
      final name = event?['checkpointName'];
      if (name is String && name.trim().isNotEmpty) {
        unawaited(showCheckpointScannedNotification(name));
      }
      unawaited(PatrolCheckpointSuccessFeedback.vibrate());
    });
  }

  static Future<void> startPatrolTracking() async {
    await ensureInitialized();
    final service = FlutterBackgroundService();
    final wasRunning = await service.isRunning();
    await service.startService();
    if (wasRunning) {
      service.invoke('refresh');
    }
  }

  static Future<void> stopPatrolTracking() async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) return;
    service.invoke('stop');
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!await service.isRunning()) return;
    }
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
