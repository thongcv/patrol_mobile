import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android BLE scan (FlutterBluePlus): Location popup first, then Bluetooth.
///
/// Location first (popup), then Bluetooth — required for BLE scan on many OEMs.
Future<bool> beaconBleEnsurePermissions() async {
  if (Platform.isAndroid) {
    final fine = await Permission.locationWhenInUse.request();
    if (!fine.isGranted) {
      final coarse = await Permission.location.request();
      if (!coarse.isGranted) return false;
    }
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    if (!scan.isGranted || !connect.isGranted) return false;
    return true;
  }
  if (Platform.isIOS) {
    final bt = await Permission.bluetooth.request();
    return bt.isGranted;
  }
  return false;
}

Future<bool> beaconBleEnsureAdapterOn() async {
  BluetoothAdapterState state;
  try {
    state = FlutterBluePlus.adapterStateNow != BluetoothAdapterState.unknown
        ? FlutterBluePlus.adapterStateNow
        : await FlutterBluePlus.adapterState
              .where((s) => s != BluetoothAdapterState.unknown)
              .first
              .timeout(const Duration(seconds: 4));
  } catch (_) {
    return false;
  }

  if (state == BluetoothAdapterState.on) return true;
  if (state == BluetoothAdapterState.unavailable) return false;

  if (state == BluetoothAdapterState.off && Platform.isAndroid) {
    try {
      await FlutterBluePlus.turnOn();
    } catch (_) {
      return false;
    }
  }

  try {
    final next = await FlutterBluePlus.adapterState
        .where(
          (s) =>
              s == BluetoothAdapterState.on ||
              s == BluetoothAdapterState.off ||
              s == BluetoothAdapterState.unavailable,
        )
        .first
        .timeout(const Duration(seconds: 8));
    return next == BluetoothAdapterState.on;
  } catch (_) {
    return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
  }
}

DateTime? _lastBleScanEndedAt;

/// Android throttles if [FlutterBluePlus.startScan] follows [stopScan] too soon.
Duration get beaconBleMinGapBetweenScans {
  if (Platform.isAndroid) return const Duration(seconds: 2);
  return const Duration(milliseconds: 400);
}

Future<void> beaconBleStopScanIfActive() async {
  if (!FlutterBluePlus.isScanningNow) return;
  try {
    await FlutterBluePlus.stopScan();
  } catch (_) {}
  _lastBleScanEndedAt = DateTime.now();
}

/// Stop any active scan and wait before the next [FlutterBluePlus.startScan].
Future<void> beaconBleCooldownBeforeScan({
  Duration? minGap,
}) async {
  await beaconBleStopScanIfActive();
  await beaconBleWaitUntilNotScanning(
    timeout: const Duration(seconds: 6),
  );
  final gap = minGap ?? beaconBleMinGapBetweenScans;
  final ended = _lastBleScanEndedAt;
  if (ended == null) return;
  final remain = gap - DateTime.now().difference(ended);
  if (remain > Duration.zero) {
    await Future<void>.delayed(remain);
  }
}

/// Drops any FBP GATT session to [remoteId] before reconnect (Android allows one client).
///
/// When nothing was connected, uses a short settle delay instead of ~1.5s on Android.
Future<void> beaconBleReleaseFbpGattForMac(
  String remoteId, {
  Duration? settleDelay,
}) async {
  if (kIsWeb) return;
  final target = _normalizeBleMacForRelease(remoteId);
  if (target.isEmpty) return;

  var disconnectedAny = false;

  Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      if (!device.isConnected) return;
      disconnectedAny = true;
      await device.disconnect(queue: false);
      try {
        await device.connectionState
            .where((s) => s == BluetoothConnectionState.disconnected)
            .first
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    } catch (_) {}
  }

  try {
    await disconnectDevice(BluetoothDevice.fromId(remoteId.trim()));
  } catch (_) {}

  try {
    for (final device in FlutterBluePlus.connectedDevices) {
      if (_normalizeBleMacForRelease(device.remoteId.str) == target) {
        await disconnectDevice(device);
      }
    }
  } catch (_) {}

  // Let Android tear down GATT client before reconnect.
  if (settleDelay != null) {
    if (settleDelay > Duration.zero) {
      await Future<void>.delayed(settleDelay);
    }
  } else if (disconnectedAny) {
    if (Platform.isAndroid) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  } else if (Platform.isAndroid) {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
}

