import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'beacon_ble_session.dart';
import 'bluetooth_beacon_reader.dart';
import 'ibeacon_configurer_types.dart';

/// Common OEM nRF52 “advertisement content” service (firmware-dependent).
const _nordicServiceUuid = '00007650-0000-1000-8000-00805f9b34fb';
const _nordicCharUuid = '00007651-0000-1000-8000-00805f9b34fb';

const _serviceUuidHints = ['7650', 'fe20', '1523'];
const _charUuidHints = ['7651', 'fe21', '1524'];

/// 21 bytes: proximity UUID (16) + major (2 BE) + minor (2 BE) + TX @1m (1).
List<int> nordicIBeaconAdvertContent21(IBeaconSettings settings) {
  final hex = settings.uuid.trim().toUpperCase().replaceAll('-', '');
  if (hex.length != 32) {
    throw ArgumentError.value(settings.uuid, 'uuid', 'expected 128-bit UUID');
  }
  final uuidBytes = <int>[];
  for (var i = 0; i < 32; i += 2) {
    uuidBytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  final major = settings.major;
  final minor = settings.minor;
  final tx = settings.txPowerAt1m;
  return [
    ...uuidBytes,
    (major >> 8) & 0xFF,
    major & 0xFF,
    (minor >> 8) & 0xFF,
    minor & 0xFF,
    tx < 0 ? tx + 256 : tx,
  ];
}

BluetoothCharacteristic? _findNordicAdvertContentChar(
  List<BluetoothService> services,
) {
  final exact = beaconBleFindCharacteristic(
    services,
    _nordicServiceUuid,
    _nordicCharUuid,
  );
  if (exact != null &&
      (exact.properties.write || exact.properties.writeWithoutResponse)) {
    return exact;
  }

  for (final service in services) {
    final su = service.uuid.str128.toLowerCase();
    final serviceMatch = _serviceUuidHints.any(su.contains);
    for (final c in service.characteristics) {
      final cu = c.uuid.str128.toLowerCase();
      final charMatch = _charUuidHints.any(cu.contains);
      if (!serviceMatch && !charMatch) continue;
      if (!c.properties.write && !c.properties.writeWithoutResponse) {
        continue;
      }
      return c;
    }
  }
  return null;
}

/// Programs Nordic / OEM nRF52 beacons by writing 21-byte iBeacon advert payload.
Future<IBeaconConfigureResult> configureNordicNearestIBeacon(
  IBeaconSettings settings, {
  Duration scanTimeout = const Duration(seconds: 15),
  int minRssi = -90,
  String? targetRemoteId,
}) async {
  final BluetoothDevice device;
  if (targetRemoteId != null && targetRemoteId.trim().isNotEmpty) {
    device = beaconBleDeviceFromRemoteId(targetRemoteId);
  } else {
    var scanHit = await beaconBleScanStrongest(
      timeout: scanTimeout,
      minRssi: minRssi,
      withServiceUuid: _nordicServiceUuid,
    );
    scanHit ??= await beaconBleScanStrongest(
      timeout: scanTimeout,
      minRssi: minRssi,
    );
    if (scanHit == null) {
      return const IBeaconConfigureResult.failure(
        IBeaconConfigureFailure.deviceNotFound,
      );
    }
    device = scanHit.device;
  }
  final remoteId = device.remoteId.str.trim().toUpperCase();

  try {
    await beaconBleConnect(device);
    await device.requestMtu(512);

    final services = await device.discoverServices();
    final configChar = _findNordicAdvertContentChar(services);
    if (configChar == null) {
      return const IBeaconConfigureResult.failure(
        IBeaconConfigureFailure.unsupportedDevice,
      );
    }

    final payload = nordicIBeaconAdvertContent21(settings);
    final withoutResponse =
        configChar.properties.writeWithoutResponse &&
        !configChar.properties.write;
    await configChar.write(payload, withoutResponse: withoutResponse);

    await device.disconnect();
    await Future<void>.delayed(const Duration(seconds: 2));

    final verify = await readBluetoothBeaconIdentifier(
      uuids: [settings.uuid.trim()],
      stableHits: 1,
      successRssi: -90,
    );
    if (!verify.ok) {
      return const IBeaconConfigureResult.failure(
        IBeaconConfigureFailure.verifyFailed,
      );
    }

    final beacon = verify.beacon;
    if (beacon?.major != settings.major || beacon?.minor != settings.minor) {
      return const IBeaconConfigureResult.failure(
        IBeaconConfigureFailure.verifyFailed,
      );
    }

    return IBeaconConfigureResult.success(
      remoteId: remoteId,
      beacon: beacon,
    );
  } catch (_) {
    return const IBeaconConfigureResult.failure(
      IBeaconConfigureFailure.connectionFailed,
    );
  } finally {
    try {
      await device.disconnect();
    } catch (_) {}
  }
}
