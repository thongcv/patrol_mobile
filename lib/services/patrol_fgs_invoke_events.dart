/// [FlutterBackgroundService.invoke] event names — shared by FGS and UI isolates.
abstract final class PatrolFgsInvokeEvents {
  PatrolFgsInvokeEvents._();

  static const stop = 'stop';
  static const refresh = 'refresh';
  static const pauseAutoScan = 'pauseAutoScan';
  static const resumeAutoScan = 'resumeAutoScan';
  static const tokenRefreshed = 'tokenRefreshed';

  static const checkpointSuccess = 'checkpointSuccess';
  static const activeRoundChanged = 'activeRoundChanged';
  static const mockLocationAlert = 'mockLocationAlert';
  static const socketConnected = 'socketConnected';
  static const positionUpdate = 'positionUpdate';
}
