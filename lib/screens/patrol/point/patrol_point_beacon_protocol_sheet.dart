part of '../patrol_point_screen.dart';

String _beaconProtocolTitle(
  AppLocalizations l10n,
  BeaconConfigureProtocol protocol,
) {
  return switch (protocol) {
    BeaconConfigureProtocol.hm10Ffe0 => l10n.patrolPointBeaconProtocolHm10,
    BeaconConfigureProtocol.nordicNrf52 => l10n.patrolPointBeaconProtocolNordic,
    BeaconConfigureProtocol.joyway => l10n.patrolPointBeaconProtocolJoyway,
    BeaconConfigureProtocol.feasycom => l10n.patrolPointBeaconProtocolFeasycom,
    BeaconConfigureProtocol.minew => l10n.patrolPointBeaconProtocolMinew,
    BeaconConfigureProtocol.eddystoneGatt =>
      l10n.patrolPointBeaconProtocolEddystone,
  };
}

String? _beaconProtocolSubtitle(
  AppLocalizations l10n,
  BeaconConfigureProtocol protocol,
) {
  return switch (protocol) {
    BeaconConfigureProtocol.hm10Ffe0 => l10n.patrolPointBeaconProtocolHm10Hint,
    BeaconConfigureProtocol.nordicNrf52 =>
      l10n.patrolPointBeaconProtocolNordicHint,
    BeaconConfigureProtocol.joyway => l10n.patrolPointBeaconProtocolJoywayHint,
    BeaconConfigureProtocol.feasycom ||
    BeaconConfigureProtocol.minew ||
    BeaconConfigureProtocol.eddystoneGatt =>
      l10n.patrolPointBeaconProtocolComingSoon,
  };
}

/// Returns chosen protocol, or `null` if cancelled.
Future<BeaconConfigureProtocol?> _pickBeaconConfigureProtocol(
  BuildContext context, {
  required BeaconConfigureProtocol initial,
  BeaconConfigureProtocol? checkpointProtocol,
}) async {
  final l10n = AppLocalizations.of(context)!;
  if (!context.mounted) return null;

  return showDialog<BeaconConfigureProtocol>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PatrolBeaconConfigureProtocolDialog(
      l10n: l10n,
      initial: initial,
      checkpointProtocol: checkpointProtocol,
    ),
  );
}

class _PatrolBeaconConfigureProtocolDialog extends StatefulWidget {
  const _PatrolBeaconConfigureProtocolDialog({
    required this.l10n,
    required this.initial,
    this.checkpointProtocol,
  });

  final AppLocalizations l10n;
  final BeaconConfigureProtocol initial;
  final BeaconConfigureProtocol? checkpointProtocol;

  @override
  State<_PatrolBeaconConfigureProtocolDialog> createState() =>
      _PatrolBeaconConfigureProtocolDialogState();
}

class _PatrolBeaconConfigureProtocolDialogState
    extends State<_PatrolBeaconConfigureProtocolDialog> {
  late BeaconConfigureProtocol _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial.isConfigureImplemented
        ? widget.initial
        : BeaconConfigureProtocol.defaultProtocol;
  }

  void _onContinue([BeaconConfigureProtocol? protocol]) {
    Navigator.of(context).pop(protocol ?? _selected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final checkpoint = widget.checkpointProtocol;

    return AlertDialog(
      backgroundColor: PatrolShellColors.surface,
      title: Text(
        l10n.patrolPointBeaconProtocolLabel,
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (checkpoint != null) ...[
                FilledButton(
                  onPressed: () => _onContinue(checkpoint),
                  child: Text(
                    l10n.patrolPointBeaconProtocolUseCheckpoint(
                      _beaconProtocolTitle(l10n, checkpoint),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              for (final protocol in BleConfigureDeviceEntry.pickerManualProtocols)
                RadioListTile<BeaconConfigureProtocol>(
                  value: protocol,
                  groupValue: _selected,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selected = value);
                  },
                  activeColor: PatrolShellColors.accent,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _beaconProtocolTitle(l10n, protocol),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                  subtitle: Text(
                    _beaconProtocolSubtitle(l10n, protocol) ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.patrolRoundCancel),
        ),
        FilledButton(
          onPressed: () => _onContinue(),
          child: Text(l10n.patrolPointBeaconPasswordContinue),
        ),
      ],
    );
  }
}
