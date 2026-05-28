import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../services/app_locale_store.dart';
import '../services/patrol_background_service.dart';
import 'patrol_checkpoint_tts.dart';

/// Vibration + notification when a checkpoint scan succeeds in background.
abstract final class PatrolCheckpointSuccessFeedback {
  PatrolCheckpointSuccessFeedback._();

  static const MethodChannel _vibrationChannel = MethodChannel('vibration');

  /// Two short pulses and a notification with [checkpointName].
  static Future<void> notify({required String checkpointName}) async {
    final name = checkpointName.trim();
    if (name.isEmpty) return;

    developer.log(
      'Checkpoint scanned successfully: $name',
      name: 'PatrolCheckpointSuccessFeedback',
    );
    try {
      await PatrolBackgroundService.showCheckpointScannedNotification(
        name,
      );
    } catch (_) {
    }

    await vibrate();

    final locale = await AppLocaleStore.readLocale();
    final spoke = await PatrolCheckpointTts.speakCheckpoint(
      checkpointName: name,
      locale: locale,
    );

    // FGS fallback: native/flutter TTS may be unavailable in background engine.
    if (!spoke && PatrolBackgroundService.isBackgroundIsolate) {
      PatrolBackgroundService.relayCheckpointSuccessToUi(name);
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
    } catch (_) {
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
    } on MissingPluginException {
      return false;
    } catch (_) {
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
    } catch (_) {
      return false;
    }
  }
}
