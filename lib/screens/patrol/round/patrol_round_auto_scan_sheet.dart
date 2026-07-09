part of '../patrol_round_screen.dart';

/// Bottom sheet shown while an auto scan (GPS / Bluetooth) waits for a match.
/// Pure UI: renders [statusNotifier] updates and a cancel action; proximity
/// detail appears only when a status carries a snapshot (GPS flow).
class _AutoScanWaitingSheet extends StatelessWidget {
  const _AutoScanWaitingSheet({
    required this.l10n,
    required this.statusNotifier,
    required this.onCancel,
  });

  final AppLocalizations l10n;
  final ValueNotifier<_QrScanProximityStatus> statusNotifier;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Material(
        color: PatrolShellColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ValueListenableBuilder<_QrScanProximityStatus>(
                valueListenable: statusNotifier,
                builder: (context, status, _) {
                  final bodyStyle =
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                            height: 1.45,
                          );
                  final detail = status.snapshot;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        status.headline,
                        textAlign: TextAlign.center,
                        style: bodyStyle,
                      ),
                      if (detail != null) ...[
                        const SizedBox(height: 14),
                        _QrProximityDetailPanel(
                          l10n: l10n,
                          snapshot: detail,
                          baroPending: status.baroPending,
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF34D399),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: onCancel,
                child: Text(l10n.patrolRoundCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
