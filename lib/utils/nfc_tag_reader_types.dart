enum NfcReadFailure { unavailable, disabled, timeout, noIdentifier, failed }

class NfcReadResult {
  const NfcReadResult._({this.identifier, this.failure});

  const NfcReadResult.success(String id) : this._(identifier: id);

  const NfcReadResult.failure(NfcReadFailure reason) : this._(failure: reason);

  final String? identifier;
  final NfcReadFailure? failure;

  bool get ok => identifier != null && identifier!.isNotEmpty;
}
