import 'bluetooth_beacon_reader_stub.dart'
    if (dart.library.io) 'bluetooth_beacon_reader_mobile.dart' as impl;

import 'bluetooth_beacon_reader_types.dart';

export 'bluetooth_beacon_reader_types.dart';

bool get isBluetoothScanSupported => impl.isBluetoothScanSupported;

Future<BluetoothReadResult> readBluetoothBeaconIdentifier({
  Duration timeout = kBluetoothDiscoveryScanTimeout,
  int minRssi = kBluetoothDiscoveryMinRssi,
  int successRssi = kBluetoothDiscoverySuccessRssi,
  int stableHits = kBluetoothDiscoveryStableHits,
  List<String>? remoteIds,
}) =>
    impl.readBluetoothBeaconIdentifier(
      timeout: timeout,
      minRssi: minRssi,
      successRssi: successRssi,
      stableHits: stableHits,
      remoteIds: remoteIds,
    );
