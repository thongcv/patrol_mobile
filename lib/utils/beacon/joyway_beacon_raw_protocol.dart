import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'beacon_ble_session.dart';
import 'beacon_name_latin.dart';
import 'ibeacon_configurer_types.dart';

/// Joyway device name field (offset 12–23): Latin ASCII, max 12 chars.
String joywayClipDeviceNameToField(String name) =>
    beaconLatinBroadcastName(name, maxLen: 12);

List<int> joywayDeviceNameFieldBytes(String name) {
  final field = List<int>.filled(12, 0);
  final latin = joywayClipDeviceNameToField(name);
  for (var i = 0; i < latin.length && i < 12; i++) {
    field[i] = latin.codeUnitAt(i) & 0xFF;
  }
  return field;
}

String joywayDeviceNameFromFieldBytes(List<int> field) =>
    beaconLatinFromRawNameBytes(field);

String joywayDeviceNameFromConfig72(Uint8List config) {
  if (config.length < 24) return '';
  return joywayDeviceNameFromFieldBytes(config.sublist(12, 24));
}

/// Joyway JW1404 UART config (decompiled [Activity_iBeacon] / [v0] / [w]).
List<int> joywayAsciiPasswordFieldBytes(String password) {
  final field = List<int>.filled(12, 0);
  final trimmed = password.trim();
  for (var i = 0; i < trimmed.length && i < 12; i++) {
    field[i] = trimmed.codeUnitAt(i) & 0xFF;
  }
  return field;
}

List<int> joywayLoginPayloadBytes(String password) {
  final data = List<int>.filled(15, 0);
  data[0] = 0x00;
  data[1] = 0x01;
  data[2] = 12;
  final pwd = joywayAsciiPasswordFieldBytes(password);
  for (var i = 0; i < 12; i++) {
    data[3 + i] = pwd[i];
  }
  return data;
}

bool joywayLoginAccepted(List<int> data) =>
    data.length >= 4 &&
    data[0] == 0x00 &&
    data[1] == 0x02 &&
    data[2] == 0x01 &&
    data[3] == 0x00;

bool joywayLoginRejected(List<int> data) =>
    data.length >= 4 &&
    data[0] == 0x00 &&
    data[1] == 0x02 &&
    data[2] == 0x01 &&
    data[3] != 0x00;

bool joywaySaveAccepted(List<int> data) =>
    data.length >= 4 &&
    data[0] == 0x00 &&
    data[1] == 0x06 &&
    data[2] == 0x01 &&
    data[3] == 0x00;

void _putU16Be(Uint8List data, int offset, int value) {
  data[offset] = (value >> 8) & 0xFF;
  data[offset + 1] = value & 0xFF;
}

int _readU16Be(Uint8List data, int offset) {
  return ((data[offset] & 0xFF) << 8) | (data[offset + 1] & 0xFF);
}

/// Raw value written to config[48]/[52] when advertising never stops.
const int kJoywayAdvNeverStopRaw = 65535;

/// UI ms value for “never stop” (65535 × 100).
const int kJoywayAdvNeverStopMs = 6553500;

/// Allowed TX power values at config offset 45 (Joyway app).
const List<int> kJoywayTxPowerDbmValues = [4, 0, -4, -8, -12, -16, -20];

/// Extended Joyway JW1404 fields from the 72-byte config block.
class JoywayBeaconExtendedSettings {
  const JoywayBeaconExtendedSettings({
    this.rssiAt1m = -59,
    this.txPowerDbm = 0,
    this.adv1IntervalMs = 1000,
    this.adv1TimeLenMs = 60000,
    this.adv1NeverStop = false,
    this.adv2IntervalMs = 2000,
    this.adv2TimeLenMs = kJoywayAdvNeverStopMs,
    this.adv2NeverStop = true,
    this.buttonDelayMs = 2000,
    this.advertiseButtonEvent = false,
  });

  final int rssiAt1m;
  final int txPowerDbm;
  final int adv1IntervalMs;
  final int adv1TimeLenMs;
  final bool adv1NeverStop;
  final int adv2IntervalMs;
  final int adv2TimeLenMs;
  final bool adv2NeverStop;
  final int buttonDelayMs;
  final bool advertiseButtonEvent;