String _normalizeBleMacForRelease(String raw) {
  final trimmed = raw.trim().toUpperCase();
  if (trimmed.contains(':')) return trimmed;
  if (trimmed.length == 12) {
    return List.generate(6, (i) => trimmed.substring(i * 2, i * 2 + 2)).join(':');
  }
  return trimmed;
}

/// Waits until FBP releases the Android BLE scanner.
Future<void> beaconBleWaitUntilNotScanning({
  Duration timeout = const Duration(seconds: 8),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (!FlutterBluePlus.isScanningNow) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

BluetoothCharacteristic? beaconBleFindCharacteristic(
  List<BluetoothService> services,
  String serviceUuid,
  String charUuid,
) {
  final serviceLower = serviceUuid.toLowerCase();
  final charLower = charUuid.toLowerCase();
  for (final service in services) {
    if (!service.uuid.str128.toLowerCase().contains(serviceLower)) continue;
    for (final c in service.characteristics) {
      if (c.uuid.str128.toLowerCase().contains(charLower)) return c;
    }
  }
  return null;
}

/// Scans for the strongest nearby peripheral, optionally filtered by service UUID.
///
/// When [waitFullDuration] is true, keeps scanning for the full [timeout] (better
/// for configure pre-scan).
Future<ScanResult?> beaconBleScanStrongest({
  required Duration timeout,
  required int minRssi,
  String? withServiceUuid,
  bool waitFullDuration = false,
}) async {
  ScanResult? best;
  StreamSubscription<List<ScanResult>>? sub;
  final done = Completer<void>();

  void consider(List<ScanResult> results) {
    for (final r in results) {
      if (r.rssi < minRssi) continue;
      if (best == null || r.rssi > best!.rssi) {
        best = r;
      }
    }
  }

  try {
    sub = FlutterBluePlus.onScanResults.listen(consider);
    consider(FlutterBluePlus.lastScanResults);

    StreamSubscription<bool>? scanningSub;
    if (!waitFullDuration) {
      var sawScanning = false;
      scanningSub = FlutterBluePlus.isScanning.listen((scanning) {
        if (scanning) sawScanning = true;
        if (sawScanning && !scanning && !done.isCompleted) {
          done.complete();
        }
      });
    }

    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidScanMode: AndroidScanMode.lowLatency,
      continuousUpdates: true,
      androidUsesFineLocation: true,
      androidCheckLocationServices: true,
      withServices: withServiceUuid != null
          ? [Guid(withServiceUuid)]
          : const <Guid>[],
    );

    if (waitFullDuration) {
      await Future<void>.delayed(timeout + const Duration(milliseconds: 400));
    } else {
      try {
        await done.future.timeout(timeout + const Duration(seconds: 2));
      } on TimeoutException {
        await beaconBleStopScanIfActive();
        if (!done.isCompleted) done.complete();
      }
    }

    await scanningSub?.cancel();
  } finally {
    await sub?.cancel();
    await beaconBleStopScanIfActive();
  }

  return best;
}

const _iBeaconMsdPrefix = [0x02, 0x15];

/// Apple company ID in BLE manufacturer data (standard iBeacon).
const int kBleAppleManufacturerId = 0x004C;

/// Hardware scan filter matching [readBluetoothBeaconIdentifier] / patrol scan.
List<MsdFilter> beaconBleIBeaconMsdFilters() => [
  MsdFilter(
    kBleAppleManufacturerId,
    data: _iBeaconMsdPrefix,
    mask: [0xFF, 0xFF],
  ),
];

/// Default RSSI floor for Joyway JW1404 configure via FBP UART.
const int kJoywayConfigureMinRssiDefault = -82;

/// Parses iBeacon from any manufacturer block (not only Apple 0x004C).
BeaconBleIBeaconAdvert? beaconBleParseIBeaconFromMsd(
  Map<int, List<int>> msd,
) {
  for (final entry in msd.entries) {
    final bytes = entry.value;
    final hit = _parseIBeaconBytes(bytes);
    if (hit != null) return hit;
    // Some stacks prefix company ID (0x4C 0x00) before 0x02 0x15.
    final cid = entry.key;
    final prefixed = <int>[
      cid & 0xFF,
      (cid >> 8) & 0xFF,
      ...bytes,
    ];
    final hitPrefixed = _parseIBeaconBytes(prefixed);
    if (hitPrefixed != null) return hitPrefixed;
  }
  return null;
}

/// Scans a raw byte blob for an iBeacon `0x02 0x15` + UUID block.
BeaconBleIBeaconAdvert? beaconBleParseIBeaconRawBytes(List<int> bytes) =>
    _parseIBeaconBytes(bytes);

BeaconBleIBeaconAdvert? _parseIBeaconBytes(List<int> bytes) {
  if (bytes.length < 23) return null;
  for (var i = 0; i <= bytes.length - 23; i++) {
    if (bytes[i] != _iBeaconMsdPrefix[0] || bytes[i + 1] != _iBeaconMsdPrefix[1]) {
      continue;
    }
    final uuid = _formatIBeaconUuid(bytes.sublist(i + 2, i + 18));
    if (uuid == null || uuid.isEmpty) continue;
    return BeaconBleIBeaconAdvert(
      uuid: uuid,
      major: (bytes[i + 18] << 8) | bytes[i + 19],
      minor: (bytes[i + 20] << 8) | bytes[i + 21],
      txPowerAt1m: _signedIBeaconByte(bytes[i + 22]),
    );
  }
  return null;
}

int _signedIBeaconByte(int value) => value > 127 ? value - 256 : value;

String? _formatIBeaconUuid(List<int> bytes) {
  if (bytes.length != 16) return null;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-'
          '${hex.substring(8, 12)}-'
          '${hex.substring(12, 16)}-'
          '${hex.substring(16, 20)}-'
          '${hex.substring(20)}'
      .toUpperCase();
}

/// Parsed iBeacon fields from a scan advertisement (Apple MSD 0x004C / 0x0215).
class BeaconBleIBeaconAdvert {
  const BeaconBleIBeaconAdvert({
    required this.uuid,
    this.major,
    this.minor,
    this.txPowerAt1m,
  });

  final String uuid;
  final int? major;
  final int? minor;
  final int? txPowerAt1m;
}

/// Returns null if the packet is not a valid iBeacon with proximity UUID.
BeaconBleIBeaconAdvert? beaconBleParseIBeaconAdvert(ScanResult result) {
  final adv = result.advertisementData;
  final fromMfr = beaconBleParseIBeaconFromMsd(adv.manufacturerData);
  if (fromMfr != null) return fromMfr;

  // Full MSD blocks include company ID bytes (FBP [msd] getter).
  for (final block in adv.msd) {
    final hit = _parseIBeaconBytes(block);
    if (hit != null) return hit;
  }

  for (final data in adv.serviceData.values) {
    final hit = beaconBleParseIBeaconRawBytes(data);
    if (hit != null) return hit;
  }
  return null;
}

/// Configure picker: parsed iBeacon advertisements only.
bool beaconBleShouldShowInConfigurePicker(
  ScanResult result, {
  int minRssi = -95,
}) {
  if (result.rssi < minRssi) return false;
  return beaconBleParseIBeaconAdvert(result) != null;
}

bool get isBeaconBleConfigureSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

BluetoothDevice beaconBleDeviceFromRemoteId(String remoteId) =>
    BluetoothDevice.fromId(remoteId.trim());

Future<void> beaconBleConnect(
  BluetoothDevice device, {
  Duration timeout = const Duration(seconds: 12),
}) =>
    device.connect(
      license: License.nonprofit,
      timeout: timeout,
      autoConnect: false,
      mtu: null,
    );

/// JW1404 often rejects 512 ([GATT_INVALID_PDU]); try smaller MTU, else stay at 23.
Future<int> beaconBleNegotiateMtu(BluetoothDevice device) async {
  if (!device.isConnected) return device.mtuNow;
  for (final target in const [128, 185, 64]) {
    if (!device.isConnected) break;
    try {
      final mtu = await device
          .requestMtu(target, predelay: 0.08)
          .timeout(const Duration(seconds: 2));
      if (mtu > 23) return mtu;
    } catch (_) {
      if (!device.isConnected) break;
    }
  }
  return device.mtuNow;
}

int beaconBleMaxAttWriteBytes(int mtu) => (mtu - 3).clamp(8, 512);

Future<void> beaconBleWriteCharacteristic(
  BluetoothCharacteristic characteristic,
  List<int> data, {
  required int mtu,
}) async {
  final maxChunk = beaconBleMaxAttWriteBytes(mtu);
  final withoutResponse = !characteristic.properties.write &&
      characteristic.properties.writeWithoutResponse;

  for (var offset = 0; offset < data.length; offset += maxChunk) {
    final end = offset + maxChunk > data.length ? data.length : offset + maxChunk;
    await characteristic.write(
      data.sublist(offset, end),
      withoutResponse: withoutResponse,
    );
    if (end < data.length) {
      await Future<void>.delayed(const Duration(milliseconds: 35));
    }
  }
}
