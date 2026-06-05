import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/beacon_configure_protocol.dart';
import 'beacon_ble_picker_connect.dart';
import 'beacon_ble_configure_session.dart';
import 'beacon_ble_session.dart';
import 'beacon_name_latin.dart';
import 'bluetooth_beacon_reader.dart';
import 'ibeacon_configurer_types.dart';

const _configServiceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
const _configCharUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';

IBeaconConfigureFailure _hm10ConfigureCommandFailure(String? devicePassword) {
  final pin = normalizeHm10DevicePassword(devicePassword);
  if (pin == null) return IBeaconConfigureFailure.wrongPassword;
  return IBeaconConfigureFailure.commandFailed;
}

/// Connect + AT unlock only; returns `null` when PIN accepted (or not required).
Future<IBeaconConfigureFailure?> hm10ValidateLoginViaGatt({
  required String targetRemoteId,
  String? devicePassword,
  int? targetRssi,
}) async {
  final remoteId = targetRemoteId.trim().toUpperCase();

  await BeaconBleConfigureSession.clear();

  BluetoothDevice? device;
  StreamSubscription<List<int>>? notifySub;

  try {
    device = await beaconBleConnectToKnownTarget(
      remoteId,
      targetRssi: targetRssi,
    );
    await device.requestMtu(512);

    BluetoothCharacteristic? configChar;
    final responseBuffer = StringBuffer();

    final services = await device.discoverServices();
    configChar = beaconBleFindCharacteristic(
      services,
      _configServiceUuid,
      _configCharUuid,
    );
    if (configChar == null) {
      return IBeaconConfigureFailure.unsupportedDevice;
    }

    if (configChar.properties.notify || configChar.properties.indicate) {
      await configChar.setNotifyValue(true);
      notifySub = configChar.onValueReceived.listen((data) {
        responseBuffer.write(utf8.decode(data, allowMalformed: true));
      });
    }

    Future<bool> sendAt(String command) async {
      responseBuffer.clear();
      await configChar!.write(
        utf8.encode('$command\r\n'),
        withoutResponse: false,
      );
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final text = responseBuffer.toString();
        if (text.contains('OK')) return true;
        if (text.contains('ERROR') || text.contains('FAIL')) return false;
      }
      return false;
    }

    if (!await sendAt('AT')) {
      return IBeaconConfigureFailure.commandFailed;
    }

    final pin = normalizeHm10DevicePassword(devicePassword);
    if (pin != null) {
      final unlocked =
          await sendAt('AT+PASS$pin') || await sendAt('AT+PIN$pin');
      if (!unlocked) {
        return IBeaconConfigureFailure.wrongPassword;
      }
    }

    BeaconBleConfigureSession.adoptHm10(
      remoteId: targetRemoteId,
      loginKey: pin ?? '',
      device: device,
      configChar: configChar,
    );
    return null;
  } catch (_) {
    return IBeaconConfigureFailure.connectionFailed;
  } finally {
    await notifySub?.cancel();
    final pin = normalizeHm10DevicePassword(devicePassword) ?? '';
    if (!BeaconBleConfigureSession.matches(
      protocol: BeaconConfigureProtocol.hm10Ffe0,
      remoteId: targetRemoteId,
      loginKey: pin,
    )) {
      try {
        await device?.disconnect();
      } catch (_) {}
    }
  }
}

