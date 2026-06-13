import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../models/beacon_configure_protocol.dart';
import 'beacon_ble_picker_connect.dart';
import 'beacon_ble_configure_session.dart';
import 'beacon_ble_session.dart';
import 'ibeacon_configurer_types.dart';
import 'joyway_beacon_fbp_configurer.dart';
import 'joyway_beacon_raw_protocol.dart';

/// Joyway JW1404: FBP scan picker MAC → Nordic UART raw protocol
/// (login → read 72 B → password + iBeacon → save), same packets as Joyway Beacon APK.
Future<IBeaconConfigureResult> configureJoywayNearestIBeacon(
  IBeaconSettings settings, {
  Duration scanTimeout = const Duration(seconds: 35),
  Duration configTimeout = const Duration(seconds: 120),
  int minRssi = kJoywayConfigureMinRssiDefault,
  String? targetRemoteId,
  int? targetRssi,
  String? loginPassword,
  String? newBeaconPassword,
  JoywayBeaconExtendedSettings? joywayExtended,
}) async {
  if (!settings.isValid) {
    return const IBeaconConfigureResult.failure(
      IBeaconConfigureFailure.invalidSettings,
    );
  }

  if (!Platform.isAndroid) {
    return const IBeaconConfigureResult.failure(
      IBeaconConfigureFailure.unavailable,
    );
  }

  if (!isBeaconBleConfigureSupported) {
    return const IBeaconConfigureResult.failure(
      IBeaconConfigureFailure.unavailable,
    );
  }

  try {
    if (!await beaconBleEnsurePermissions()) {
      return const IBeaconConfigureResult.failure(
        IBeaconConfigureFailure.permissionDenied,
      );
    }
  } catch (_) {
    return const IBeaconConfigureResult.failure(
      IBeaconConfigureFailure.unavailable,
    );
  }

  final joywayLoginPassword = normalizeJoywayBeaconPassword(loginPassword);
  final joywayNewPassword = newBeaconPassword == null
      ? null
      : normalizeJoywayBeaconPassword(newBeaconPassword);

  final preScanMac = targetRemoteId?.trim().toUpperCase();
  if (preScanMac == null || preScanMac.isEmpty) {
    return const IBeaconConfigureResult.failure(
      IBeaconConfigureFailure.deviceNotFound,
    );
  }

  if (kDebugMode) {
    debugPrint('Joyway: FBP UART configure for $preScanMac');
  }

  final sessionReady = BeaconBleConfigureSession.matches(
    protocol: BeaconConfigureProtocol.joyway,
    remoteId: preScanMac,
    loginKey: joywayLoginPassword,
  );
  if (!sessionReady) {
    await beaconBleStopScanIfActive();
    if (!beaconBleIsFreshPickerTarget(preScanMac)) {
      await beaconBleCooldownBeforeScan(
        minGap: const Duration(milliseconds: 400),
      );
      await beaconBleReleaseFbpGattForMac(preScanMac);
    }
    await beaconBleWaitUntilNotScanning(timeout: const Duration(seconds: 2));
  }

  return configureJoywayViaFbpUart(
    settings,
    targetRemoteId: preScanMac,
    loginPassword: joywayLoginPassword,
    newBeaconPassword: joywayNewPassword,
    joywayExtended: joywayExtended,
    minRssi: minRssi,
  );
}
