import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../services/patrol_background_service.dart';

/// Vibration + notification when a checkpoint scan succeeds in background.
abstract final class PatrolCheckpointSuccessFeedback {
  PatrolCheckpointSuccessFeedback._();

  static const MethodChannel _vibrationChannel = MethodChannel('vibration');

  /// Two short pulses and a notification with [checkpointName].
  static Future<void> notify({required String checkpointName}) async {
    try {
      await PatrolBackgroundService.showCheckpointScannedNotification(
        checkpointName,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('PatrolCheckpointSuccessFeedback notify: $e\n$st');
      }
    }

    if (await vibrate()) return;

    // UI isolate may be suspended when the app is backgrounded; still try.
    if (PatrolBackgroundService.isBackgroundIsolate) {
      PatrolBackgroundService.relayCheckpointSuccessToUi(checkpointName);
    }
  }

  /// Returns `true` when a pulse was triggered on this isolate.
  static Future<bool> vibrate() async {
    if (Platform.isAndroid) {
      if (await _vibrateWithMethodChannel()) return true;
      if (await _vibrateWithPlugin()) return true;
      return false;
    }
    if (Platform.isIOS) {
      if (await _vibrateWithPlugin()) return true;
      if (await _hapticPulse()) return true;
      return false;
    }
    if (await _vibrateWithPlugin()) return true;
    return false;
  }

  static Future<bool> _hapticPulse() async {
    if (!Platform.isIOS) return false;
    try {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.mediumImpact();
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('PatrolCheckpointSuccessFeedback haptic: $e\n$st');
      }
      return false;
    }
  }

  static Future<bool> _vibrateWithPlugin() async {
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

      if (await Vibration.hasCustomVibrationsSupport()) {
        await Vibration.vibrate(pattern: [0, 120, 80, 120]);
        return true;
      }

      await Vibration.vibrate(duration: 120);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await Vibration.vibrate(duration: 120);
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

  static Future<bool> _vibrateWithMethodChannel() async {
    if (!Platform.isAndroid) return false;
    try {
      await _vibrationChannel.invokeMethod<void>('vibrate', <String, dynamic>{
        'pattern': <int>[0, 120, 80, 120],
        'repeat': -1,
        'intensities': <int>[],
        'duration': 500,
        'amplitude': -1,
      });
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('PatrolCheckpointSuccessFeedback channel: $e\n$st');
      }
      return false;
    }
  }
}
