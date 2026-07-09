import '../../models/beacon_configure_protocol.dart';
import 'beacon_ble_session.dart';
import 'hm10_beacon_configurer.dart';
import 'ibeacon_configurer_types.dart';
import 'joyway_beacon_configurer.dart';
import 'joyway_beacon_fbp_configurer.dart';
import 'joyway_beacon_raw_protocol.dart';
import 'nordic_beacon_configurer.dart';

bool get isIBeaconConfigureSupported => isBeaconBleConfigureSupported;

Future<IBeaconConfigureFailure?> validateBeaconDeviceLogin({
  required BeaconConfigureProtocol protocol,
  required String targetRemoteId,
  String? devicePassword,
  int? targetRssi,
}) async {
  if (!isBeaconBleConfigureSupported) {
    return IBeaconConfigureFailure.unavailable;
  }

  try {
    if (!await beaconBleEnsurePermissions()) {
      return IBeaconConfigureFailure.permissionDenied;
    }
  } catch (_) {
    return IBeaconConfigureFailure.unavailable;
  }

  if (!protocol.isConfigureImplemented) {
    return IBeaconConfigureFailure.unsupportedProtocol;
  }

  if (!await beaconBleEnsureAdapterOn()) {
    return IBeaconConfigureFailure.disabled;
  }

  return switch (protocol) {
    BeaconConfigureProtocol.joyway => joywayValidateLoginViaFbpUart(
        targetRemoteId: targetRemoteId,
        loginPassword: normalizeJoywayBeaconPassword(devicePassword),
        targetRssi: targetRssi,
      ),
    BeaconConfigureProtocol.hm10Ffe0 => hm10ValidateLoginViaGatt(
        targetRemoteId: targetRemoteId,
        devicePassword: devicePassword,
        targetRssi: targetRssi,
      ),
    BeaconConfigureProtocol.nordicNrf52 => null,
    _ => IBeaconConfigureFailure.unsupportedProtocol,
  };
}

Future<IBeaconConfigureResult> configureNearestIBeacon(
  IBeaconSettings settings, {
  BeaconConfigureProtocol? protocol,
  String? devicePassword,
  String? newBeaconPassword,
  JoywayBeaconExtendedSettings? joywayExtended,
  Duration scanTimeout = const Duration(seconds: 15),
  int minRssi = -90,
  String? targetRemoteId,
  int? targetRssi,
}) async {
  if (!settings.isValid) {
    return const IBeaconConfigureResult.failure(
      IBeaconConfigureFailure.invalidSettings,
    );
  }

  if (!isIBeaconConfigureSupported) {
    return const IBeaconConfigureResult.failure(
      IBeaconConfigureFailure.unavailable,
    );
  }

  final resolved = protocol ?? BeaconConfigureProtocol.defaultProtocol;
  if (!resolved.isConfigureImplemented) {
    return const IBeaconConfigureResult.failure(
      IBeaconConfigureFailure.unsupportedProtocol,
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

  if (resolved == BeaconConfigureProtocol.joyway) {
    await beaconBleStopScanIfActive();
    final joywayScan = scanTimeout < const Duration(seconds: 30)
        ? const Duration(seconds: 30)
        : scanTimeout;
    return configureJoywayNearestIBeacon(
      settings,
      scanTimeout: joywayScan,
      minRssi: minRssi < kJoywayConfigureMinRssiDefault
          ? kJoywayConfigureMinRssiDefault
          : minRssi,
      targetRemoteId: targetRemoteId,
      targetRssi: targetRssi,
      loginPassword: normalizeJoywayBeaconPassword(devicePassword),
      newBeaconPassword: newBeaconPassword == null
          ? null
          : normalizeJoywayBeaconPassword(newBeaconPassword),
      joywayExtended: joywayExtended,
    );
  }

  if (!await beaconBleEnsureAdapterOn()) {
    return const IBeaconConfigureResult.failure(
      IBeaconConfigureFailure.disabled,
    );
  }

  return switch (resolved) {
    BeaconConfigureProtocol.hm10Ffe0 => configureHm10NearestIBeacon(
        settings,
        devicePassword: devicePassword,
        scanTimeout: scanTimeout,
        minRssi: minRssi,
        targetRemoteId: targetRemoteId,
      ),
    BeaconConfigureProtocol.nordicNrf52 => configureNordicNearestIBeacon(
        settings,
        scanTimeout: scanTimeout,
        minRssi: minRssi,
        targetRemoteId: targetRemoteId,
      ),
    BeaconConfigureProtocol.joyway => const IBeaconConfigureResult.failure(
        IBeaconConfigureFailure.unavailable,
      ),
    _ => const IBeaconConfigureResult.failure(
        IBeaconConfigureFailure.unsupportedProtocol,
      ),
  };
}
