/// Shared FGS notification identifiers (main + background isolates).
abstract final class PatrolBackgroundConstants {
  PatrolBackgroundConstants._();

  static const String notificationChannelId = 'sps_patrol_track';
  static const int foregroundNotificationId = 8812;

  /// Next-round confirm notification stays until action or this elapses.
  static const Duration nextRoundConfirmVisibleDuration = Duration(minutes: 20);
}
