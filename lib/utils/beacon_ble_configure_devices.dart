import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/beacon_configure_protocol.dart';
import 'beacon_ble_session.dart';
import 'beacon_name_latin.dart';

/// FBP iBeacon scan for the configure picker; Joyway JW1404 is programmed via FBP UART.
const int kConfigurePickerMinRssi = -95;

/// Normalized BLE MAC for picker keys / manual entry.
String beaconBleNormalizePickerId(String raw) {
  final t = raw.trim().toUpperCase();
  if (t.contains(':')) return t;
  final hex = t.replaceAll(RegExp(r'[^0-9A-F]'), '');
  if (hex.length == 12) {
    return List<String>.generate(
      6,
      (i) => hex.substring(i * 2, i * 2 + 2),
    ).join(':');
  }
  return t;
}

bool beaconBleLooksLikeMac(String raw) {
  final n = beaconBleNormalizePickerId(raw);
  return RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$').hasMatch(n);
}

/// Manual pick when config mode has no iBeacon advert (MAC from BLE Scanner).
BleConfigureDeviceEntry beaconBleManualPickerEntry(String mac, {int rssi = -50}) {
  final id = beaconBleNormalizePickerId(mac);
  return BleConfigureDeviceEntry(
    remoteId: id,
    rssi: rssi,
    advName: id,
  );
}

/// True when [raw] looks like a readable BLE local name (not mojibake).
bool beaconBleIsPlausibleLocalName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.contains('\uFFFD')) return false;
  for (final r in trimmed.runes) {
    if (r < 0x20) return false;
  }
  return true;
}

/// Normalize BLE broadcast name for display: Latin, no mojibake.
/// When [maxLen] is null, the full readable name is kept (picker list display).
String? beaconBleSanitizeAdvName(String raw, {int? maxLen}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final latin = maxLen == null
      ? beaconTextToLatin(trimmed)
      : beaconLatinBroadcastName(trimmed, maxLen: maxLen);
  if (latin.isNotEmpty && beaconBleIsPlausibleLocalName(latin)) {
    return latin;
  }

  final fromBytes = beaconLatinFromRawNameBytes(
    trimmed.codeUnits,
    maxLen: maxLen ?? 256,
  );
  if (fromBytes.isNotEmpty && beaconBleIsPlausibleLocalName(fromBytes)) {
    return fromBytes;
  }

  return null;
}

class BleConfigureDeviceEntry implements Comparable<BleConfigureDeviceEntry> {
  const BleConfigureDeviceEntry({
    required this.remoteId,
    required this.rssi,
    this.uuid,
    this.advName,
    this.major,
    this.minor,
    this.txPowerAt1m,
    this.connectable = false,
    this.hasIBeaconAdvert = false,
  });

  final String remoteId;
  final int rssi;
  final String? uuid;
  final String? advName;
  final int? major;
  final int? minor;
  final int? txPowerAt1m;
  final bool connectable;
  final bool hasIBeaconAdvert;

  String get displayName => pickerListTitle;

  /// Primary picker label — MAC is stable; broadcast name may be garbled.
  String get pickerListTitle => remoteId;

  /// BLE broadcast local name when readable; null if missing or garbled.
  String? get pickerBroadcastName =>
      beaconBleSanitizeAdvName(advName ?? '', maxLen: null);

  /// iBeacon adverts do not expose GATT protocol — user picks on the picker.
  static const List<BeaconConfigureProtocol> pickerManualProtocols = [
    BeaconConfigureProtocol.joyway,
    BeaconConfigureProtocol.hm10Ffe0,
    BeaconConfigureProtocol.nordicNrf52,
  ];

  @override
  int compareTo(BleConfigureDeviceEntry other) => other.rssi.compareTo(rssi);
}

bool _shouldReplaceEntry(
  BleConfigureDeviceEntry? prev,
  BleConfigureDeviceEntry next,
) {
  if (prev == null) return true;
  return next.rssi > prev.rssi;
}

BleConfigureDeviceEntry _entryFromScan(ScanResult r) {
  final ibeacon = beaconBleParseIBeaconAdvert(r)!;
  final adv = r.advertisementData;
  final id = beaconBleNormalizePickerId(r.device.remoteId.str);
  final name = beaconBleSanitizeAdvName(adv.advName) ?? '';

  return BleConfigureDeviceEntry(
    remoteId: id,
    rssi: r.rssi,
    uuid: ibeacon.uuid,
    advName: name.isEmpty ? null : name,
    major: ibeacon.major,
    minor: ibeacon.minor,
    txPowerAt1m: ibeacon.txPowerAt1m,
    connectable: adv.connectable,
    hasIBeaconAdvert: true,
  );
}

