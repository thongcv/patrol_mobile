/// Shared FGS notification identifiers (main + background isolates).
abstract final class PatrolBackgroundConstants {
  PatrolBackgroundConstants._();

  static const String notificationChannelId = 'sps_patrol_track';
  static const int foregroundNotificationId = 8812;

  /// Next-round confirm notification stays until action or this elapses.
  static const Duration nextRoundConfirmVisibleDuration = Duration(minutes: 20);

  /// UI / notification isolate waits for FGS confirm handler (cross-isolate prefs latch).
  static const Duration nextRoundConfirmWaitTimeout = Duration(seconds: 2);
  static const Duration nextRoundConfirmWaitPollInterval =
      Duration(milliseconds: 25);
}
