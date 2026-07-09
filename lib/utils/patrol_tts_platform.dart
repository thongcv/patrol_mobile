import 'dart:io';

import 'package:flutter/services.dart';

/// Android native TextToSpeech via [MainActivity] — works when [FlutterTts] is unavailable.
abstract final class PatrolTtsPlatform {
  PatrolTtsPlatform._();

  static const MethodChannel _channel = MethodChannel('patrol/tts');

  static Future<bool> speak({
    required String text,
    required String languageTag,
  }) async {
    if (!Platform.isAndroid || text.trim().isEmpty) return false;
    try {
      await _channel.invokeMethod<void>('speak', <String, dynamic>{
        'text': text,
        'language': languageTag,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
