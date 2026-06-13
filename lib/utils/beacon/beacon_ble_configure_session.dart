import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../models/beacon_configure_protocol.dart';

/// In-memory authenticated BLE session between login validate and configure.
///
/// Keeps GATT open while the user fills the settings form so configure can skip
/// a second connect + login round-trip.
class BeaconBleConfigureSession {
  BeaconBleConfigureSession._({
    required this.protocol,
    required this.remoteId,
    required this.loginKey,
    required this.device,
    this.joywayRx,
    this.joywayTx,
    this.joywayMtu = 23,
    this.hm10ConfigChar,
  });

  final BeaconConfigureProtocol protocol;
  final String remoteId;
  final String loginKey;
  final BluetoothDevice device;
  final BluetoothCharacteristic? joywayRx;
  final BluetoothCharacteristic? joywayTx;
  final int joywayMtu;
  final BluetoothCharacteristic? hm10ConfigChar;

  static BeaconBleConfigureSession? _active;

  static bool get hasActive => _active != null;

  static bool matches({
    required BeaconConfigureProtocol protocol,
    required String remoteId,
    required String loginKey,
  }) {
    final s = _active;
    if (s == null || !s.device.isConnected) return false;
    return s.protocol == protocol &&
        s.remoteId == remoteId.trim().toUpperCase() &&
        s.loginKey == loginKey;
  }

  static BeaconBleConfigureSession? activeIfMatches({
    required BeaconConfigureProtocol protocol,
    required String remoteId,
    required String loginKey,
  }) {
    if (!matches(
      protocol: protocol,
      remoteId: remoteId,
      loginKey: loginKey,
    )) {
      return null;
    }
    return _active;
  }

  static void adoptJoyway({
    required String remoteId,
    required String loginKey,
    required BluetoothDevice device,
    required BluetoothCharacteristic rxChar,
    required BluetoothCharacteristic txChar,
    required int mtu,
  }) {
    _replace(
      BeaconBleConfigureSession._(
        protocol: BeaconConfigureProtocol.joyway,
        remoteId: remoteId.trim().toUpperCase(),
        loginKey: loginKey,
        device: device,
        joywayRx: rxChar,
        joywayTx: txChar,
        joywayMtu: mtu,
      ),
    );
  }

  static void adoptHm10({
    required String remoteId,
    required String loginKey,
    required BluetoothDevice device,
    required BluetoothCharacteristic configChar,
  }) {
    _replace(
      BeaconBleConfigureSession._(
        protocol: BeaconConfigureProtocol.hm10Ffe0,
        remoteId: remoteId.trim().toUpperCase(),
        loginKey: loginKey,
        device: device,
        hm10ConfigChar: configChar,
      ),
    );
  }

  static void _replace(BeaconBleConfigureSession next) {
    final prev = _active;
    _active = next;
    if (prev != null && prev.device.remoteId != next.device.remoteId) {
      prev._disconnectQuietly();
    }
  }

  static Future<void> clear() async {
    final s = _active;
    _active = null;
    if (s != null) await s._disconnectQuietly();
  }

  Future<void> _disconnectQuietly() async {
    try {
      if (device.isConnected) await device.disconnect(queue: false);
    } catch (_) {}
  }
}
