import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/account_session_store.dart';
import 'beacon_ble_session.dart';
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

/// iBeacon MSD filters: all iBeacons, or a specific proximity UUID from [uuids].
List<MsdFilter> _iBeaconScanMsdFilters(List<String>? uuids) {
  final uuidBytes = <List<int>>[];
  if (uuids != null) {
    for (final raw in uuids) {
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

bool _candidateMatchesScanFilters(
  _BeaconCandidate candidate, {
  List<String> uuids = const [],
  List<String> remoteIds = const [],
}) {
  if (uuids.isEmpty && remoteIds.isEmpty) return true;

  var uuidOk = uuids.isEmpty;
  final scannedUuid = candidate.uuid?.trim();
  if (!uuidOk && scannedUuid != null && scannedUuid.isNotEmpty) {
    for (final raw in uuids) {
      if (bluetoothIdentifiersMatch(raw, scannedUuid)) {
        uuidOk = true;
        break;
      }
    }
  }

  var remoteOk = remoteIds.isEmpty;
  final scannedRemote = candidate.remoteId?.trim();
  if (!remoteOk && scannedRemote != null && scannedRemote.isNotEmpty) {
    for (final raw in remoteIds) {
      if (bluetoothIdentifiersMatch(raw, scannedRemote)) {
        remoteOk = true;
        break;
      }
    }
  }

  if (uuids.isNotEmpty && remoteIds.isNotEmpty) return uuidOk || remoteOk;
  if (uuids.isNotEmpty) return uuidOk;
  return remoteOk;
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

/// 1D Kalman smoother for noisy BLE RSSI (dBm).
class _RssiKalmanFilter {
  bool _initialized = false;
  double _estimate = 0;
  double _errorVariance = 0;

  static const double _processNoise = 0.5;
  static const double _measurementNoise = 4.0;

  int filter(int rssi) {
    if (!_initialized) {
      _estimate = rssi.toDouble();
      _errorVariance = _measurementNoise;
      _initialized = true;
      return rssi;
    }

    final predictedVariance = _errorVariance + _processNoise;
    final kalmanGain =
        predictedVariance / (predictedVariance + _measurementNoise);
    _estimate += kalmanGain * (rssi - _estimate);
    _errorVariance = (1.0 - kalmanGain) * predictedVariance;
    return _estimate.round();
  }
}

class _BeaconCandidate {
  const _BeaconCandidate({
    this.uuid,
    this.remoteId,
    required this.rssi,
    this.deviceName,
    this.major,
    this.minor,
    this.txPowerAt1m,
  });

  final String? uuid;
  final String? remoteId;
  final int rssi;
  final String? deviceName;
  final int? major;
  final int? minor;
  final int? txPowerAt1m;

  String get _trackingKey {
    final remote = remoteId?.trim();
    if (remote != null && remote.isNotEmpty) return remote;
    return uuid?.trim() ?? '';
  }

  BluetoothBeaconDetails toDetails() {
    return BluetoothBeaconDetails(
      rssi: rssi,
      distanceMeters: BluetoothBeaconDetails.estimateDistanceMeters(
        rssi: rssi,
        txPowerAt1m: txPowerAt1m,
      ),
      deviceAddress: remoteId,
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
  final normalizedRemote =
      remote.isEmpty ? null : _normalizeBleIdentifier(remote);
  final uuid =
      ibeacon != null && ibeacon.isNotEmpty ? ibeacon : null;
  if ((uuid == null || uuid.isEmpty) &&
      (normalizedRemote == null || normalizedRemote.isEmpty)) {
    return null;
  }

  final meta = _iBeaconMetaFromMsd(msd);
  final name = result.advertisementData.advName.trim();
  return _BeaconCandidate(
    uuid: uuid,
    remoteId: normalizedRemote,
    rssi: result.rssi,
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
  required Map<String, _RssiKalmanFilter> rssiFilters,
  List<String> uuids = const [],
  List<String> remoteIds = const [],
}) {
  if (result.rssi < minRssi) return;
  final candidate = _candidateFromIBeaconScanResult(result);
  if (candidate == null) return;
  if (!_candidateMatchesScanFilters(
    candidate,
    uuids: uuids,
    remoteIds: remoteIds,
  )) {
    return;
  }
  final key = candidate._trackingKey;
  if (key.isEmpty) return;
  final filteredRssi =
      rssiFilters.putIfAbsent(key, _RssiKalmanFilter.new).filter(candidate.rssi);
  if (filteredRssi < minRssi) return;
  bestById[key] = _BeaconCandidate(
    uuid: candidate.uuid,
    remoteId: candidate.remoteId,
    rssi: filteredRssi,
    deviceName: candidate.deviceName,
    major: candidate.major,
    minor: candidate.minor,
    txPowerAt1m: candidate.txPowerAt1m,
  );
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
    uuid: candidate.uuid,
    remoteId: candidate.remoteId,
    beacon: candidate.toDetails(),
  );
}

/// Tracks consecutive strong-signal hits for one leading beacon.
class _StrongSignalTracker {
  _StrongSignalTracker({required this.requiredHits});

  final int requiredHits;
  String? _leaderKey;
  int _hits = 0;

  bool register(_BeaconCandidate? leader, {required int successRssi}) {
    if (leader == null || leader.rssi < successRssi) {
      _leaderKey = null;
      _hits = 0;
      return false;
    }
    final key = leader._trackingKey;
    if (key.isEmpty) {
      _leaderKey = null;
      _hits = 0;
      return false;
    }
    if (_leaderKey == key) {
      _hits++;
    } else {
      _leaderKey = key;
      _hits = 1;
    }
    return _hits >= requiredHits;
  }
}

Future<void> _stopScanIfActive() => beaconBleStopScanIfActive();

List<String>? _companyBeaconUuids() {
  final uuid = AccountSessionStore.instance.companyBeaconUuid;
  return uuid != null ? [uuid] : null;
}

Future<BluetoothReadResult> readBluetoothBeaconIdentifier({
  Duration timeout = kBluetoothDiscoveryScanTimeout,
  int minRssi = kBluetoothDiscoveryMinRssi,
  int successRssi = kBluetoothDiscoverySuccessRssi,
  int stableHits = kBluetoothDiscoveryStableHits,
  List<String>? uuids,
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

  final filterUuids = uuids ?? _companyBeaconUuids() ?? const <String>[];
  final filterRemoteIds = remoteIds ?? const <String>[];
  final bestById = <String, _BeaconCandidate>{};
  final rssiFilters = <String, _RssiKalmanFilter>{};
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
      final existingIndex = discoveredDevices.indexWhere(
        (d) => d.device.remoteId == r.device.remoteId,
      );
      final isNew = existingIndex < 0;
      if (isNew) {
        discoveredDevices.add(r);
      } else if (r.rssi > discoveredDevices[existingIndex].rssi) {
        discoveredDevices[existingIndex] = r;
      }
      _trackNearestCandidate(
        bestById,
        r,
        minRssi: minRssi,
        rssiFilters: rssiFilters,
        uuids: filterUuids,
        remoteIds: filterRemoteIds,
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

    await beaconBleCooldownBeforeScan();

    // Hardware filters (OR): MSD iBeacon, MAC.
    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidScanMode: AndroidScanMode.lowLatency,
      continuousUpdates: true,
      androidUsesFineLocation: true,
      androidCheckLocationServices: true,
      withMsd: _iBeaconScanMsdFilters(
        filterUuids.isEmpty ? null : filterUuids,
      ),
      withRemoteIds: _hardwareScanMacRemoteIds(
        filterRemoteIds.isEmpty ? null : filterRemoteIds,
      ),
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

/// Continuous iBeacon scan — delivers stable hits via [BluetoothBeaconOnHit].
class BluetoothBeaconScanSession {
  StreamSubscription<List<ScanResult>>? _resultsSub;
  final _bestById = <String, _BeaconCandidate>{};
  final _rssiFilters = <String, _RssiKalmanFilter>{};
  var _stopped = true;
  BluetoothBeaconOnHit? _onHit;
  _StrongSignalTracker? _strongTracker;
  List<String> _filterUuids = const [];
  List<String> _filterRemoteIds = const [];
  int _minRssi = kBluetoothDiscoveryMinRssi;
  int _successRssi = kBluetoothDiscoverySuccessRssi;
  Future<void>? _runner;

  Future<BluetoothReadFailure?> start({
    List<String>? uuids,
    List<String>? remoteIds,
    required BluetoothBeaconOnHit onHit,
    int minRssi = kBluetoothDiscoveryMinRssi,
    int successRssi = kBluetoothDiscoverySuccessRssi,
    int stableHits = kBluetoothDiscoveryStableHits,
  }) async {
    if (!isBluetoothScanSupported) {
      return BluetoothReadFailure.unavailable;
    }

    try {
      if (!await FlutterBluePlus.isSupported) {
        return BluetoothReadFailure.unavailable;
      }
    } catch (_) {
      return BluetoothReadFailure.unavailable;
    }

    if (!await _ensureBlePermissions()) {
      return BluetoothReadFailure.permissionDenied;
    }

    if (!await _ensureAdapterOn()) {
      return BluetoothReadFailure.disabled;
    }

    _stopped = false;
    _onHit = onHit;
    _filterUuids = uuids ?? _companyBeaconUuids() ?? const [];
    _filterRemoteIds = remoteIds ?? const [];
    _minRssi = minRssi;
    _successRssi = successRssi;
    final hits = stableHits < 1 ? 1 : stableHits;
    _strongTracker = _StrongSignalTracker(requiredHits: hits);
    _bestById.clear();
    _rssiFilters.clear();

    void absorbAndDispatch(List<ScanResult> results) {
      if (_stopped || _onHit == null || _strongTracker == null) return;
      for (final r in results) {
        _trackNearestCandidate(
          _bestById,
          r,
          minRssi: _minRssi,
          rssiFilters: _rssiFilters,
          uuids: _filterUuids,
          remoteIds: _filterRemoteIds,
        );
      }
      final nearest = _pickNearestBeacon(_bestById);
      final tracker = _strongTracker!;
      if (!tracker.register(nearest, successRssi: _successRssi)) return;
      _strongTracker = _StrongSignalTracker(requiredHits: hits);
      if (nearest == null) return;
      final read = _successFromCandidate(nearest);
      if (_onHit!(read)) {
        unawaited(stop());
      }
    }

    _resultsSub = FlutterBluePlus.onScanResults.listen(absorbAndDispatch);
    absorbAndDispatch(FlutterBluePlus.lastScanResults);
    _runner = _runContinuousScan();
    return null;
  }

  Future<void> _runContinuousScan() async {
    const scanSlice = Duration(hours: 1);
    while (!_stopped) {
      try {
        await beaconBleCooldownBeforeScan();
        if (_stopped) break;

        await FlutterBluePlus.startScan(
          timeout: scanSlice,
          androidScanMode: AndroidScanMode.lowLatency,
          continuousUpdates: true,
          androidUsesFineLocation: true,
          androidCheckLocationServices: true,
          withMsd: _iBeaconScanMsdFilters(
            _filterUuids.isEmpty ? null : _filterUuids,
          ),
          withRemoteIds: _hardwareScanMacRemoteIds(
            _filterRemoteIds.isEmpty ? null : _filterRemoteIds,
          ),
        );

        while (!_stopped && FlutterBluePlus.isScanningNow) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      } catch (_) {
        if (!_stopped) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
    }
  }

  Future<void> stop() async {
    _stopped = true;
    _onHit = null;
    _strongTracker = null;
    await _resultsSub?.cancel();
    _resultsSub = null;
    await _stopScanIfActive();
    try {
      await _runner?.timeout(const Duration(seconds: 3));
    } catch (_) {}
    _runner = null;
    _bestById.clear();
    _rssiFilters.clear();
  }
}