  JoywayBeaconExtendedSettings copyWith({
    int? rssiAt1m,
    int? txPowerDbm,
    int? adv1IntervalMs,
    int? adv1TimeLenMs,
    bool? adv1NeverStop,
    int? adv2IntervalMs,
    int? adv2TimeLenMs,
    bool? adv2NeverStop,
    int? buttonDelayMs,
    bool? advertiseButtonEvent,
  }) {
    return JoywayBeaconExtendedSettings(
      rssiAt1m: rssiAt1m ?? this.rssiAt1m,
      txPowerDbm: txPowerDbm ?? this.txPowerDbm,
      adv1IntervalMs: adv1IntervalMs ?? this.adv1IntervalMs,
      adv1TimeLenMs: adv1TimeLenMs ?? this.adv1TimeLenMs,
      adv1NeverStop: adv1NeverStop ?? this.adv1NeverStop,
      adv2IntervalMs: adv2IntervalMs ?? this.adv2IntervalMs,
      adv2TimeLenMs: adv2TimeLenMs ?? this.adv2TimeLenMs,
      adv2NeverStop: adv2NeverStop ?? this.adv2NeverStop,
      buttonDelayMs: buttonDelayMs ?? this.buttonDelayMs,
      advertiseButtonEvent: advertiseButtonEvent ?? this.advertiseButtonEvent,
    );
  }
}

int _joywayAdvTimeLenMsFromRaw(int raw) {
  if (raw == kJoywayAdvNeverStopRaw) return kJoywayAdvNeverStopMs;
  return raw * 100;
}

int _joywayAdvTimeLenRawFromMs(int ms, {required bool neverStop}) {
  if (neverStop) return kJoywayAdvNeverStopRaw;
  return (ms / 100).round().clamp(0, 0xFFFF);
}

JoywayBeaconExtendedSettings joywayParseExtendedFromConfig72(Uint8List data) {
  if (data.length < 56) return const JoywayBeaconExtendedSettings();
  final adv1Raw = _readU16Be(data, 48);
  final adv2Raw = _readU16Be(data, 52);
  final adv1Ms = _joywayAdvTimeLenMsFromRaw(adv1Raw);
  final adv2Ms = _joywayAdvTimeLenMsFromRaw(adv2Raw);
  final txRaw = data[45];
  final txSigned = txRaw >= 128 ? txRaw - 256 : txRaw;
  return JoywayBeaconExtendedSettings(
    rssiAt1m: data[44] >= 128 ? data[44] - 256 : data[44],
    txPowerDbm: kJoywayTxPowerDbmValues.contains(txSigned)
        ? txSigned
        : kJoywayTxPowerDbmValues.first,
    adv1IntervalMs: _readU16Be(data, 46),
    adv1TimeLenMs: adv1Ms,
    adv1NeverStop: adv1Raw == kJoywayAdvNeverStopRaw,
    adv2IntervalMs: _readU16Be(data, 50),
    adv2TimeLenMs: adv2Ms,
    adv2NeverStop: adv2Raw == kJoywayAdvNeverStopRaw,
    buttonDelayMs: (data[54] & 0xFF) * 100,
    advertiseButtonEvent: (data[55] & 1) != 0,
  );
}

JoywayBeaconExtendedSettings joywayDefaultExtendedSettings({
  int rssiAt1m = -59,
}) {
  return JoywayBeaconExtendedSettings(rssiAt1m: rssiAt1m);
}

void _patchJoywayExtendedFields(
  Uint8List config,
  JoywayBeaconExtendedSettings extended,
) {
  final rssi = extended.rssiAt1m.clamp(-100, 0);
  config[44] = rssi;
  config[45] = extended.txPowerDbm;
  _putU16Be(config, 46, extended.adv1IntervalMs.clamp(100, 10000));
  _putU16Be(
    config,
    48,
    _joywayAdvTimeLenRawFromMs(
      extended.adv1TimeLenMs,
      neverStop: extended.adv1NeverStop,
    ),
  );
  _putU16Be(config, 50, extended.adv2IntervalMs.clamp(100, 10000));
  _putU16Be(
    config,
    52,
    _joywayAdvTimeLenRawFromMs(
      extended.adv2TimeLenMs,
      neverStop: extended.adv2NeverStop,
    ),
  );
  config[54] = (extended.buttonDelayMs / 100).round().clamp(0, 255);
  config[55] = extended.advertiseButtonEvent ? 1 : 0;
}

