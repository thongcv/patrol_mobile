import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import '../l10n/app_localizations.dart';
import '../services/app_locale_store.dart';
import '../services/patrol_tracking_config_store.dart';
import 'patrol_tts_platform.dart';

/// Single TTS entry point — dedupes across UI + FGS isolates via prefs.
abstract final class PatrolCheckpointTts {
  PatrolCheckpointTts._();

  static final FlutterTts _tts = FlutterTts();
  static Future<void>? _speakChain;
  /// Matches next-round confirm visibility — blocks repeat TTS on sync races.
  static const String _nextRoundDedupeKey = '__next_round_prompt__';
  /// Sentinel relayed via [PatrolFgsInvokeEvents.checkpointSuccess] when FGS TTS fails.
  static const String roundCompletedRelayToken = '__round_completed__';
  static const String _roundCompletedDedupeKey = roundCompletedRelayToken;
  static const String _proximityNavDedupePrefix = '__proximity_nav__';

  /// Speaks round-completed message when background auto-scan finishes all points.
  static Future<bool> speakRoundCompleted({Locale? locale}) async {
    final resolvedLocale = locale ?? await AppLocaleStore.readLocale();
    final message = lookupAppLocalizations(
      resolvedLocale,
    ).patrolBackgroundRoundCompleted;
    final text = message.trim();
    if (text.isEmpty) return false;
    if (!await _tryAcquireSpeakSlot(_roundCompletedDedupeKey)) return false;
    await _markPriorityAnnouncement(text);

    var started = false;
    final future = (_speakChain ?? Future<void>.value()).then((_) async {
      started = await _speak(message: text, locale: resolvedLocale);
      if (!started) {
        await _releaseSpeakSlot(_roundCompletedDedupeKey);
      }
    });
    _speakChain = future;
    await future;
    return started;
  }

  /// Speaks next-round auto-scan prompt (deduped across isolates).
  static Future<bool> speakNextRoundPrompt({
    required String message,
    Locale? locale,
  }) async {
    final text = message.trim();
    if (text.isEmpty) return false;
    if (!await _tryAcquireSpeakSlot(
      _nextRoundDedupeKey,
      window: Duration(
        minutes: (await PatrolTrackingConfigStore.load()).nextRoundConfirmMin,
      ),
    )) {
      return false;
    }
    await _markPriorityAnnouncement(text);

    final resolvedLocale = locale ?? await AppLocaleStore.readLocale();
    var started = false;
    final future = (_speakChain ?? Future<void>.value()).then((_) async {
      started = await _speak(message: text, locale: resolvedLocale);
      if (!started) {
        await _releaseSpeakSlot(_nextRoundDedupeKey);
      }
    });
    _speakChain = future;
    await future;
    return started;
  }

  /// Speaks proximity navigation hint (deduped by message text).
  static Future<bool> speakProximityNavigation({
    required String message,
    Locale? locale,
    Duration? dedupeWindow,
  }) async {
    final text = message.trim();
    if (text.isEmpty) return false;
    // Stay silent while a checkpoint-scan / round announcement is speaking so
    // route guidance never talks over the more important notification.
    if (await isPriorityAnnouncementActive()) return false;
    final slot = '$_proximityNavDedupePrefix:$text';
    if (!await _tryAcquireSpeakSlot(slot, window: dedupeWindow)) return false;

    final resolvedLocale = locale ?? await AppLocaleStore.readLocale();
    var started = false;
    final future = (_speakChain ?? Future<void>.value()).then((_) async {
      started = await _speak(message: text, locale: resolvedLocale);
      if (!started) {
        await _releaseSpeakSlot(slot);
      }
    });
    _speakChain = future;
    await future;
    return started;
  }

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
    await _markPriorityAnnouncement(message);

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

  /// Reserves a cross-isolate window during which route-guidance TTS stays
  /// quiet, sized to the estimated spoken length of [message] (+ a buffer).
  static Future<void> _markPriorityAnnouncement(String message) async {
    final until = DateTime.now()
        .add(_estimateSpeechDuration(message))
        .millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    final existing =
        prefs.getInt(StorageKeys.patrolCheckpointTtsPriorityUntilMs) ?? 0;
    if (until > existing) {
      await prefs.setInt(
        StorageKeys.patrolCheckpointTtsPriorityUntilMs,
        until,
      );
    }
  }

  /// `true` while a checkpoint-scan / round announcement is (or is about to be)
  /// speaking — route-guidance TTS must defer until it finishes.
  static Future<bool> isPriorityAnnouncementActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final until =
        prefs.getInt(StorageKeys.patrolCheckpointTtsPriorityUntilMs) ?? 0;
    return DateTime.now().millisecondsSinceEpoch < until;
  }

  /// Rough spoken-length estimate at the configured slow speech rate, clamped
  /// so even short messages get protected and long ones don't block forever.
  static Duration _estimateSpeechDuration(String message) {
    final chars = message.trim().length;
    final ms = (1000 + chars * 80).clamp(3000, 12000);
    return Duration(milliseconds: ms);
  }

  static Future<bool> _tryAcquireSpeakSlot(
    String checkpointName, {
    Duration? window,
  }) async {
    final config = await PatrolTrackingConfigStore.load();
    final dedupeWindow = window ??
        Duration(seconds: config.checkpointTtsDedupeSec);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lastName = prefs.getString(StorageKeys.patrolCheckpointTtsLastName);
    final lastAtMs = prefs.getInt(StorageKeys.patrolCheckpointTtsLastAtMs) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lastName == checkpointName &&
        now - lastAtMs < dedupeWindow.inMilliseconds) {
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
