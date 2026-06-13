import '../../models/beacon_configure_protocol.dart';
import 'ibeacon_configurer_stub.dart'
    if (dart.library.io) 'ibeacon_configurer_mobile.dart' as impl;
import 'ibeacon_configurer_types.dart';
import 'joyway_beacon_raw_protocol.dart';

export '../../models/beacon_configure_protocol.dart';
export 'ibeacon_configurer_types.dart';
export 'joyway_beacon_raw_protocol.dart' show JoywayBeaconExtendedSettings;

bool get isIBeaconConfigureSupported => impl.isIBeaconConfigureSupported;

/// BLE connect + protocol login. `null` = password accepted.
Future<IBeaconConfigureFailure?> validateBeaconDeviceLogin({
  required BeaconConfigureProtocol protocol,
  required String targetRemoteId,
  String? devicePassword,
  int? targetRssi,
}) =>
    impl.validateBeaconDeviceLogin(
      protocol: protocol,
      targetRemoteId: targetRemoteId,
      devicePassword: devicePassword,
      targetRssi: targetRssi,
    );

/// Scan for a nearby beacon in config mode, program UUID/major/minor, verify.
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
}) =>
    impl.configureNearestIBeacon(
      settings,
      protocol: protocol,
      devicePassword: devicePassword,
      newBeaconPassword: newBeaconPassword,
      joywayExtended: joywayExtended,
      scanTimeout: scanTimeout,
      minRssi: minRssi,
      targetRemoteId: targetRemoteId,
      targetRssi: targetRssi,
    );
