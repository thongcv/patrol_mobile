import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

import 'nfc_tag_reader_types.dart';

bool get isNfcScanSupported =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

String _bytesToHex(Uint8List bytes) {
  return bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
}

String? _identifierHexFromTag(NfcTag tag) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      final androidTag = NfcTagAndroid.from(tag);
      if (androidTag != null && androidTag.id.isNotEmpty) {
        return _bytesToHex(androidTag.id);
      }
      return null;
    case TargetPlatform.iOS:
      final mifare = MiFareIos.from(tag);
      if (mifare != null && mifare.identifier.isNotEmpty) {
        return _bytesToHex(mifare.identifier);
      }
      final iso7816 = Iso7816Ios.from(tag);
      if (iso7816 != null && iso7816.identifier.isNotEmpty) {
        return _bytesToHex(iso7816.identifier);
      }
      final iso15693 = Iso15693Ios.from(tag);
      if (iso15693 != null && iso15693.identifier.isNotEmpty) {
        return _bytesToHex(iso15693.identifier);
      }
      final felica = FeliCaIos.from(tag);
      if (felica != null && felica.currentIDm.isNotEmpty) {
        return _bytesToHex(felica.currentIDm);
      }
      return null;
    default:
      return null;
  }
}

Future<NfcReadResult> readNfcTagIdentifier({
  Duration timeout = const Duration(seconds: 45),
  String? iosAlertMessage,
}) async {
  if (!isNfcScanSupported) {
    return const NfcReadResult.failure(NfcReadFailure.unavailable);
  }

  NfcAvailability availability;
  try {
    availability = await NfcManager.instance.checkAvailability();
  } catch (_) {
    return const NfcReadResult.failure(NfcReadFailure.unavailable);
  }

  switch (availability) {
    case NfcAvailability.unsupported:
      return const NfcReadResult.failure(NfcReadFailure.unavailable);
    case NfcAvailability.disabled:
      return const NfcReadResult.failure(NfcReadFailure.disabled);
    case NfcAvailability.enabled:
      break;
  }

  final completer = Completer<NfcReadResult>();
  Timer? timeoutTimer;
  var sessionActive = false;

  void finish(NfcReadResult result) {
    if (!completer.isCompleted) completer.complete(result);
    timeoutTimer?.cancel();
  }

  try {
    await NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      alertMessageIos: iosAlertMessage,
      onDiscovered: (tag) async {
        final id = _identifierHexFromTag(tag);
        if (id == null || id.isEmpty) {
          finish(const NfcReadResult.failure(NfcReadFailure.noIdentifier));
        } else {
          finish(NfcReadResult.success(id));
        }
        if (sessionActive) {
          try {
            await NfcManager.instance.stopSession();
          } catch (_) {}
          sessionActive = false;
        }
      },
    );
    sessionActive = true;

    timeoutTimer = Timer(timeout, () {
      finish(const NfcReadResult.failure(NfcReadFailure.timeout));
    });

    final result = await completer.future;
    return result;
  } catch (_) {
    return const NfcReadResult.failure(NfcReadFailure.failed);
  } finally {
    timeoutTimer?.cancel();
    if (sessionActive) {
      try {
        await NfcManager.instance.stopSession();
      } catch (_) {}
    }
  }
}
