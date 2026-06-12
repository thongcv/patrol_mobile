part of '../patrol_point_screen.dart';

BeaconConfigureProtocol? _checkpointBeaconProtocol(CheckPoint point) {
  final protocol = BeaconConfigureProtocol.tryFromStorage(point.beaconProtocol);
  if (protocol == null || !protocol.isConfigureImplemented) return null;
  return protocol;
}

String _nfcScanFailureMessage(AppLocalizations l10n, NfcReadFailure failure) {
  return switch (failure) {
    NfcReadFailure.disabled => l10n.patrolPointNfcDisabled,
    NfcReadFailure.timeout => l10n.patrolPointNfcScanTimeout,
    NfcReadFailure.unavailable => l10n.patrolPointNfcUnavailable,
    NfcReadFailure.noIdentifier || NfcReadFailure.failed =>
      l10n.patrolPointNfcScanFailed,
  };
}

String _iBeaconConfigureFailureMessage(
  AppLocalizations l10n,
  IBeaconConfigureFailure failure,
) {
  return switch (failure) {
    IBeaconConfigureFailure.disabled => l10n.patrolPointBluetoothDisabled,
    IBeaconConfigureFailure.permissionDenied =>
      l10n.patrolPointBluetoothPermissionDenied,
    IBeaconConfigureFailure.unavailable =>
      l10n.patrolPointBluetoothUnavailable,
    IBeaconConfigureFailure.deviceNotFound ||
    IBeaconConfigureFailure.verifyFailed =>
      l10n.patrolPointIBeaconConfigModeRequired,
    IBeaconConfigureFailure.connectionFailed ||
    IBeaconConfigureFailure.unsupportedDevice ||
    IBeaconConfigureFailure.commandFailed ||
    IBeaconConfigureFailure.timeout =>
      l10n.patrolPointIBeaconConfigureFailed,
    IBeaconConfigureFailure.invalidSettings =>
      l10n.patrolPointCompanyBeaconUuidMissing,
    IBeaconConfigureFailure.unsupportedProtocol =>
      l10n.patrolPointBeaconProtocolUnsupported,
    IBeaconConfigureFailure.wrongPassword =>
      l10n.patrolPointIBeaconWrongPassword,
  };
}

