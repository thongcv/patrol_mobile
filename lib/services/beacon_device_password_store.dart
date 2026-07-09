import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import '../http/api_response.dart';

/// Optional beacon configure password (HM-10 PIN, etc.) — remembered per device.
abstract final class BeaconDevicePasswordStore {
  BeaconDevicePasswordStore._();

  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.beaconDevicePassword);
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  /// Login `data.devicePassword` — company default for beacon configure.
  static Future<void> saveFromLoginEnvelope(Map<String, dynamic>? data) async {
    await save(jsonStr(data?['devicePassword']));
  }

  static Future<void> save(String? password) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = password?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(StorageKeys.beaconDevicePassword);
      return;
    }
    await prefs.setString(StorageKeys.beaconDevicePassword, trimmed);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.beaconDevicePassword);
  }
}
