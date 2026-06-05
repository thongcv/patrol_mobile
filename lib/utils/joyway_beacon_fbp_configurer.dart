import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/beacon_configure_protocol.dart';
import 'beacon_ble_picker_connect.dart';
import 'beacon_ble_session.dart';
import 'beacon_ble_configure_session.dart';
import 'bluetooth_beacon_reader.dart';
import 'ibeacon_configurer_types.dart';
import 'joyway_beacon_raw_protocol.dart';

const _joywayUartService = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const _joywayUartRx = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
const _joywayUartTx = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

/// Beacon reboots after config; scan by MAC and require advertised UUID/major/minor.
Future<BluetoothReadResult?> joywayVerifyProgrammedIBeacon(
  IBeaconSettings settings, {
  required String remoteId,
}) async {
  const attempts = 3;
  for (var i = 0; i < attempts; i++) {
    await Future<void>.delayed(Duration(milliseconds: i == 0 ? 1000 : 700));
    await beaconBleCooldownBeforeScan(minGap: const Duration(milliseconds: 250));
    // Scan by MAC only so we still see the device while it advertises the old UUID.
    final verify = await readBluetoothBeaconIdentifier(
      remoteIds: [remoteId],
      timeout: const Duration(seconds: 6),
      minRssi: -100,
      successRssi: -95,
      stableHits: 1,
    );
    if (!verify.ok) continue;
    final scannedUuid = verify.uuid?.trim() ?? '';
    if (scannedUuid.isEmpty ||
        !bluetoothIdentifiersMatch(settings.uuid, scannedUuid)) {
      continue;
    }
    final beacon = verify.beacon;
    if (beacon?.major != settings.major || beacon?.minor != settings.minor) {
      continue;
    }
    return verify;
  }
  return null;
}

