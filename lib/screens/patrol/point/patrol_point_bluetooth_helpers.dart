part of '../patrol_point_screen.dart';

String _nfcScanFailureMessage(AppLocalizations l10n, NfcReadFailure failure) {
  return switch (failure) {
    NfcReadFailure.disabled => l10n.patrolPointNfcDisabled,
    NfcReadFailure.timeout => l10n.patrolPointNfcScanTimeout,
    NfcReadFailure.unavailable => l10n.patrolPointNfcUnavailable,
    NfcReadFailure.noIdentifier || NfcReadFailure.failed =>
      l10n.patrolPointNfcScanFailed,
  };
}

String _bluetoothScanSummary(
  AppLocalizations l10n,
  BluetoothBeaconDetails beacon,
) {
  final distance = BluetoothBeaconDetails.formatDistanceMeters(
    beacon.distanceMeters,
  );
  return l10n.patrolPointBluetoothScanSummary(beacon.rssi, distance);
}

String? _bluetoothScanMetaLine(
  AppLocalizations l10n,
  BluetoothBeaconDetails beacon,
) {
  final address = beacon.deviceAddress?.trim();
  final hasAddress = address != null && address.isNotEmpty;
  final hasMajor = beacon.major != null;
  final hasMinor = beacon.minor != null;
  if (!hasAddress && !hasMajor && !hasMinor) return null;
  return l10n.patrolPointBluetoothScanMeta(
    hasAddress ? address : '—',
    hasMajor ? '${beacon.major}' : '—',
    hasMinor ? '${beacon.minor}' : '—',
  );
}

String _bluetoothScanFailureMessage(
  AppLocalizations l10n,
  BluetoothReadFailure failure,
) {
  return switch (failure) {
    BluetoothReadFailure.disabled => l10n.patrolPointBluetoothDisabled,
    BluetoothReadFailure.permissionDenied =>
      l10n.patrolPointBluetoothPermissionDenied,
    BluetoothReadFailure.timeout => l10n.patrolPointBluetoothScanTimeout,
    BluetoothReadFailure.unavailable => l10n.patrolPointBluetoothUnavailable,
    BluetoothReadFailure.failed => l10n.patrolPointBluetoothScanFailed,
  };
}

