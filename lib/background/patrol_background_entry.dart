import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../utils/patrol_background_plugin_registrant.dart';
import '../services/patrol_foreground_notification.dart';
import 'patrol_background_constants.dart';
import 'patrol_background_runner.dart';
import 'patrol_fgs_notifications.dart';

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

  final l10n = await PatrolFgsNotifications.l10nFromPrefs();
  await PatrolForegroundNotification.ensureInitialized(
    channelId: PatrolBackgroundConstants.notificationChannelId,
    channelName: l10n.patrolBackgroundNotificationTitle,
    channelDescription: l10n.patrolBackgroundNotificationInitialContent,
  );

  if (service is! AndroidServiceInstance) {
    await PatrolFgsNotifications.showForegroundNotification(
      notificationId: PatrolBackgroundConstants.foregroundNotificationId,
      title: l10n.patrolBackgroundNotificationTitle,
      body: l10n.patrolBackgroundNotificationContent,
    );
  }

  await runner.startTracking();
}
