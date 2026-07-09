import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import '../models/beacon_configure_protocol.dart';

/// User-selected beacon programming protocol (patrol point screen).
abstract final class BeaconProtocolStore {
  BeaconProtocolStore._();

  static Future<BeaconConfigureProtocol> read() async {
    final prefs = await SharedPreferences.getInstance();
    return BeaconConfigureProtocol.fromStorage(
      prefs.getString(StorageKeys.beaconConfigureProtocol),
    );
  }

  /// Saved protocol from a prior user choice, or `null` if never saved.
  static Future<BeaconConfigureProtocol?> readIfSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.beaconConfigureProtocol);
    if (raw == null || raw.isEmpty) return null;
    return BeaconConfigureProtocol.fromStorage(raw);
  }

  static Future<void> save(BeaconConfigureProtocol protocol) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.beaconConfigureProtocol,
      protocol.storageValue,
    );
  }
}
