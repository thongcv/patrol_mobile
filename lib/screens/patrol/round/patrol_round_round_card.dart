part of '../patrol_round_screen.dart';

class _RoundCard extends StatelessWidget {
  const _RoundCard({
    super.key,
    required this.theme,
    required this.l10n,
    required this.round,
    required this.statusLabel,
    required this.statusColor,
    required this.loading,
    required this.onReload,
    this.qrScanBusy = false,
    this.onQrScan,
    this.nfcScanBusy = false,
    this.onNfcScan,
    this.autoScanBusy = false,
    this.onAutoScan,
    this.autoScanBluetoothBusy = false,
    this.onAutoScanBluetooth,
  });

  final TextTheme theme;
  final AppLocalizations l10n;
  final PatrolRound round;
  final String statusLabel;
  final Color statusColor;
  final bool loading;
  final VoidCallback onReload;
  final bool qrScanBusy;
  final VoidCallback? onQrScan;
  final bool nfcScanBusy;
  final VoidCallback? onNfcScan;
  final bool autoScanBusy;
  final VoidCallback? onAutoScan;
  final bool autoScanBluetoothBusy;
  final VoidCallback? onAutoScanBluetooth;

  @override
  Widget build(BuildContext context) {
    final assignee = round.assignedName?.trim();

    return _PatrolPanel(
      accent: statusColor.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.route_rounded,
                size: 20,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        l10n.patrolRoundRoundHeading,
                        style: theme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#${round.id}',
                      style: theme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                    ),
                  ],
                ),
              ),
              _StatusChip(
                label: statusLabel,
                color: statusColor,
                filled: true,
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                onPressed: loading ? null : onReload,
                style: IconButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF34D399).withValues(alpha: 0.18),
                  foregroundColor: const Color(0xFF34D399),
                ),
                tooltip: l10n.patrolRoundReload,
                icon: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 22,
                      color: loading
                          ? const Color(0xFF34D399).withValues(alpha: 0.35)
                          : const Color(0xFF34D399),
                    ),
                    if (loading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF34D399),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoRow(
            theme: theme,
            icon: Icons.play_circle_outline_rounded,
            label: l10n.patrolRoundExpectedStart,
            value: formatPatrolIsoDateTime(round.expectedStartTime),
          ),
          const SizedBox(height: 8),
          _InfoRow(
            theme: theme,
            icon: Icons.stop_circle_outlined,
            label: l10n.patrolRoundExpectedEnd,
            value: formatPatrolIsoDateTime(round.expectedEndTime),
          ),
          if (assignee != null && assignee.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(
              theme: theme,
              icon: Icons.person_outline_rounded,
              label: l10n.patrolRoundAssigned,
              value: assignee,
            ),
          ],
          if (onQrScan != null ||
              onNfcScan != null ||
              onAutoScan != null ||
              onAutoScanBluetooth != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (onAutoScan != null)
                  _PatrolScanActionTile(
                    onTap: onAutoScan,
                    busy: autoScanBusy,
                    icon: Icons.auto_mode_rounded,
                    label: l10n.patrolRoundAutoScan,
                  ),
                if (onAutoScanBluetooth != null)
                  _PatrolScanActionTile(
                    onTap: onAutoScanBluetooth,
                    busy: autoScanBluetoothBusy,
                    icon: Icons.bluetooth_rounded,
                    label: l10n.patrolRoundAutoScanBluetooth,
                  ),
                if (onQrScan != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: qrScanBusy ? null : onQrScan,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: kPatrolQrPreviewSize,
                        height: kPatrolQrPreviewSize,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34D399).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF34D399)
                                .withValues(alpha: 0.45),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          qrScanBusy
                              ? Icons.hourglass_top_rounded
                              : Icons.qr_code_scanner_rounded,
                          size: 36,
                          color: qrScanBusy
                              ? const Color(0xFF34D399).withValues(alpha: 0.45)
                              : const Color(0xFF34D399),
                        ),
                      ),
                    ),
                  ),
                if (onNfcScan != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: nfcScanBusy ? null : onNfcScan,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: kPatrolQrPreviewSize,
                        height: kPatrolQrPreviewSize,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34D399).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF34D399)
                                .withValues(alpha: 0.45),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          nfcScanBusy
                              ? Icons.hourglass_top_rounded
                              : Icons.nfc_rounded,
                          size: 36,
                          color: nfcScanBusy
                              ? const Color(0xFF34D399).withValues(alpha: 0.45)
                              : const Color(0xFF34D399),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Photo capture popup after checkpoint match (GPS / scan).
