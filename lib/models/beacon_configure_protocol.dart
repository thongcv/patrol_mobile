/// GATT protocol used when programming beacons on [PatrolPointScreen].
enum BeaconConfigureProtocol {
  /// HM-10 / TQ clone — service FFE0, char FFE1, AT commands.
  hm10Ffe0('hm10_ffe0'),

  /// Nordic nRF52 OEM — write 21-byte iBeacon payload to advertisement char.
  nordicNrf52('nordic_nrf52'),

  /// Joyway JW1404 / Waterdrop — FBP UART (Nordic 6e400001, Android).
  joyway('joyway'),

  /// Feasycom FSC-BP… — proprietary binary (not implemented).
  feasycom('feasycom'),

  /// Minew — proprietary multi-frame GATT (not implemented).
  minew('minew'),

  /// Google Eddystone-GATT FEAA (not implemented).
  eddystoneGatt('eddystone_gatt');

  const BeaconConfigureProtocol(this.storageValue);

  final String storageValue;

  static const BeaconConfigureProtocol defaultProtocol =
      BeaconConfigureProtocol.hm10Ffe0;

  /// Whether this app can program beacons for this protocol.
  bool get isConfigureImplemented => switch (this) {
        hm10Ffe0 || nordicNrf52 || joyway => true,
        _ => false,
      };

  static BeaconConfigureProtocol? tryFromStorage(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final p in values) {
      if (p.storageValue == raw) return p;
    }
    return null;
  }

  static BeaconConfigureProtocol fromStorage(String? raw) {
    return tryFromStorage(raw) ?? defaultProtocol;
  }
}