/// Connect + UART login only; returns `null` when password accepted.
Future<IBeaconConfigureFailure?> joywayValidateLoginViaFbpUart({
  required String targetRemoteId,
  String loginPassword = '',
  int? targetRssi,
}) async {
  final loginPwd = normalizeJoywayBeaconPassword(loginPassword);
  final remoteId = targetRemoteId.trim().toUpperCase();

  await BeaconBleConfigureSession.clear();

  BluetoothDevice? device;
  BluetoothCharacteristic? rxChar;
  BluetoothCharacteristic? txChar;
  var mtu = 23;

  try {
    device = await beaconBleConnectFreshToKnownTarget(
      remoteId,
      targetRssi: targetRssi,
    );
    if (!device.isConnected) {
      return IBeaconConfigureFailure.connectionFailed;
    }

    await Future<void>.delayed(const Duration(milliseconds: 80));
    mtu = await beaconBleNegotiateMtu(device);
    if (!device.isConnected) {
      device = await beaconBleConnectFreshToKnownTarget(
        remoteId,
        targetRssi: targetRssi,
      );
      if (!device.isConnected) {
        return IBeaconConfigureFailure.connectionFailed;
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
      mtu = await beaconBleNegotiateMtu(device);
    }

    final services = await device.discoverServices();
    rxChar = beaconBleFindCharacteristic(
      services,
      _joywayUartService,
      _joywayUartRx,
    );
    txChar = beaconBleFindCharacteristic(
      services,
      _joywayUartService,
      _joywayUartTx,
    );
    if (rxChar == null || txChar == null) {
      return IBeaconConfigureFailure.unsupportedDevice;
    }

    await txChar.setNotifyValue(true);

    final loginResult = await joywayLoginWithFallback(
      rxChar: rxChar,
      txChar: txChar,
      password: loginPwd,
      mtu: mtu,
      allowEmptyPasswordFallback: false,
    );
    if (loginResult != JoywayLoginResult.success) {
      return joywayLoginFailureFor(
        result: loginResult,
        loginPassword: loginPwd,
      );
    }

    BeaconBleConfigureSession.adoptJoyway(
      remoteId: remoteId,
      loginKey: loginPwd,
      device: device,
      rxChar: rxChar,
      txChar: txChar,
      mtu: mtu,
    );
    return null;
  } on TimeoutException {
    return IBeaconConfigureFailure.timeout;
  } catch (_) {
    return IBeaconConfigureFailure.connectionFailed;
  } finally {
    if (!BeaconBleConfigureSession.matches(
      protocol: BeaconConfigureProtocol.joyway,
      remoteId: remoteId,
      loginKey: loginPwd,
    )) {
      try {
        if (device?.isConnected ?? false) await device!.disconnect();
      } catch (_) {}
    }
  }
}

/// Joyway JW1404 configure over FBP GATT + Nordic UART raw protocol.
Future<IBeaconConfigureResult> configureJoywayViaFbpUart(
  IBeaconSettings settings, {
  required String targetRemoteId,
  String loginPassword = '',
  String? newBeaconPassword,
  JoywayBeaconExtendedSettings? joywayExtended,
  int minRssi = kJoywayConfigureMinRssiDefault,
}) async {
  final loginPwd = normalizeJoywayBeaconPassword(loginPassword);
  final remoteId = targetRemoteId.trim().toUpperCase();
  BluetoothDevice device = beaconBleDeviceFromRemoteId(remoteId);
  BluetoothCharacteristic? rxChar;
  BluetoothCharacteristic? txChar;
  var mtu = 23;
  var ownsConnection = true;

  try {
    final session = BeaconBleConfigureSession.activeIfMatches(
      protocol: BeaconConfigureProtocol.joyway,
      remoteId: remoteId,
      loginKey: loginPwd,
    );
    if (session != null &&
        session.joywayRx != null &&
        session.joywayTx != null) {
      device = session.device;
      rxChar = session.joywayRx;
      txChar = session.joywayTx;
      mtu = session.joywayMtu;
      ownsConnection = false;
    } else {
      await BeaconBleConfigureSession.clear();
      device = await beaconBleConnectFreshToKnownTarget(
        remoteId,
        targetRssi: minRssi,
      );
      if (!device.isConnected) {
        return const IBeaconConfigureResult.failure(
          IBeaconConfigureFailure.connectionFailed,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
      mtu = await beaconBleNegotiateMtu(device);

      final services = await device.discoverServices();
      rxChar = beaconBleFindCharacteristic(
        services,
        _joywayUartService,
        _joywayUartRx,
      );
      txChar = beaconBleFindCharacteristic(
        services,
        _joywayUartService,
        _joywayUartTx,
      );
      if (rxChar == null || txChar == null) {
        return const IBeaconConfigureResult.failure(
          IBeaconConfigureFailure.unsupportedDevice,
        );
      }

      await txChar.setNotifyValue(true);

      final loginResult = await joywayLoginWithFallback(
        rxChar: rxChar,
        txChar: txChar,
        password: loginPwd,
        mtu: mtu,
      );
      if (loginResult != JoywayLoginResult.success) {
        return IBeaconConfigureResult.failure(
          joywayLoginFailureFor(
            result: loginResult,
            loginPassword: loginPwd,
          ),
        );
      }
    }

    final configured = await joywayApplyPasswordAndIBeaconViaUart(
      rxChar: rxChar!,
      txChar: txChar!,
      settings: settings,
      newBeaconPassword: newBeaconPassword,
      extended: joywayExtended,
      mtu: mtu,
    );
    if (!configured) {
      return const IBeaconConfigureResult.failure(
        IBeaconConfigureFailure.commandFailed,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));

    try {
      await device.disconnect();
    } catch (_) {}
    ownsConnection = false;

    final verify = await joywayVerifyProgrammedIBeacon(
      settings,
      remoteId: remoteId,
    );
    if (verify == null) {
      return const IBeaconConfigureResult.failure(
        IBeaconConfigureFailure.verifyFailed,
      );
    }

    return IBeaconConfigureResult.success(
      remoteId: remoteId,
      beacon: verify.beacon,
    );
  } on TimeoutException {
    return const IBeaconConfigureResult.failure(
      IBeaconConfigureFailure.timeout,
    );
  } catch (_) {
    return const IBeaconConfigureResult.failure(
      IBeaconConfigureFailure.connectionFailed,
    );
  } finally {
    await BeaconBleConfigureSession.clear();
    if (ownsConnection) {
      try {
        if (device.isConnected) await device.disconnect();
      } catch (_) {}
    }
  }
}
