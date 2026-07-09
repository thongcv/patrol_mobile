import 'nfc_tag_reader_types.dart';

bool get isNfcScanSupported => false;

Future<NfcReadResult> readNfcTagIdentifier({
  Duration timeout = const Duration(seconds: 45),
  String? iosAlertMessage,
}) async {
  return const NfcReadResult.failure(NfcReadFailure.unavailable);
}
