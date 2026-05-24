import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../services/patrol_background_service.dart';

/// Vibration + notification when a checkpoint scan succeeds in background.
abstract final class PatrolCheckpointSuccessFeedback {
  PatrolCheckpointSuccessFeedback._();

  /// Two short pulses and a notification with [checkpointName].
  static Future<void> notify({required String checkpointName}) async {
    await PatrolBackgroundService.showCheckpointScannedNotification(
      checkpointName,
    );
    if (await vibrate()) return;
    if (PatrolBackgroundService.isBackgroundIsolate) {
      PatrolBackgroundService.relayCheckpointSuccessToUi(checkpointName);
    }
  }

  /// Returns `true` when a pulse was triggered on this isolate.
  static Future<bool> vibrate() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) return false;

      final hasAmplitude = await Vibration.hasAmplitudeControl();
      if (hasAmplitude == true) {
        await Vibration.vibrate(
          pattern: [0, 120, 80, 120],
          intensities: [0, 200, 0, 255],
        );
        return true;
      }

      await Vibration.vibrate(pattern: [0, 120, 80, 120]);
      return true;
    } on MissingPluginException catch (e, st) {
      if (kDebugMode) {
        debugPrint('PatrolCheckpointSuccessFeedback: $e\n$st');
      }
      return false;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('PatrolCheckpointSuccessFeedback: $e\n$st');
      }
      return false;
    }
  }
}
