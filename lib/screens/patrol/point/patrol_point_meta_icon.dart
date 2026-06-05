part of '../patrol_point_screen.dart';

class _PatrolPointMetaIcon extends StatelessWidget {
  const _PatrolPointMetaIcon({
    required this.l10n,
    required this.busy,
    required this.icon,
    required this.applyTooltip,
    required this.detailTooltip,
    required this.dialogTitle,
    required this.dialogBody,
    required this.onApply,
    this.readOnly = false,
    this.showTooltip = true,
    this.directApplyWhenHasDetail = false,
  });

  final AppLocalizations l10n;
  final bool busy;
  final IconData icon;
  /// When data exists — hint on long-press / hover.
  final String detailTooltip;
  /// When missing — assign action (always used for NFC / Bluetooth / GPS).
  final String applyTooltip;
  final String dialogTitle;
  final String Function() dialogBody;
  final VoidCallback onApply;
  final bool readOnly;
  final bool showTooltip;
  /// Tap runs [onApply] even when detail exists (e.g. Bluetooth reconfigure).
  final bool directApplyWhenHasDetail;

  Future<void> _showDetailDialog(BuildContext context) async {
    final body = dialogBody();
    if (body.trim().isEmpty) return;
    await _showPatrolCheckpointMetaDialog(
      context,
      l10n: l10n,
      title: dialogTitle,
      body: body,
      onEdit: readOnly ? null : onApply,
    );
  }

  Future<void> _onTap(BuildContext context) async {
    if (busy) return;
    final body = dialogBody();
    final hasDetail = body.trim().isNotEmpty;
    if (!hasDetail || directApplyWhenHasDetail) {
      onApply();
      return;
    }
    await _showDetailDialog(context);
  }

  Future<void> _onLongPress(BuildContext context) async {
    if (busy) return;
    final body = dialogBody();
    if (body.trim().isEmpty) return;
    await _showDetailDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final body = dialogBody();
    final hasDetail = body.trim().isNotEmpty;
    final accent = hasDetail
        ? PatrolShellColors.accent
        : Colors.white.withValues(alpha: 0.55);
    final hint = hasDetail && directApplyWhenHasDetail
        ? applyTooltip
        : (hasDetail ? detailTooltip : applyTooltip);

    final button = GestureDetector(
      onLongPress: busy || !hasDetail ? null : () => _onLongPress(context),
      child: IconButton.filledTonal(
      onPressed: busy ? null : () => _onTap(context),
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      style: IconButton.styleFrom(
        backgroundColor: PatrolShellColors.accent.withValues(
          alpha: hasDetail ? 0.28 : 0.14,
        ),
        foregroundColor: accent,
      ),
      icon: busy
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accent,
              ),
            )
          : Icon(icon, size: 26),
      ),
    );

    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: button,
    );

    if (showTooltip) {
      return Tooltip(
        message: hint,
        child: padded,
      );
    }
    return padded;
  }
}

