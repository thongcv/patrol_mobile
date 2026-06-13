import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'beacon_ble_configure_devices.dart';
import 'beacon_ble_configure_session.dart';
import 'beacon_ble_session.dart';

const _pickerFreshTtl = Duration(seconds: 45);

BleConfigureDeviceEntry? _lastPickerEntry;
DateTime? _lastPickerSelectedAt;
final _warmConnectByMac = <String, Future<void>>{};

Duration beaconBleConnectTimeoutForRssi(int rssi) {
  if (rssi >= -65) return const Duration(seconds: 6);
  if (rssi >= -78) return const Duration(seconds: 8);
  return const Duration(seconds: 12);
}

void beaconBleMarkPickerSelection(BleConfigureDeviceEntry entry) {
  _lastPickerEntry = entry;
  _lastPickerSelectedAt = DateTime.now();
}

void beaconBleClearPickerSelection() {
  _lastPickerEntry = null;
  _lastPickerSelectedAt = null;
}

bool beaconBleIsFreshPickerTarget(String remoteId) {
  final entry = _lastPickerEntry;
  final at = _lastPickerSelectedAt;
  if (entry == null || at == null) return false;
  if (DateTime.now().difference(at) > _pickerFreshTtl) return false;
  return entry.remoteId.trim().toUpperCase() ==
      remoteId.trim().toUpperCase();
}

int? beaconBleFreshPickerRssi(String remoteId) {
  if (!beaconBleIsFreshPickerTarget(remoteId)) return null;
  return _lastPickerEntry!.rssi;
}

/// Stop scan and release GATT only when needed before connecting to a known MAC.
Future<void> beaconBlePrepareConnectToKnownTarget(String remoteId) async {
  await beaconBleStopScanIfActive();

  if (beaconBleIsFreshPickerTarget(remoteId)) {
    if (!BeaconBleConfigureSession.hasActive) {
      await beaconBleReleaseFbpGattForMac(
        remoteId,
        settleDelay: Duration.zero,
      );
    }
    return;
  }

  await beaconBleCooldownBeforeScan(minGap: const Duration(milliseconds: 400));
  await beaconBleReleaseFbpGattForMac(remoteId);
}

/// Begin connect in the background right after picker selection.
///
/// Connect only — JW1404 drops idle GATT links ([LINK_SUPERVISION_TIMEOUT]) if
/// MTU/login is deferred while the user fills protocol/password dialogs.
void beaconBleStartWarmConnect(BleConfigureDeviceEntry entry) {
  beaconBleMarkPickerSelection(entry);
  final mac = entry.remoteId.trim().toUpperCase();
  _warmConnectByMac[mac] ??= _runWarmConnect(mac, entry.rssi);
}

Future<void> _runWarmConnect(String mac, int rssi) async {
  try {
    await beaconBlePrepareConnectToKnownTarget(mac);
    final device = beaconBleDeviceFromRemoteId(mac);
    if (device.isConnected) return;
    await beaconBleConnect(
      device,
      timeout: beaconBleConnectTimeoutForRssi(rssi),
    );
  } catch (_) {
    // Login/configure uses [beaconBleConnectFreshToKnownTarget].
  }
}

/// Drop any stale GATT link and connect immediately before UART work.
Future<BluetoothDevice> beaconBleConnectFreshToKnownTarget(
  String remoteId, {
  int? targetRssi,
}) async {
  final mac = remoteId.trim().toUpperCase();
  _warmConnectByMac.remove(mac);
  final device = beaconBleDeviceFromRemoteId(mac);
  try {
    if (device.isConnected) {
      await device.disconnect(queue: false);
    }
  } catch (_) {}
  await beaconBlePrepareConnectToKnownTarget(mac);
  final rssi = targetRssi ?? beaconBleFreshPickerRssi(mac) ?? -85;
  await beaconBleConnect(
    device,
    timeout: beaconBleConnectTimeoutForRssi(rssi),
  );
  return device;
}

Future<BluetoothDevice> beaconBleConnectToKnownTarget(
  String remoteId, {
  int? targetRssi,
}) async {
  final mac = remoteId.trim().toUpperCase();
  final device = beaconBleDeviceFromRemoteId(mac);
  if (device.isConnected) return device;

  final warm = _warmConnectByMac[mac];
  if (warm != null) {
    try {
      await warm.timeout(const Duration(seconds: 14));
    } catch (_) {}
    if (device.isConnected) return device;
  }

  await beaconBlePrepareConnectToKnownTarget(mac);
  if (!device.isConnected) {
    final rssi = targetRssi ?? beaconBleFreshPickerRssi(mac) ?? -85;
    await beaconBleConnect(
      device,
      timeout: beaconBleConnectTimeoutForRssi(rssi),
    );
  }
  return device;
}

Future<void> beaconBleCancelWarmConnect([String? remoteId]) async {
  if (remoteId == null) {
    _warmConnectByMac.clear();
    beaconBleClearPickerSelection();
    return;
  }
  final mac = remoteId.trim().toUpperCase();
  _warmConnectByMac.remove(mac);
  try {
    final device = beaconBleDeviceFromRemoteId(mac);
    if (device.isConnected && !BeaconBleConfigureSession.hasActive) {
      await device.disconnect(queue: false);
    }
  } catch (_) {}
}
