part of '../patrol_point_screen.dart';

class _CheckPointCard extends StatelessWidget {
  const _CheckPointCard({
    required this.theme,
    required this.point,
    required this.l10n,
    required this.nfcBusy,
    required this.bluetoothBusy,
    required this.gpsBusy,
    required this.onApplyNfc,
    required this.onApplyBluetooth,
    required this.onApplyGps,
  });

  final TextTheme theme;
  final CheckPoint point;
  final AppLocalizations l10n;
  final bool nfcBusy;
  final bool bluetoothBusy;
  final bool gpsBusy;
  final VoidCallback onApplyNfc;
  final VoidCallback onApplyBluetooth;
  final VoidCallback onApplyGps;

  bool get _anyMetaBusy => nfcBusy || bluetoothBusy || gpsBusy;

  @override
  Widget build(BuildContext context) {
    final hasNfc = point.nfc != null && point.nfc!.trim().isNotEmpty;
    final hasBluetooth =
        point.bluetooth != null && point.bluetooth!.trim().isNotEmpty;
    final hasQrCode =
        point.qrCode != null && point.qrCode!.trim().isNotEmpty;
    final hasCoords = point.hasCoordinates;

    final needsAssignMenu = !hasNfc || !hasBluetooth || !hasCoords;

    String bluetoothDetailBody() {
      if (!hasBluetooth) return '';
      final buf = StringBuffer(
        l10n.patrolPointBluetoothValue(point.bluetooth!.trim()),
      );
      final rssi = point.rssi;
      if (rssi != null) {
        buf.write('\nRSSI: $rssi dBm');
      }
      return buf.toString();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: PatrolShellColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PatrolShellColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  '${point.sequenceOrder}',
                  style: theme.titleSmall?.copyWith(
                    color: PatrolShellColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        point.name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (!point.active)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n.patrolPointInactive,
                            style: theme.labelSmall?.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (needsAssignMenu)
                PopupMenuButton<String>(
                  enabled: !_anyMetaBusy,
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'nfc':
                        onApplyNfc();
                        break;
                      case 'bluetooth':
                        onApplyBluetooth();
                        break;
                      case 'gps':
                        onApplyGps();
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (!hasNfc)
                      PopupMenuItem(
                        value: 'nfc',
                        child: Text(l10n.patrolPointUpdateNfcTooltip),
                      ),
                    if (!hasBluetooth)
                      PopupMenuItem(
                        value: 'bluetooth',
                        child: Text(l10n.patrolPointUpdateBluetoothTooltip),
                      ),
                    if (!hasCoords)
                      PopupMenuItem(
                        value: 'gps',
                        child: Text(l10n.patrolPointUpdateCoordsTooltip),
                      ),
                  ],
                ),
            ],
          ),
          if (hasCoords) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: theme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.45),
                    height: 1.35,
                  ),
                  children: [
                    TextSpan(
                      text: '${l10n.patrolPointCheckpointCoordsLabel}: ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.15,
                      ),
                    ),
                    TextSpan(
                      text:
                          '${point.latitude!.toStringAsFixed(6)}, '
                          '${point.longitude!.toStringAsFixed(6)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (hasNfc)
                _PatrolPointMetaIcon(
                  l10n: l10n,
                  busy: nfcBusy,
                  icon: Icons.nfc_rounded,
                  applyTooltip: l10n.patrolPointUpdateNfcTooltip,
                  detailTooltip: l10n.patrolPointNfcValue(point.nfc!.trim()),
                  dialogTitle: l10n.patrolPointNfcDialogTitle,
                  dialogBody: () => point.nfc!.trim(),
                  onApply: onApplyNfc,
                ),
              if (hasBluetooth)
                _PatrolPointMetaIcon(
                  l10n: l10n,
                  busy: bluetoothBusy,
                  icon: Icons.bluetooth_rounded,
                  applyTooltip: l10n.patrolPointUpdateBluetoothTooltip,
                  detailTooltip:
                      l10n.patrolPointBluetoothValue(point.bluetooth!.trim()),
                  dialogTitle: l10n.patrolPointBluetoothDialogTitle,
                  dialogBody: bluetoothDetailBody,
                  onApply: onApplyBluetooth,
                ),
              if (hasQrCode)
                _PatrolPointMetaIcon(
                  l10n: l10n,
                  busy: false,
                  icon: Icons.qr_code_scanner_rounded,
                  applyTooltip: l10n.patrolRoundChipQr,
                  detailTooltip: point.qrCode!.trim(),
                  dialogTitle: l10n.patrolRoundChipQr,
                  dialogBody: () => point.qrCode!.trim(),
                  onApply: () {},
                  readOnly: true,
                  showTooltip: false,
                ),
              if (hasCoords)
                _PatrolPointMetaIcon(
                  l10n: l10n,
                  busy: gpsBusy,
                  icon: Icons.gps_fixed_rounded,
                  applyTooltip: l10n.patrolPointUpdateCoordsTooltip,
                  detailTooltip: patrolServerCoordLabel(
                    l10n,
                    point.latitude!,
                    point.longitude!,
                    altitude: point.gpsAltitude != null &&
                            point.gpsAltitude!.isFinite
                        ? point.gpsAltitude
                        : null,
                  ),
                  dialogTitle: l10n.patrolRoundChipGps,
                  dialogBody: () => patrolServerCoordLabel(
                    l10n,
                    point.latitude!,
                    point.longitude!,
                    altitude: point.gpsAltitude != null &&
                            point.gpsAltitude!.isFinite
                        ? point.gpsAltitude
                        : null,
                  ),
                  onApply: onApplyGps,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
