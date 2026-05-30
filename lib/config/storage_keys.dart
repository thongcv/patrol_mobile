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
  static const patrolTrackEmitEnabled = 'patrol_track_emit_enabled';
  /// Armed by STOMP `active-round-changed` when login config allows — not on app bootstrap GET.
  static const patrolTrackBackgroundAutoScanEnabled =
      'patrol_track_background_auto_scan_enabled';
  static const patrolTrackForegroundScanBusy = 'patrol_track_foreground_scan_busy';

  /// Main sets before FGS `refresh` invoke; FGS [PatrolBackgroundRunner.startTracking] consumes.
  static const patrolTrackPendingFgsReloadAfterRound =
      'patrol_track_pending_fgs_reload_after_round';
  static const patrolTrackActiveRoundSnapshot = 'patrol_track_active_round_snapshot';
  /// Monotonic counter bumped on each [PatrolActiveRoundCache] write — FGS dedupes reload.
  static const patrolTrackActiveRoundRevision = 'patrol_track_active_round_revision';

  /// UI locale `languageCode` (`vi` / `en`) — chosen on login, read in background isolate.
  static const appLocaleLanguageCode = 'patrol_app_locale_language_code';

  /// Login `data.config`: `{ "background", "minMoveM", "socket", "backgroundAutoScan" }`.
  static const patrolTrackingConfig = 'patrol_tracking_config';

  /// Epoch ms — [LocationGateScreen] / ensure background location passed (all isolates).
  static const patrolBackgroundLocationReadyAt =
      'patrol_background_location_ready_at';

  /// Cross-isolate TTS dedupe for checkpoint success feedback.
  static const patrolCheckpointTtsLastName = 'patrol_checkpoint_tts_last_name';
  static const patrolCheckpointTtsLastAtMs = 'patrol_checkpoint_tts_last_at_ms';
}
