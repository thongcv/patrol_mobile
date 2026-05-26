import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import '../models/patrol_tracking_config.dart';

/// Login tracking config — persisted for UI + background isolate.
abstract final class PatrolTrackingConfigStore {
  PatrolTrackingConfigStore._();

  static Future<void> save(PatrolTrackingConfig config) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      StorageKeys.patrolTrackingConfig,
      jsonEncode(config.toJson()),
    );
  }

  static Future<PatrolTrackingConfig> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(StorageKeys.patrolTrackingConfig);
    if (raw == null || raw.trim().isEmpty) {
      return PatrolTrackingConfig.defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return PatrolTrackingConfig.fromJson(decoded);
      }
      if (decoded is Map) {
        return PatrolTrackingConfig.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      //
    }
    return PatrolTrackingConfig.defaults;
  }

  static Future<double> minMoveM() async => (await load()).minMoveM;

  static Future<bool> backgroundEnabled() async => (await load()).background;

  static Future<bool> socketEnabled() async => (await load()).socket;

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(StorageKeys.patrolTrackingConfig);
  }
}
