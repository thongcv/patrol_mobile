import 'bluetooth_beacon_reader_types.dart';

bool get isBluetoothScanSupported => false;

Future<BluetoothReadResult> readBluetoothBeaconIdentifier({
  Duration timeout = kBluetoothDiscoveryScanTimeout,
  BluetoothScanMode mode = BluetoothScanMode.generic,
  int minRssi = kBluetoothDiscoveryMinRssi,
  int successRssi = kBluetoothDiscoverySuccessRssi,
  int stableHits = kBluetoothDiscoveryStableHits,
  String? namePrefix,
  List<String>? remoteIds,
}) async {
  return const BluetoothReadResult.failure(BluetoothReadFailure.unavailable);
}
