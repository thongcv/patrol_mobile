import 'bluetooth_beacon_reader_types.dart';

/// Target iBeacon broadcast values written to hardware.
class IBeaconSettings {
  const IBeaconSettings({
    required this.uuid,
    required this.major,
    required this.minor,
    this.txPowerAt1m = -59,
    this.advertisingName,
  });

  /// Proximity UUID (128-bit, with or without dashes).
  final String uuid;

  /// iBeacon major (0–65535).
  final int major;

  /// iBeacon minor (0–65535).
  final int minor;

  /// Measured power at 1 m in dBm (Apple iBeacon field).
  final int txPowerAt1m;

  /// Optional BLE local name written to hardware when supported.
  final String? advertisingName;

  bool get isValid {
    final u = uuid.trim();
    if (!isBluetoothUuidIdentifier(u)) return false;
    if (major < 0 || major > 0xFFFF) return false;
    if (minor < 0 || minor > 0xFFFF) return false;
    return true;
  }
}

enum IBeaconConfigureFailure {
  unavailable,
  disabled,
  permissionDenied,
  timeout,
  deviceNotFound,
  connectionFailed,
  unsupportedDevice,
  unsupportedProtocol,
  commandFailed,
  verifyFailed,
  invalidSettings,
  wrongPassword,
}

enum JoywayLoginResult {
  success,
  /// Device replied with an explicit login rejection packet.
  rejected,
  /// Timeout or transport error before a definitive login response.
  failed,
}

/// Joyway GATT login on RX: `0x00 0x01`, `12`, then 12 password bytes (0x00 = factory empty).
String normalizeJoywayBeaconPassword(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.length > 12) return trimmed.substring(0, 12);
  return trimmed;
}

IBeaconConfigureFailure joywayLoginFailureFor({
  required JoywayLoginResult result,
  required String loginPassword,
}) {
  if (result == JoywayLoginResult.success) {
    throw ArgumentError.value(result, 'result', 'must not be success');
  }
  if (result == JoywayLoginResult.rejected) {
    return IBeaconConfigureFailure.wrongPassword;
  }
  return loginPassword.trim().isNotEmpty
      ? IBeaconConfigureFailure.wrongPassword
      : IBeaconConfigureFailure.connectionFailed;
}

/// Normalizes optional HM-10-style PIN (6 digits). Returns null when empty/invalid.
String? normalizeHm10DevicePassword(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  if (digits.length >= 6) return digits.substring(0, 6);
  return digits.padLeft(6, '0');
}

class IBeaconConfigureResult {
  const IBeaconConfigureResult._({
    this.remoteId,
    this.beacon,
    this.failure,
  });

  const IBeaconConfigureResult.success({
    required String remoteId,
    BluetoothBeaconDetails? beacon,
  }) : this._(remoteId: remoteId, beacon: beacon);

  const IBeaconConfigureResult.failure(IBeaconConfigureFailure reason)
      : this._(failure: reason);

  final String? remoteId;
  final BluetoothBeaconDetails? beacon;
  final IBeaconConfigureFailure? failure;

  bool get ok => failure == null && remoteId != null && remoteId!.isNotEmpty;
}

/// Splits a proximity UUID into four 4-byte hex chunks for HM-10 `AT+IBE0`…`3`.
List<String> iBeaconUuidCommandParts(String uuid) {
  final hex = uuid.trim().toUpperCase().replaceAll('-', '');
  if (hex.length != 32) {
    throw ArgumentError.value(uuid, 'uuid', 'expected 128-bit UUID');
  }
  return [
    hex.substring(0, 8),
    hex.substring(8, 16),
    hex.substring(16, 24),
    hex.substring(24, 32),
  ];
}

String iBeaconMajorCommandValue(int major) {
  if (major < 0 || major > 0xFFFF) {
    throw ArgumentError.value(major, 'major', 'expected 0–65535');
  }
  return '0x${major.toRadixString(16).padLeft(4, '0').toUpperCase()}';
}

String iBeaconMinorCommandValue(int minor) {
  if (minor < 0 || minor > 0xFFFF) {
    throw ArgumentError.value(minor, 'minor', 'expected 0–65535');
  }
  return '0x${minor.toRadixString(16).padLeft(4, '0').toUpperCase()}';
}
