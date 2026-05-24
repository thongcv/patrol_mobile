import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import '../models/patrol_location_track_payload.dart';

/// Buffers locations when WebSocket is down — flushed on reconnect.
class PatrolTrackOfflineQueue {
  PatrolTrackOfflineQueue._();

  static const int maxItems = 500;

  static Future<void> enqueue(PatrolLocationTrackPayload payload) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(StorageKeys.patrolTrackOfflineQueue);
    final list = <Map<String, dynamic>>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) list.add(item);
            if (item is Map) {
              list.add(Map<String, dynamic>.from(item));
            }
          }
        }
      } catch (_) {
        //
      }
    }
    list.add(payload.toJson());
    while (list.length > maxItems) {
      list.removeAt(0);
    }
    await p.setString(StorageKeys.patrolTrackOfflineQueue, jsonEncode(list));
  }

  static Future<List<PatrolLocationTrackPayload>> drainAll() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(StorageKeys.patrolTrackOfflineQueue);
    await p.remove(StorageKeys.patrolTrackOfflineQueue);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => PatrolLocationTrackPayload.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<int> pendingCount() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(StorageKeys.patrolTrackOfflineQueue);
    if (raw == null || raw.isEmpty) return 0;
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded.length : 0;
    } catch (_) {
      return 0;
    }
  }
}
