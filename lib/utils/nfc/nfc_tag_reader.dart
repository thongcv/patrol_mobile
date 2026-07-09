import 'nfc_tag_reader_stub.dart'
    if (dart.library.io) 'nfc_tag_reader_mobile.dart' as impl;

import 'nfc_tag_reader_types.dart';

export 'nfc_tag_reader_types.dart';

bool get isNfcScanSupported => impl.isNfcScanSupported;

Future<NfcReadResult> readNfcTagIdentifier({
  Duration timeout = const Duration(seconds: 45),
  String? iosAlertMessage,
}) =>
    impl.readNfcTagIdentifier(
      timeout: timeout,
      iosAlertMessage: iosAlertMessage,
    );
