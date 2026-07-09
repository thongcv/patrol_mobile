/// Whether Dart code is running inside the [FlutterBackgroundService] isolate.
abstract final class PatrolBackgroundIsolateFlags {
  PatrolBackgroundIsolateFlags._();

  static bool active = false;
}
