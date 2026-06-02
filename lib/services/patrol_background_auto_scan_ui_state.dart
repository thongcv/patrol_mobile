import 'package:flutter/foundation.dart';

/// Main-isolate mirror of FGS background auto-scan running (listener attached + not paused).
abstract final class PatrolBackgroundAutoScanUiState {
  PatrolBackgroundAutoScanUiState._();

  static final ValueNotifier<bool> running = ValueNotifier<bool>(false);

  static void setRunning(bool value) {
    if (running.value == value) return;
    running.value = value;
  }
}
