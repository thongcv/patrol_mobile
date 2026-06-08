/// [FlutterBackgroundService.invoke] event names — shared by FGS and UI isolates.
abstract final class PatrolFgsInvokeEvents {
  PatrolFgsInvokeEvents._();

  static const stop = 'stop';
  static const refresh = 'refresh';
  static const pauseAutoScan = 'pauseAutoScan';
  static const resumeAutoScan = 'resumeAutoScan';
  static const confirmNextRoundAutoScan = 'confirmNextRoundAutoScan';
  static const cancelNextRoundAutoScan = 'cancelNextRoundAutoScan';
  /// Main / prefs — re-hold auto-scan when [awaiting] (no notify/TTS).
  static const syncNextRoundAutoScanHold = 'syncNextRoundAutoScanHold';
  /// First offer for current round — heads-up + TTS (deduped).
  static const offerNextRoundAutoScan = 'offerNextRoundAutoScan';
  static const setForegroundScanRelay = 'setForegroundScanRelay';
  static const tokenRefreshed = 'tokenRefreshed';

  static const checkpointSuccess = 'checkpointSuccess';
  static const proximityNavigationHint = 'proximityNavigationHint';
  static const activeRoundChanged = 'activeRoundChanged';
  static const trackingConfigChanged = 'trackingConfigChanged';
  static const mockLocationAlert = 'mockLocationAlert';
  static const socketConnected = 'socketConnected';
  static const positionUpdate = 'positionUpdate';
  static const scanGpsSample = 'scanGpsSample';
  static const backgroundAutoScanRunning = 'backgroundAutoScanRunning';
  static const awaitingNextRoundAutoScanConfirm =
      'awaitingNextRoundAutoScanConfirm';
}
