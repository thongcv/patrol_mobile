import 'bluetooth_beacon_reader_types.dart';

bool get isBluetoothScanSupported => false;

Future<BluetoothReadResult> readBluetoothBeaconIdentifier({
  Duration timeout = kBluetoothDiscoveryScanTimeout,
  int minRssi = kBluetoothDiscoveryMinRssi,
  int successRssi = kBluetoothDiscoverySuccessRssi,
  int stableHits = kBluetoothDiscoveryStableHits,
  List<String>? remoteIds,
}) async {
  return const BluetoothReadResult.failure(BluetoothReadFailure.unavailable);
}
