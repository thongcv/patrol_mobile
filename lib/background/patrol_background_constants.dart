import '../models/patrol_tracking_config.dart';

/// Shared FGS notification identifiers (main + background isolates).
abstract final class PatrolBackgroundConstants {
  PatrolBackgroundConstants._();

  static const String notificationChannelId = 'sps_patrol_track';
  static const int foregroundNotificationId = 8812;

  /// Next-round confirm notification stays until action or this elapses.
  static Duration get nextRoundConfirmVisibleDuration => Duration(
        minutes: PatrolTrackingConfig.defaultNextRoundConfirmMin,
      );

  /// UI / notification isolate waits for FGS confirm handler (cross-isolate prefs latch).
  static const Duration nextRoundConfirmWaitTimeout = Duration(seconds: 2);
  static const Duration nextRoundConfirmWaitPollInterval =
      Duration(milliseconds: 25);
}
