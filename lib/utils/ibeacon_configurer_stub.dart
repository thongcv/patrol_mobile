import '../models/beacon_configure_protocol.dart';
import 'ibeacon_configurer_types.dart';
import 'joyway_beacon_raw_protocol.dart';

bool get isIBeaconConfigureSupported => false;

Future<IBeaconConfigureFailure?> validateBeaconDeviceLogin({
  required BeaconConfigureProtocol protocol,
  required String targetRemoteId,
  String? devicePassword,
  int? targetRssi,
}) async {
  return IBeaconConfigureFailure.unavailable;
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
  return const IBeaconConfigureResult.failure(
    IBeaconConfigureFailure.unavailable,
  );
}
