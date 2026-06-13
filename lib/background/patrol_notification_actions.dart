import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../background/patrol_background_service.dart';
import '../services/patrol_active_round_cache.dart';
import '../services/patrol_active_round_sync.dart';
import '../services/patrol_background_auto_scan_ui_state.dart';
import '../services/patrol_foreground_notification.dart';
import '../utils/patrol_background_plugin_registrant.dart';

/// Payload / action ids for next-round auto-scan confirm notifications.
abstract final class PatrolNotificationActions {
  PatrolNotificationActions._();

  static const String nextRoundPayload = 'patrol_next_round_auto_scan';
  /// Short ids — some Android builds truncate custom action keys.
  static const String autoScanConfirmActionId = 'confirm';
  static const String autoScanCancelActionId = 'cancel';

  /// Legacy ids from earlier builds.
  static const String autoScanOkActionId = 'auto_scan_ok';
  static const String legacyConfirmActionId = 'auto_scan_confirm';
  static const String legacyCancelActionId = 'auto_scan_cancel';

  static Future<void> handleResponse(NotificationResponse response) async {
    final actionId = response.actionId?.trim();
    if (actionId == null || actionId.isEmpty) return;

    if (_isCancelAction(actionId)) {
      PatrolBackgroundAutoScanUiState.setAwaitingNextRoundConfirm(false);
      await PatrolActiveRoundCache.signalCancelNextRoundAutoScan();
      await PatrolBackgroundService.invokeCancelNextRoundAutoScan();
      await PatrolForegroundNotification.cancelNextRoundConfirm();
      return;
    }

    if (!_isConfirmAction(actionId)) return;

    await PatrolActiveRoundSync.confirmNextRoundAutoScanFromUser();
  }

  static bool _isConfirmAction(String actionId) =>
      actionId == autoScanConfirmActionId ||
      actionId == autoScanOkActionId ||
      actionId == legacyConfirmActionId;

  static bool _isCancelAction(String actionId) =>
      actionId == autoScanCancelActionId ||
      actionId == legacyCancelActionId;
}

/// Required top-level entry for [flutter_local_notifications] background taps.
@pragma('vm:entry-point')
void patrolNotificationBackgroundTap(NotificationResponse response) {
  WidgetsFlutterBinding.ensureInitialized();
  ensurePatrolBackgroundPlugins();
  unawaited(PatrolNotificationActions.handleResponse(response));
}
