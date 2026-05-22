import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/account_session_store.dart';
import 'bluetooth_beacon_reader_types.dart';

bool get isBluetoothScanSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

Future<bool> _ensureBlePermissions() async {
  if (Platform.isAndroid) {
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    if (!scan.isGranted || !connect.isGranted) return false;
    final location = await Permission.locationWhenInUse.status;
    if (!location.isGranted) {
      final requested = await Permission.locationWhenInUse.request();
      if (!requested.isGranted) return false;
    }
    return true;
  }
  if (Platform.isIOS) {
    final bt = await Permission.bluetooth.request();
    return bt.isGranted;
  }
  return false;
}

Future<bool> _ensureAdapterOn() async {
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

String _normalizeBleIdentifier(String raw) {
  final trimmed = raw.trim();
  if (trimmed.contains(':')) {
    return trimmed.toUpperCase();
  }
  return trimmed.toUpperCase();
}

List<int>? _uuidBytesFromIdentifier(String raw) {
  final hex = raw.trim().toUpperCase().replaceAll('-', '');
  if (hex.length != 32 || !RegExp(r'^[0-9A-F]+$').hasMatch(hex)) {
    return null;
  }
  final bytes = <int>[];
  for (var i = 0; i < 32; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return bytes;
}

bool _isBleMacIdentifier(String raw) =>
    _normalizeBleIdentifier(raw).contains(':');

/// MAC-only filters for [FlutterBluePlus.startScan.withRemoteIds].
List<String> _hardwareScanMacRemoteIds(List<String>? remoteIds) {
  if (remoteIds == null || remoteIds.isEmpty) return const [];
  return remoteIds
      .where(_isBleMacIdentifier)
      .map(_normalizeBleIdentifier)
      .where((id) => id.isNotEmpty)
      .toList();
}

/// iBeacon MSD filters: all iBeacons, or a specific proximity UUID from [remoteIds].
List<MsdFilter> _iBeaconScanMsdFilters(List<String>? remoteIds) {
  final uuidBytes = <List<int>>[];
  if (remoteIds != null) {
    for (final raw in remoteIds) {
      final bytes = _uuidBytesFromIdentifier(raw);
      if (bytes != null) uuidBytes.add(bytes);
    }
  }
  if (uuidBytes.isEmpty) {
    return [
      MsdFilter(
        _appleManufacturerId,
        data: _iBeaconMsdPrefix,
        mask: [0xFF, 0xFF],
      ),
    ];
  }
  return [
    for (final uuid in uuidBytes)
      MsdFilter(
        _appleManufacturerId,
        data: [..._iBeaconMsdPrefix, ...uuid],
        mask: [0xFF, 0xFF, ...List.filled(16, 0xFF)],
      ),
  ];
}

bool _identifierMatchesRemoteIds(String identifier, List<String> remoteIds) {
  if (remoteIds.isEmpty) return true;
  for (final raw in remoteIds) {
    if (bluetoothIdentifiersMatch(raw, identifier)) return true;
  }
  return false;
}

String? _formatUuid(List<int> bytes) {
  if (bytes.length != 16) return null;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-'
          '${hex.substring(8, 12)}-'
          '${hex.substring(12, 16)}-'
          '${hex.substring(16, 20)}-'
          '${hex.substring(20)}'
      .toUpperCase();
}

/// Apple manufacturer ID in BLE advertisements.
const _appleManufacturerId = 0x004C;

/// iBeacon type/length prefix inside Apple manufacturer data.
const _iBeaconMsdPrefix = [0x02, 0x15];

int _signedByte(int value) => value > 127 ? value - 256 : value;

class _IBeaconMeta {
  const _IBeaconMeta({this.major, this.minor, this.txPowerAt1m});

  final int? major;
  final int? minor;
  final int? txPowerAt1m;
}

_IBeaconMeta? _iBeaconMetaFromMsd(Map<int, List<int>> msd) {
  final apple = msd[_appleManufacturerId];
  if (apple == null || apple.length < 23) return null;
  if (apple[0] != _iBeaconMsdPrefix[0] || apple[1] != _iBeaconMsdPrefix[1]) {
    return null;
  }
  return _IBeaconMeta(
    major: (apple[18] << 8) | apple[19],
    minor: (apple[20] << 8) | apple[21],
    txPowerAt1m: _signedByte(apple[22]),
  );
}

bool _isIBeaconAdvertisement(ScanResult result) {
  final apple = result.advertisementData.manufacturerData[_appleManufacturerId];
  return apple != null &&
      apple.length >= 2 &&
      apple[0] == _iBeaconMsdPrefix[0] &&
      apple[1] == _iBeaconMsdPrefix[1];
}

String? _iBeaconUuidFromMsd(Map<int, List<int>> msd) {
  final apple = msd[_appleManufacturerId];
  if (apple == null || apple.length < 23) return null;
  if (apple[0] != _iBeaconMsdPrefix[0] || apple[1] != _iBeaconMsdPrefix[1]) {
    return null;
  }
  return _formatUuid(apple.sublist(2, 18));
}

class _BeaconCandidate {
  const _BeaconCandidate({
    required this.identifier,
    required this.rssi,
    this.deviceAddress,
    this.deviceName,
    this.major,
    this.minor,
    this.txPowerAt1m,
  });

  final String identifier;
  final int rssi;
  final String? deviceAddress;
  final String? deviceName;
  final int? major;
  final int? minor;
  final int? txPowerAt1m;

  BluetoothBeaconDetails toDetails() {
    return BluetoothBeaconDetails(
      rssi: rssi,
      distanceMeters: BluetoothBeaconDetails.estimateDistanceMeters(
        rssi: rssi,
        txPowerAt1m: txPowerAt1m,
      ),
      deviceAddress: deviceAddress,
      deviceName: deviceName,
      major: major,
      minor: minor,
      txPowerAt1m: txPowerAt1m,
    );
  }
}

_BeaconCandidate? _candidateFromIBeaconScanResult(ScanResult result) {
  if (!_isIBeaconAdvertisement(result)) return null;
  final msd = result.advertisementData.manufacturerData;
  final ibeacon = _iBeaconUuidFromMsd(msd);
  final remote = result.device.remoteId.str.trim();
  final identifier = ibeacon != null && ibeacon.isNotEmpty
      ? ibeacon
      : remote.isEmpty
      ? null
      : _normalizeBleIdentifier(remote);
  if (identifier == null || identifier.isEmpty) return null;

  final meta = _iBeaconMetaFromMsd(msd);
  final name = result.advertisementData.advName.trim();
  return _BeaconCandidate(
    identifier: identifier,
    rssi: result.rssi,
    deviceAddress: remote.isEmpty ? null : _normalizeBleIdentifier(remote),
    deviceName: name.isEmpty ? null : name,
    major: meta?.major,
    minor: meta?.minor,
    txPowerAt1m: meta?.txPowerAt1m,
  );
}

void _trackNearestCandidate(
  Map<String, _BeaconCandidate> bestById,
  ScanResult result, {
  required int minRssi,
  List<String>? remoteIds,
}) {
  if (result.rssi < minRssi) return;
  final candidate = _candidateFromIBeaconScanResult(result);
  if (candidate == null) return;
  if (remoteIds != null &&
      remoteIds.isNotEmpty &&
      !_identifierMatchesRemoteIds(candidate.identifier, remoteIds)) {
    return;
  }
  final prev = bestById[candidate.identifier];
  if (prev == null || candidate.rssi > prev.rssi) {
    bestById[candidate.identifier] = candidate;
  }
}

_BeaconCandidate? _pickNearestBeacon(Map<String, _BeaconCandidate> bestById) {
  if (bestById.isEmpty) return null;
  var best = bestById.values.first;
  for (final candidate in bestById.values) {
    if (candidate.rssi > best.rssi) {
      best = candidate;
    }
  }
  return best;
}

BluetoothReadResult _successFromCandidate(_BeaconCandidate candidate) {
  return BluetoothReadResult.success(
    candidate.identifier,
    beacon: candidate.toDetails(),
  );
}

/// Tracks consecutive strong-signal hits for one leading identifier.
class _StrongSignalTracker {
  _StrongSignalTracker({required this.requiredHits});

  final int requiredHits;
  String? _leaderId;
  int _hits = 0;

  bool register(_BeaconCandidate? leader, {required int successRssi}) {
    if (leader == null || leader.rssi < successRssi) {
      _leaderId = null;
      _hits = 0;
      return false;
    }
    if (_leaderId == leader.identifier) {
      _hits++;
    } else {
      _leaderId = leader.identifier;
      _hits = 1;
    }
    return _hits >= requiredHits;
  }
}

Future<void> _stopScanIfActive() async {
  if (!FlutterBluePlus.isScanningNow) return;
  try {
    await FlutterBluePlus.stopScan();
  } catch (_) {}
}

List<String>? _companyBeaconRemoteIds() {
  final uuid = AccountSessionStore.instance.companyBeaconUuid;
  return uuid != null ? [uuid] : null;
}

Future<BluetoothReadResult> readBluetoothBeaconIdentifier({
  Duration timeout = kBluetoothDiscoveryScanTimeout,
  int minRssi = kBluetoothDiscoveryMinRssi,
  int successRssi = kBluetoothDiscoverySuccessRssi,
  int stableHits = kBluetoothDiscoveryStableHits,
  List<String>? remoteIds,
}) async {
  if (!isBluetoothScanSupported) {
    return const BluetoothReadResult.failure(BluetoothReadFailure.unavailable);
  }

  try {
    if (!await FlutterBluePlus.isSupported) {
      return const BluetoothReadResult.failure(BluetoothReadFailure.unavailable);
    }
  } catch (_) {
    return const BluetoothReadResult.failure(BluetoothReadFailure.unavailable);
  }

  if (!await _ensureBlePermissions()) {
    return const BluetoothReadResult.failure(
      BluetoothReadFailure.permissionDenied,
    );
  }

  if (!await _ensureAdapterOn()) {
    return const BluetoothReadResult.failure(BluetoothReadFailure.disabled);
  }

  final filterIds = remoteIds ?? _companyBeaconRemoteIds();
  final bestById = <String, _BeaconCandidate>{};
  final discoveredDevices = <ScanResult>[];
  StreamSubscription<List<ScanResult>>? resultsSub;
  StreamSubscription<bool>? scanningSub;
  final sessionDone = Completer<void>();
  final strongTracker = _StrongSignalTracker(
    requiredHits: stableHits < 1 ? 1 : stableHits,
  );
  BluetoothReadResult? earlyResult;

  void absorbResults(List<ScanResult> results) {
    for (final r in results) {
      // Chỉ xử lý thiết bị mới hoặc có thay đổi quan trọng (RSSI mạnh hơn).
      final existingIndex = discoveredDevices.indexWhere(
        (d) => d.device.remoteId == r.device.remoteId,
      );
      final isNew = existingIndex < 0;
      if (isNew) {
        discoveredDevices.add(r);
      } else if (r.rssi <= discoveredDevices[existingIndex].rssi) {
        continue;
      } else {
        discoveredDevices[existingIndex] = r;
      }
      _trackNearestCandidate(
        bestById,
        r,
        minRssi: minRssi,
        remoteIds: filterIds,
      );
    }
  }

  void tryFinishEarly() {
    if (earlyResult != null || sessionDone.isCompleted) return;
    final nearest = _pickNearestBeacon(bestById);
    if (!strongTracker.register(nearest, successRssi: successRssi)) return;
    earlyResult = _successFromCandidate(nearest!);
    if (!sessionDone.isCompleted) sessionDone.complete();
    unawaited(_stopScanIfActive());
  }

  try {
    resultsSub = FlutterBluePlus.onScanResults.listen((results) {
      absorbResults(results);
      tryFinishEarly();
    });
    absorbResults(FlutterBluePlus.lastScanResults);
    tryFinishEarly();

    // Only end session after scan has started, then stopped. Subscribing
    // before [startScan] would see `false` and finish with an empty map.
    var sawScanning = false;
    scanningSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (scanning) sawScanning = true;
      if (sawScanning && !scanning && !sessionDone.isCompleted) {
        sessionDone.complete();
      }
    });

    // Hardware filters (OR): MSD iBeacon, MAC.
    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidScanMode: AndroidScanMode.lowLatency,
      continuousUpdates: true,
      androidUsesFineLocation: true,
      withMsd: _iBeaconScanMsdFilters(filterIds),
      withRemoteIds: _hardwareScanMacRemoteIds(filterIds),
    );

    try {
      await sessionDone.future.timeout(
        timeout + const Duration(seconds: 2),
      );
    } on TimeoutException {
      await _stopScanIfActive();
      if (!sessionDone.isCompleted) sessionDone.complete();
    }

    if (earlyResult != null) return earlyResult!;

    final nearest = _pickNearestBeacon(bestById);
    if (nearest == null) {
      return const BluetoothReadResult.failure(BluetoothReadFailure.timeout);
    }
    return _successFromCandidate(nearest);
  } catch (_) {
    if (earlyResult != null) return earlyResult!;
    final nearest = _pickNearestBeacon(bestById);
    if (nearest != null) {
      return _successFromCandidate(nearest);
    }
    return const BluetoothReadResult.failure(BluetoothReadFailure.failed);
  } finally {
    await resultsSub?.cancel();
    await scanningSub?.cancel();
    await _stopScanIfActive();
  }
}
