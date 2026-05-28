/// Static STOMP handlers — survives hot reload of [PatrolTrackSocketClient].
abstract final class PatrolTrackSocketDispatch {
  PatrolTrackSocketDispatch._();

  static void Function()? onActiveRoundChanged;
  static void Function()? onSocketConnected;
}