void joywayPatchConfig72({
  required Uint8List config,
  required IBeaconSettings settings,
  JoywayBeaconExtendedSettings? extended,
  String? newBeaconPassword,
}) {
  final newPassword = newBeaconPassword?.trim() ?? '';
  if (newPassword.isNotEmpty) {
    _patchJoywayPasswordField(config, newPassword);
  }
  final advName = settings.advertisingName?.trim();
  if (advName != null && advName.isNotEmpty) {
    _patchJoywayDeviceNameField(config, joywayClipDeviceNameToField(advName));
  }
  final ext = extended ??
      JoywayBeaconExtendedSettings(rssiAt1m: settings.txPowerAt1m);
  _patchJoywayExtendedFields(config, ext);
  _patchJoywayIBeaconFields(
    config,
    settings.uuid,
    settings.major,
    settings.minor,
    ext.rssiAt1m,
  );
}

Uint8List buildDefaultJoywayConfig72({
  required String uuid,
  required int major,
  required int minor,
  int rssiAt1m = -59,
}) {
  final config = Uint8List(72);
  joywayPatchConfig72(
    config: config,
    settings: IBeaconSettings(
      uuid: uuid,
      major: major,
      minor: minor,
      txPowerAt1m: rssiAt1m,
    ),
    extended: joywayDefaultExtendedSettings(rssiAt1m: rssiAt1m),
  );
  return config;
}

void _patchJoywayPasswordField(Uint8List config, String password) {
  final field = joywayAsciiPasswordFieldBytes(password);
  for (var i = 0; i < 12; i++) {
    config[i] = field[i];
  }
}

void _patchJoywayDeviceNameField(Uint8List config, String name) {
  final field = joywayDeviceNameFieldBytes(name);
  for (var i = 0; i < 12; i++) {
    config[12 + i] = field[i];
  }
}

