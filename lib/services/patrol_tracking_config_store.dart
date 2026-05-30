import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import '../http/api_response.dart';
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
    await p.reload();
  }

  static Future<PatrolTrackingConfig> load() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
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

  static Future<bool> backgroundAutoScanEnabled() async =>
      (await load()).backgroundAutoScan;

  /// STOMP `tracking-config-changed` — merge frame fields into stored config.
  /// Saves only when merged config differs from current.
  static Future<({PatrolTrackingConfig config, bool updated})?>
      applyFromActiveRoundFrame(
    Map<String, dynamic> map,
  ) async {
    final source = jsonMapCoerce(map['config']) ?? map;
    if (!PatrolTrackingConfig.hasFrameFields(source)) return null;

    final current = await load();
    final next = PatrolTrackingConfig.mergeFrameSource(current, source);
    if (current == next) {
      return (config: current, updated: false);
    }
    await save(next);
    return (config: next, updated: true);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(StorageKeys.patrolTrackingConfig);
  }
}
