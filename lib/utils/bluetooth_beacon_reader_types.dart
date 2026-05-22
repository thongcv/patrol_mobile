import 'dart:math' as math;

/// Defaults for nearby-beacon discovery (see [readBluetoothBeaconIdentifier]).
const Duration kBluetoothDiscoveryScanTimeout = Duration(seconds: 10);
const int kBluetoothDiscoveryMinRssi = -90;
const int kBluetoothDiscoverySuccessRssi = -78;
const int kBluetoothDiscoveryStableHits = 2;

/// `true` when [raw] looks like an iBeacon proximity UUID (not a BLE MAC).
bool isBluetoothUuidIdentifier(String raw) {
  final hex = raw.trim().toUpperCase().replaceAll('-', '');
  return hex.length == 32 && RegExp(r'^[0-9A-F]+$').hasMatch(hex);
}

/// Whether two stored / scanned BLE ids refer to the same beacon.
bool bluetoothIdentifiersMatch(String a, String b) {
  final left = a.trim();
  final right = b.trim();
  if (left.isEmpty || right.isEmpty) return false;
  final aNorm = left.toUpperCase();
  final bNorm = right.toUpperCase();
  if (aNorm == bNorm) return true;
  final aCompact = aNorm.replaceAll('-', '').replaceAll(':', '');
  final bCompact = bNorm.replaceAll('-', '').replaceAll(':', '');
  return aCompact.isNotEmpty && aCompact == bCompact;
}

enum BluetoothReadFailure {
  unavailable,
  disabled,
  permissionDenied,
  timeout,
  failed,
}

/// Extra data from an iBeacon scan hit.
class BluetoothBeaconDetails {
  const BluetoothBeaconDetails({
    required this.rssi,
    this.distanceMeters,
    this.deviceAddress,
    this.deviceName,
    this.major,
    this.minor,
    this.txPowerAt1m,
  });

  /// Received signal strength in dBm.
  final int rssi;

  /// Estimated distance in meters (path-loss model; not GPS).
  final double? distanceMeters;

  /// BLE MAC / remote id from the advertisement.
  final String? deviceAddress;

  /// Local name from the advertisement, if any.
  final String? deviceName;

  /// iBeacon major, when present.
  final int? major;

  /// iBeacon minor, when present.
  final int? minor;

  /// Calibrated TX power at 1 m from iBeacon packet (dBm).
  final int? txPowerAt1m;

  /// Path-loss estimate: distance ≈ 10^((txPower − rssi) / (10 × n)).
  static double? estimateDistanceMeters({
    required int rssi,
    int? txPowerAt1m,
    double pathLossExponent = 2.0,
  }) {
    if (rssi >= 0) return null;
    final tx = txPowerAt1m ?? -59;
    final ratio = (tx - rssi) / (10 * pathLossExponent);
    final meters = math.pow(10, ratio).toDouble();
    if (!meters.isFinite || meters <= 0) return null;
    return meters;
  }

  static String formatDistanceMeters(double? meters) {
    if (meters == null) return '—';
    if (meters < 0.1) return '<0.1';
    if (meters < 10) return meters.toStringAsFixed(1);
    return meters.toStringAsFixed(0);
  }
}

class BluetoothReadResult {
  const BluetoothReadResult._({this.identifier, this.beacon, this.failure});

  const BluetoothReadResult.success(
    String identifier, {
    BluetoothBeaconDetails? beacon,
  }) : this._(identifier: identifier, beacon: beacon);

  const BluetoothReadResult.failure(BluetoothReadFailure reason)
    : this._(failure: reason);

  final String? identifier;
  final BluetoothBeaconDetails? beacon;
  final BluetoothReadFailure? failure;

  bool get ok => identifier != null && identifier!.isNotEmpty;
}