/// Before FBP configure picker scan.
Future<void> beaconBlePrepareConfigurePickerScan() async {
  await beaconBleCooldownBeforeScan(minGap: const Duration(milliseconds: 400));
}

Future<BleConfigureDeviceScanHandle> beaconBleStartConfigureDeviceScan({
  required void Function(List<BleConfigureDeviceEntry>) onUpdate,
  void Function()? onScanFinished,
  void Function(String? errorMessage)? onScanError,
  BeaconConfigureProtocol protocol = BeaconConfigureProtocol.joyway,
  Duration scanDuration = const Duration(seconds: 50),
  int minRssi = kConfigurePickerMinRssi,
}) {
  return _startFbpConfigureDeviceScan(
    onUpdate: onUpdate,
    onScanFinished: onScanFinished,
    onScanError: onScanError,
    scanDuration: scanDuration,
    minRssi: minRssi,
  );
}

Future<BleConfigureDeviceScanHandle> _startFbpConfigureDeviceScan({
  required void Function(List<BleConfigureDeviceEntry>) onUpdate,
  void Function()? onScanFinished,
  void Function(String? errorMessage)? onScanError,
  required Duration scanDuration,
  required int minRssi,
}) async {
  final byId = <String, BleConfigureDeviceEntry>{};
  StreamSubscription<List<ScanResult>>? resultsSub;
  var stopped = false;
  String? scanError;

  void publish() {
    onUpdate(byId.values.toList()..sort());
  }

  void absorb(Iterable<ScanResult> results) {
    var changed = false;
    for (final r in results) {
      if (!beaconBleShouldShowInConfigurePicker(r, minRssi: minRssi)) continue;
      final id = beaconBleNormalizePickerId(r.device.remoteId.str);
      if (id.isEmpty) continue;
      final entry = _entryFromScan(r);
      final prev = byId[id];
      if (_shouldReplaceEntry(prev, entry)) {
        byId[id] = entry;
        changed = true;
      }
    }
    if (changed) publish();
  }

  Future<void> runScan() async {
    try {
      if (!await beaconBleEnsureAdapterOn()) {
        onUpdate(const []);
        return;
      }
      if (stopped) return;

      await beaconBleCooldownBeforeScan(minGap: const Duration(milliseconds: 400));
      if (stopped) return;

      await FlutterBluePlus.startScan(
        timeout: scanDuration,
        androidScanMode: AndroidScanMode.lowLatency,
        continuousUpdates: true,
        androidUsesFineLocation: true,
        androidCheckLocationServices: true,
        withMsd: beaconBleIBeaconMsdFilters(),
      );

      while (!stopped && FlutterBluePlus.isScanningNow) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    } on PlatformException catch (e) {
      scanError = e.message ?? e.code;
    } catch (e) {
      scanError = e.toString();
    } finally {
      await beaconBleStopScanIfActive();
      publish();
      if (!stopped) {
        onScanError?.call(scanError);
        onScanFinished?.call();
      }
    }
  }

  await beaconBlePrepareConfigurePickerScan();

  if (!await beaconBleEnsureAdapterOn()) {
    onUpdate(const []);
    onScanFinished?.call();
    return BleConfigureDeviceScanHandle._();
  }

  resultsSub = FlutterBluePlus.onScanResults.listen(absorb);
  absorb(FlutterBluePlus.lastScanResults);

  final runner = runScan();

  return BleConfigureDeviceScanHandle._(
    fbpSub: resultsSub,
    onStop: () => stopped = true,
    runner: runner,
  );
}

class BleConfigureDeviceScanHandle {
  BleConfigureDeviceScanHandle._({
    this.fbpSub,
    void Function()? onStop,
    this.runner,
  }) : _onStop = onStop;

  final StreamSubscription<List<ScanResult>>? fbpSub;
  final void Function()? _onStop;
  final Future<void>? runner;

  Future<void> stop() async {
    _onStop?.call();
    await fbpSub?.cancel();
    await beaconBleStopScanIfActive();
    await beaconBleWaitUntilNotScanning();
    try {
      await runner?.timeout(const Duration(seconds: 3));
    } catch (_) {}
  }
}
