import 'dart:async';
import 'dart:io';

import 'package:flutter_background_service/flutter_background_service.dart';

import '../l10n/app_localizations.dart';
import '../services/app_locale_store.dart';
import '../services/patrol_foreground_notification.dart';
import 'patrol_fgs_isolate_bridge.dart';

/// Patrol FGS notification display and checkpoint-scan revert timer.
abstract final class PatrolFgsNotifications {
  PatrolFgsNotifications._();

  static Timer? _notificationRevertTimer;

  static void cancelNotificationRevertTimer() {
    _notificationRevertTimer?.cancel();
    _notificationRevertTimer = null;
  }

  static Future<void> cancelForegroundNotification(int notificationId) =>
      PatrolForegroundNotification.cancel(notificationId);

  static Future<AppLocalizations> l10nFromPrefs() async {
    final locale = await AppLocaleStore.readLocale();
    return lookupAppLocalizations(locale);
  }

  static Future<void> showForegroundNotification({
    required int notificationId,
    required String title,
    required String body,
    bool checkpointPulse = false,
  }) async {
    await PatrolForegroundNotification.show(
      notificationId: notificationId,
      title: title,
      body: body,
      checkpointPulse: checkpointPulse,
    );
  }

  /// Updates the patrol notification to show a scanned checkpoint.
  static Future<void> showCheckpointScannedNotification(
    String checkpointName, {
    required int foregroundNotificationId,
    required Future<bool> Function() isRunningSafe,
  }) async {
    final name = checkpointName.trim();
    if (name.isEmpty) return;

    final l10n = await l10nFromPrefs();
    final title = l10n.patrolBackgroundNotificationTitle;
    final body = l10n.patrolBackgroundCheckpointScanned(name);

    // Android FGS notification is owned by flutter_background_service — update
    // it via [AndroidServiceInstance], not flutter_local_notifications.
    final bg = PatrolFgsIsolateBridge.backgroundServiceInstance;
    if (bg is AndroidServiceInstance) {
      await bg.setForegroundNotificationInfo(title: title, content: body);
      await _showCheckpointAlertNotification(title: title, body: body);
      _schedulePatrolNotificationRevert(
        foregroundNotificationId: foregroundNotificationId,
        isRunningSafe: isRunningSafe,
        android: bg,
      );
      return;
    }

    if (!PatrolFgsIsolateBridge.isBackgroundIsolate &&
        !await isRunningSafe()) {
      return;
    }

    await _showCheckpointAlertNotification(title: title, body: body);
    await showForegroundNotification(
      notificationId: foregroundNotificationId,
      title: title,
      body: body,
      checkpointPulse: true,
    );
    _schedulePatrolNotificationRevert(
      foregroundNotificationId: foregroundNotificationId,
      isRunningSafe: isRunningSafe,
    );
  }

  static void _schedulePatrolNotificationRevert({
    required int foregroundNotificationId,
    required Future<bool> Function() isRunningSafe,
    AndroidServiceInstance? android,
  }) {
    _notificationRevertTimer?.cancel();
    _notificationRevertTimer = Timer(const Duration(seconds: 8), () async {
      final l = await l10nFromPrefs();
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
      if (PatrolFgsIsolateBridge.isBackgroundIsolate && !Platform.isAndroid) {
        await showForegroundNotification(
          notificationId: foregroundNotificationId,
          title: title,
          body: body,
        );
        return;
      }
      if (!await isRunningSafe()) return;
      await showForegroundNotification(
        notificationId: foregroundNotificationId,
        title: title,
        body: body,
      );
    });
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
}