void _patchJoywayIBeaconFields(
  Uint8List config,
  String uuid,
  int major,
  int minor,
  int rssiAt1m,
) {
  final hex = uuid.replaceAll(RegExp(r'[-:]', caseSensitive: false), '').toLowerCase();
  if (hex.length != 32) return;
  for (var i = 0; i < 16; i++) {
    config[24 + i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  _putU16Be(config, 40, major);
  _putU16Be(config, 42, minor);
  final rssi = rssiAt1m.clamp(-100, 0);
  config[44] = rssi;
  config[45] = 0;
}

List<List<int>> joywaySaveConfigPackets(Uint8List config) {
  final packets = <List<int>>[];
  var chunkIndex = 0;
  var offset = 0;
  while (offset < config.length) {
    final chunkLen = (config.length - offset) > 16 ? 16 : (config.length - offset);
    if (chunkLen == 16) {
      final packet = List<int>.filled(20, 0);
      packet[0] = 0x00;
      packet[1] = 0x05;
      packet[2] = 17;
      packet[3] = chunkIndex;
      for (var i = 0; i < 16; i++) {
        packet[4 + i] = config[offset + i];
      }
      packets.add(packet);
    } else {
      final packet = List<int>.filled(chunkLen + 4, 0);
      packet[0] = 0x00;
      packet[1] = 0x05;
      packet[2] = chunkLen + 1;
      packet[3] = chunkIndex;
      for (var i = 0; i < chunkLen; i++) {
        packet[4 + i] = config[offset + i];
      }
      packets.add(packet);
    }
    offset += chunkLen;
    chunkIndex++;
  }
  return packets;
}

Future<Uint8List?> joywayReadConfig72ViaUart({
  required BluetoothCharacteristic rxChar,
  required BluetoothCharacteristic txChar,
  required int mtu,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final buffer = <int>[];
  var totalChunks = 0;
  final completer = Completer<Uint8List?>();
  late final StreamSubscription<List<int>> sub;
  sub = txChar.onValueReceived.listen((data) {
    if (data.isEmpty || data[0] != 0x00 || data[1] != 0x04) return;
    if (data.length < 5) return;
    final subType = data[3];
    if (subType == 2 && data.length >= 5) {
      totalChunks = data[4];
    } else if (subType == 0) {
      final chunkIndex = data[4];
      buffer.addAll(data.sublist(5));
      final lastIndex = totalChunks > 0 ? totalChunks - 1 : 4;
      if (chunkIndex == lastIndex && buffer.length >= 72 && !completer.isCompleted) {
        completer.complete(Uint8List.fromList(buffer.sublist(0, 72)));
      }
    }
  });

  try {
    await beaconBleWriteCharacteristic(rxChar, [0x00, 0x07], mtu: mtu);
    return await completer.future.timeout(
      timeout,
      onTimeout: () => null,
    );
  } finally {
    await sub.cancel();
  }
}

Future<bool> joywayWriteConfig72ViaUart({
  required BluetoothCharacteristic rxChar,
  required BluetoothCharacteristic txChar,
  required Uint8List config,
  required int mtu,
  Duration timeout = const Duration(seconds: 15),
}) async {
  final saveOk = Completer<bool>();
  late final StreamSubscription<List<int>> sub;
  sub = txChar.onValueReceived.listen((data) {
    if (joywaySaveAccepted(data) && !saveOk.isCompleted) {
      saveOk.complete(true);
    }
  });

  try {
    for (final packet in joywaySaveConfigPackets(config)) {
      await beaconBleWriteCharacteristic(rxChar, packet, mtu: mtu);
      await Future<void>.delayed(const Duration(milliseconds: 28));
    }
    return await saveOk.future.timeout(timeout, onTimeout: () => false);
  } finally {
    await sub.cancel();
  }
}

Future<JoywayLoginResult> joywayLoginWithFallback({
  required BluetoothCharacteristic rxChar,
  required BluetoothCharacteristic txChar,
  required String password,
  required int mtu,
  bool allowEmptyPasswordFallback = true,
}) async {
  Future<JoywayLoginResult> attempt(String pwd) async {
    final ok = Completer<bool>();
    var rejected = false;
    late final StreamSubscription<List<int>> sub;
    sub = txChar.onValueReceived.listen((data) {
      if (joywayLoginAccepted(data) && !ok.isCompleted) ok.complete(true);
      if (joywayLoginRejected(data) && !ok.isCompleted) {
        rejected = true;
        ok.complete(false);
      }
    });
    try {
      await beaconBleWriteCharacteristic(
        rxChar,
        joywayLoginPayloadBytes(pwd),
        mtu: mtu,
      );
      final accepted = await ok.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
      if (accepted) return JoywayLoginResult.success;
      if (rejected) return JoywayLoginResult.rejected;
      return JoywayLoginResult.failed;
    } catch (_) {
      return JoywayLoginResult.failed;
    } finally {
      await sub.cancel();
    }
  }

  final trimmed = normalizeJoywayBeaconPassword(password);
  final primary = await attempt(trimmed);
  if (primary == JoywayLoginResult.success) return primary;
  if (trimmed.isEmpty || !allowEmptyPasswordFallback) return primary;
  return attempt('');
}

/// Assumes UART notify is on and login already succeeded.
Future<bool> joywayApplyPasswordAndIBeaconViaUart({
  required BluetoothCharacteristic rxChar,
  required BluetoothCharacteristic txChar,
  required IBeaconSettings settings,
  String? newBeaconPassword,
  JoywayBeaconExtendedSettings? extended,
  required int mtu,
}) async {
  var config = await joywayReadConfig72ViaUart(
    rxChar: rxChar,
    txChar: txChar,
    mtu: mtu,
  );
  config ??= buildDefaultJoywayConfig72(
    uuid: settings.uuid,
    major: settings.major,
    minor: settings.minor,
    rssiAt1m: extended?.rssiAt1m ?? settings.txPowerAt1m,
  );
  joywayPatchConfig72(
    config: config,
    settings: settings,
    extended: extended,
    newBeaconPassword: newBeaconPassword,
  );
  return joywayWriteConfig72ViaUart(
    rxChar: rxChar,
    txChar: txChar,
    config: config,
    mtu: mtu,
  );
}