/// Programs HM-10 / FFE0-style beacons over GATT AT commands.
Future<IBeaconConfigureResult> configureHm10NearestIBeacon(
  IBeaconSettings settings, {
  String? devicePassword,
  Duration scanTimeout = const Duration(seconds: 15),
  int minRssi = -90,
  String? targetRemoteId,
}) async {
  late final BluetoothDevice device;
  if (targetRemoteId != null && targetRemoteId.trim().isNotEmpty) {
    device = beaconBleDeviceFromRemoteId(targetRemoteId);
  } else {
    final scanHit = await beaconBleScanStrongest(
      timeout: scanTimeout,
      minRssi: minRssi,
      withServiceUuid: _configServiceUuid,
    );
    if (scanHit == null) {
      return const IBeaconConfigureResult.failure(
        IBeaconConfigureFailure.deviceNotFound,
      );
    }
    device = scanHit.device;
  }
  final remoteId = device.remoteId.str.trim().toUpperCase();
  final pinKey = normalizeHm10DevicePassword(devicePassword) ?? '';
  var activeDevice = device;
  BluetoothCharacteristic? configChar;
  StreamSubscription<List<int>>? notifySub;
  final responseBuffer = StringBuffer();
  var ownsConnection = true;

  Future<bool> sendAt(String command) async {
    responseBuffer.clear();
    await configChar!.write(
      utf8.encode('$command\r\n'),
      withoutResponse: false,
    );
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final text = responseBuffer.toString();
      if (text.contains('OK')) return true;
      if (text.contains('ERROR') || text.contains('FAIL')) return false;
    }
    return false;
  }

  try {
    final session = BeaconBleConfigureSession.activeIfMatches(
      protocol: BeaconConfigureProtocol.hm10Ffe0,
      remoteId: remoteId,
      loginKey: pinKey,
    );
    if (session != null && session.hm10ConfigChar != null) {
      activeDevice = session.device;
      configChar = session.hm10ConfigChar;
      ownsConnection = false;
    } else {
      await BeaconBleConfigureSession.clear();
      final connected = await beaconBleConnectToKnownTarget(
        remoteId,
        targetRssi: beaconBleFreshPickerRssi(remoteId),
      );
      activeDevice = connected;
      await activeDevice.requestMtu(512);

      final services = await activeDevice.discoverServices();
      configChar = beaconBleFindCharacteristic(
        services,
        _configServiceUuid,
        _configCharUuid,
      );
      if (configChar == null) {
        return const IBeaconConfigureResult.failure(
          IBeaconConfigureFailure.unsupportedDevice,
        );
      }

      if (configChar.properties.notify || configChar.properties.indicate) {
        await configChar.setNotifyValue(true);
        notifySub = configChar.onValueReceived.listen((data) {
          responseBuffer.write(utf8.decode(data, allowMalformed: true));
        });
      }

      if (!await sendAt('AT')) {
        return const IBeaconConfigureResult.failure(
          IBeaconConfigureFailure.commandFailed,
        );
      }

      final pin = normalizeHm10DevicePassword(devicePassword);
      if (pin != null) {
        final unlocked =
            await sendAt('AT+PASS$pin') || await sendAt('AT+PIN$pin');
        if (!unlocked) {
          return const IBeaconConfigureResult.failure(
            IBeaconConfigureFailure.wrongPassword,
          );
        }
      }
    }

    if (notifySub == null &&
        (configChar!.properties.notify || configChar.properties.indicate)) {
      await configChar.setNotifyValue(true);
      notifySub = configChar.onValueReceived.listen((data) {
        responseBuffer.write(utf8.decode(data, allowMalformed: true));
      });
    }

    final advName = settings.advertisingName?.trim();
    if (advName != null && advName.isNotEmpty) {
      final clipped = beaconLatinBroadcastName(
        advName,
        maxLen: kHm10BroadcastNameMaxLen,
      );
      if (clipped.isNotEmpty) {
        await sendAt('AT+NAME$clipped');
      }
    }

    final uuidParts = iBeaconUuidCommandParts(settings.uuid);
    for (var i = 0; i < uuidParts.length; i++) {
      if (!await sendAt('AT+IBE$i${uuidParts[i]}')) {
        return IBeaconConfigureResult.failure(
          _hm10ConfigureCommandFailure(devicePassword),
        );
      }
    }

    if (!await sendAt('AT+MARJ${iBeaconMajorCommandValue(settings.major)}')) {
      return IBeaconConfigureResult.failure(
        _hm10ConfigureCommandFailure(devicePassword),
      );
    }

    if (!await sendAt('AT+MINO${iBeaconMinorCommandValue(settings.minor)}')) {
      return IBeaconConfigureResult.failure(
        _hm10ConfigureCommandFailure(devicePassword),
      );
    }

    final tx = settings.txPowerAt1m;
    if (tx != -59) {
      await sendAt('AT+MEAS${tx > 127 ? tx - 256 : tx}');
    }

    await sendAt('AT+IBEA1');
    await sendAt('AT+RESET');

    await notifySub?.cancel();
    notifySub = null;
    await activeDevice.disconnect();
    ownsConnection = false;

    await Future<void>.delayed(const Duration(milliseconds: 1000));

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
    await notifySub?.cancel();
    await BeaconBleConfigureSession.clear();
    if (ownsConnection) {
      try {
        await activeDevice.disconnect();
      } catch (_) {}
    }
  }
}
