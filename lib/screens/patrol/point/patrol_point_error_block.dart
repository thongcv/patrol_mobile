part of '../patrol_point_screen.dart';

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.theme,
    required this.l10n,
    required this.onRetry,
  });

  final TextTheme theme;
  final AppLocalizations l10n;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PatrolShellColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.patrolPointLoadFailed,
            style: theme.bodyMedium?.copyWith(
              color: Colors.orangeAccent.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: PatrolShellColors.accent,
              foregroundColor: PatrolShellColors.background,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(l10n.patrolPointReload),
          ),
        ],
      ),
    );
  }
}

