part of '../patrol_round_screen.dart';

class _RoutePointCard extends StatelessWidget {
  const _RoutePointCard({
    required this.theme,
    required this.l10n,
    required this.point,
    this.scanned = false,
    this.qrBusy = false,
  });

  final TextTheme theme;
  final AppLocalizations l10n;
  final CheckPoint point;
  final bool scanned;
  final bool qrBusy;

  @override
  Widget build(BuildContext context) {
    final hasQrPayload =
        point.qrImage != null && point.qrImage!.trim().isNotEmpty;
    final hasNfc = point.nfc != null && point.nfc!.trim().isNotEmpty;
    final hasBluetooth =
        point.bluetooth != null && point.bluetooth!.trim().isNotEmpty;
    final isScanned = scanned || point.verified == true;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  '${point.sequenceOrder}',
                  style: theme.titleSmall?.copyWith(
                    color: const Color(0xFF6EE7B7),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FeatureChip(
                theme: theme,
                label: isScanned
                    ? l10n.patrolRoundChipScanned
                    : l10n.patrolRoundChipNotScanned,
                icon: isScanned
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isScanned
                    ? const Color(0xFF34D399)
                    : Colors.white54,
              ),
              if (hasQrPayload)
                _FeatureChip(
                  theme: theme,
                  label: l10n.patrolRoundChipQr,
                  icon: qrBusy
                      ? Icons.hourglass_top_rounded
                      : Icons.qr_code_2_rounded,
                  color: const Color(0xFF6EE7B7),
                ),
              if (hasNfc)
                _FeatureChip(
                  theme: theme,
                  label: l10n.patrolRoundChipNfc,
                  icon: Icons.nfc_rounded,
                  color: Colors.white70,
                ),
              if (hasBluetooth)
                _FeatureChip(
                  theme: theme,
                  label: l10n.patrolRoundChipBluetooth,
                  icon: Icons.bluetooth_rounded,
                  color: const Color(0xFF93C5FD),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

