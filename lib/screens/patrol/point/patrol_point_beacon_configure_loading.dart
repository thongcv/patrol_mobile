part of '../patrol_point_screen.dart';

/// Blocks the UI with a loading dialog while programming the beacon over BLE.
Future<T> _withPatrolBeaconConfigureLoading<T>(
  BuildContext context, {
  required Future<T> Function() task,
  String? title,
  String? hint,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final navigator = Navigator.of(context, rootNavigator: true);

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: PatrolShellColors.surface,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: PatrolShellColors.accent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title ?? l10n.patrolPointBeaconConfiguring,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hint ?? l10n.patrolPointBeaconConfiguringHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  height: 1.35,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  await Future<void>.delayed(Duration.zero);

  try {
    return await task();
  } finally {
    if (navigator.mounted) {
      navigator.pop();
    }
  }
}
