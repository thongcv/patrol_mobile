import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import '../l10n/app_localizations.dart';
import '../services/app_locale_store.dart';
import 'patrol_tts_platform.dart';

/// Single TTS entry point — dedupes across UI + FGS isolates via prefs.
abstract final class PatrolCheckpointTts {
  PatrolCheckpointTts._();

  static final FlutterTts _tts = FlutterTts();
  static Future<void>? _speakChain;
  static const Duration _dedupeWindow = Duration(seconds: 8);

  /// Speaks localized checkpoint-scanned message once per [checkpointName].
  /// Returns `true` when a speak attempt was started.
  static Future<bool> speakCheckpoint({
    required String checkpointName,
    Locale? locale,
  }) async {
    final name = checkpointName.trim();
    if (name.isEmpty) return false;
    if (!await _tryAcquireSpeakSlot(name)) return false;

    final resolvedLocale = locale ?? await AppLocaleStore.readLocale();
    final message = lookupAppLocalizations(
      resolvedLocale,
    ).patrolBackgroundCheckpointScanned(name);

    var started = false;
    final future = (_speakChain ?? Future<void>.value()).then((_) async {
      started = await _speak(message: message, locale: resolvedLocale);
      if (!started) {
        await _releaseSpeakSlot(name);
      }
    });
    _speakChain = future;
    await future;
    return started;
  }

  static Future<bool> _tryAcquireSpeakSlot(String checkpointName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lastName = prefs.getString(StorageKeys.patrolCheckpointTtsLastName);
    final lastAtMs = prefs.getInt(StorageKeys.patrolCheckpointTtsLastAtMs) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lastName == checkpointName &&
        now - lastAtMs < _dedupeWindow.inMilliseconds) {
      return false;
    }
    await prefs.setString(StorageKeys.patrolCheckpointTtsLastName, checkpointName);
    await prefs.setInt(StorageKeys.patrolCheckpointTtsLastAtMs, now);
    return true;
  }

  static Future<void> _releaseSpeakSlot(String checkpointName) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(StorageKeys.patrolCheckpointTtsLastName) != checkpointName) {
      return;
    }
    await prefs.remove(StorageKeys.patrolCheckpointTtsLastName);
    await prefs.remove(StorageKeys.patrolCheckpointTtsLastAtMs);
  }

  static Future<bool> _speak({
    required String message,
    required Locale locale,
  }) async {
    final languageTag = _resolveLanguage(locale);
    if (await _speakWithFlutterTts(message, languageTag)) {
      if (kDebugMode) {
        developer.log('flutter_tts spoke: $message', name: 'PatrolCheckpointTts');
      }
      return true;
    }
    if (await PatrolTtsPlatform.speak(text: message, languageTag: languageTag)) {
      if (kDebugMode) {
        developer.log('native TTS spoke: $message', name: 'PatrolCheckpointTts');
      }
      return true;
    }
    if (kDebugMode) {
      developer.log('TTS failed: $message', name: 'PatrolCheckpointTts');
    }
    return false;
  }

  static Future<bool> _speakWithFlutterTts(
    String message,
    String languageTag,
  ) async {
    try {
      await _tts.stop();
      final languages = await _tts.getLanguages;
      if (languages is List) {
        final available = languages.map((e) => e.toString()).toList();
        final picked = _pickLanguage(available, languageTag);
        if (picked != null) {
          await _tts.setLanguage(picked);
        }
      } else {
        await _tts.setLanguage(languageTag);
      }
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(message);
      return true;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static String? _pickLanguage(List<String> available, String preferred) {
    if (available.contains(preferred)) return preferred;
    final lang = preferred.split('-').first;
    for (final code in available) {
      if (code == lang || code.startsWith('$lang-')) return code;
    }
    return available.isNotEmpty ? available.first : null;
  }

  static String _resolveLanguage(Locale locale) {
    final code = locale.languageCode;
    if (code == 'vi') return 'vi-VN';
    if (code == 'en') return 'en-US';
    return code;
  }
}
