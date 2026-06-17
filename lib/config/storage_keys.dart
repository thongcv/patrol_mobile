/// SharedPreferences keys used across the app (avoids string drift between classes).
abstract final class StorageKeys {
  StorageKeys._();

  static const accessToken = 'patrol_access_token';
  static const devicePushToken = 'patrol_device_push_token';

  /// Company/merchant iBeacon proximity UUID — from `userInfo.beaconUuid` (`/accounts/me`).
  static const companyBeaconUuid = 'patrol_company_beacon_uuid';

  /// GATT protocol for programming beacons (`hm10_ffe0`, `nordic_nrf52`, …).
  static const beaconConfigureProtocol = 'patrol_beacon_configure_protocol';

  /// Optional HM-10 / clone PIN for beacon configure (6 digits); empty = not used.
  static const beaconDevicePassword = 'patrol_beacon_device_password';

  /// Location queue when WebSocket is down (JSON array).
  static const patrolTrackOfflineQueue = 'patrol_track_offline_queue';

  /// Realtime patrol session — used in background isolate.
  static const patrolTrackEmitEnabled = 'patrol_track_emit_enabled';
  /// Armed by STOMP `active-round-changed` when login config allows — not on app bootstrap GET.
  static const patrolTrackBackgroundAutoScanEnabled =
      'patrol_track_background_auto_scan_enabled';
  /// FGS auto-scan listener active and not soft-paused (UI radar button).
  static const patrolTrackBackgroundAutoScanRunning =
      'patrol_track_background_auto_scan_running';
  static const patrolTrackForegroundScanBusy = 'patrol_track_foreground_scan_busy';

  /// Main sets before FGS `refresh` invoke; FGS [PatrolBackgroundRunner.startTracking] (lib/background/) consumes.
  static const patrolTrackPendingFgsReloadAfterRound =
      'patrol_track_pending_fgs_reload_after_round';
  /// User tapped confirm on next-round notification (any isolate → FGS poll).
  static const patrolTrackConfirmNextRoundAutoScanAtMs =
      'patrol_track_confirm_next_round_auto_scan_at_ms';
  /// FGS or main fallback finished next-round confirm (arm + resume + reload).
  static const patrolTrackNextRoundConfirmHandledAtMs =
      'patrol_track_next_round_confirm_handled_at_ms';
  static const patrolTrackCancelNextRoundAutoScanAtMs =
      'patrol_track_cancel_next_round_auto_scan_at_ms';
  /// FGS holds auto-scan until user taps confirm on next-round notification.
  static const patrolTrackAwaitingNextRoundAutoScanConfirm =
      'patrol_track_awaiting_next_round_auto_scan_confirm';
  /// Last round id user confirmed (or dismissed) for FGS auto-scan — detect round change on app open.
  static const patrolTrackLastAutoScanConfirmedRoundId =
      'patrol_track_last_auto_scan_confirmed_round_id';
  /// When next-round confirm notification was posted (expiry / re-show).
  static const patrolTrackNextRoundPromptShownAtMs =
      'patrol_track_next_round_prompt_shown_at_ms';
  /// Active round id for which next-round heads-up + TTS was already offered.
  static const patrolTrackNextRoundPromptOfferRoundId =
      'patrol_track_next_round_prompt_offer_round_id';
  static const patrolTrackActiveRoundSnapshot = 'patrol_track_active_round_snapshot';
  /// Monotonic counter bumped on each [PatrolActiveRoundCache] write — FGS dedupes reload.
  static const patrolTrackActiveRoundRevision = 'patrol_track_active_round_revision';
  /// Cached `round.expectedStartTime` / `expectedEndTime` for emit gating (FGS + main).
  static const patrolTrackShiftWindow = 'patrol_track_shift_window';

  /// UI locale `languageCode` (`vi` / `en`) — chosen on login, read in background isolate.
  static const appLocaleLanguageCode = 'patrol_app_locale_language_code';

  /// Login `data.config`: `{ "background", "minMoveM", "socket", "backgroundAutoScan", "trackByShiftWindow", "shiftWindowStartGraceMinutes", "shiftWindowEndGraceMinutes", "overdueGraceMinutes" }`.
  static const patrolTrackingConfig = 'patrol_tracking_config';

  /// Epoch ms — [LocationGateScreen] / ensure background location passed (all isolates).
  static const patrolBackgroundLocationReadyAt =
      'patrol_background_location_ready_at';

  /// Cross-isolate TTS dedupe for checkpoint success feedback.
  static const patrolCheckpointTtsLastName = 'patrol_checkpoint_tts_last_name';
  static const patrolCheckpointTtsLastAtMs = 'patrol_checkpoint_tts_last_at_ms';
}
