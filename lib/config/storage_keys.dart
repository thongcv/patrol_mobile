/// SharedPreferences keys used across the app (avoids string drift between classes).
abstract final class StorageKeys {
  StorageKeys._();

  static const accessToken = 'patrol_access_token';
  static const devicePushToken = 'patrol_device_push_token';

  /// Company/merchant iBeacon proximity UUID — from `userInfo.beaconUuid` (`/accounts/me`).
  static const companyBeaconUuid = 'patrol_company_beacon_uuid';

  /// Location queue when WebSocket is down (JSON array).
  static const patrolTrackOfflineQueue = 'patrol_track_offline_queue';

  /// Realtime patrol session — used in background isolate.
  static const patrolTrackRoundId = 'patrol_track_round_id';
  static const patrolTrackEmitEnabled = 'patrol_track_emit_enabled';
  static const patrolTrackBackgroundAutoScanEnabled =
      'patrol_track_background_auto_scan_enabled';
  static const patrolTrackForegroundScanBusy = 'patrol_track_foreground_scan_busy';
  static const patrolTrackActiveRoundSnapshot = 'patrol_track_active_round_snapshot';

  /// UI locale `languageCode` (`vi` / `en`) — chosen on login, read in background isolate.
  static const appLocaleLanguageCode = 'patrol_app_locale_language_code';
}
