part of '../patrol_point_screen.dart';

/// Returns configure password, or `null` if cancelled. Empty string = no password.
Future<String?> _showPatrolBeaconConfigurePasswordDialog(
  BuildContext context, {
  required BeaconConfigureProtocol protocol,
}) async {
  final l10n = AppLocalizations.of(context)!;
  if (!context.mounted) return null;

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PatrolBeaconConfigurePasswordDialog(
      l10n: l10n,
      protocol: protocol,
    ),
  );
}

/// Login password right after picker Connect (before settings).
Future<String?> _promptBeaconLoginPasswordAfterConnect(
  BuildContext context, {
  required BeaconConfigureProtocol protocol,
}) async {
  switch (protocol) {
    case BeaconConfigureProtocol.nordicNrf52:
      return '';
    case BeaconConfigureProtocol.joyway:
    case BeaconConfigureProtocol.hm10Ffe0:
      if (!context.mounted) return null;
      return _showPatrolBeaconConfigurePasswordDialog(
        context,
        protocol: protocol,
      );
    default:
      return '';
  }
}

class _PatrolBeaconConfigurePasswordDialog extends StatefulWidget {
  const _PatrolBeaconConfigurePasswordDialog({
    required this.l10n,
    required this.protocol,
  });

  final AppLocalizations l10n;
  final BeaconConfigureProtocol protocol;

  @override
  State<_PatrolBeaconConfigurePasswordDialog> createState() =>
      _PatrolBeaconConfigurePasswordDialogState();
}

class _PatrolBeaconConfigurePasswordDialogState
    extends State<_PatrolBeaconConfigurePasswordDialog> {
  late final TextEditingController _passwordCtrl;
  bool _userTyped = false;

  @override
  void initState() {
    super.initState();
    _passwordCtrl = TextEditingController();
    _scheduleAutofillStrip();
  }

  /// OS password managers may inject saved credentials into obscure fields.
  void _scheduleAutofillStrip() {
    for (final delay in const [
      Duration.zero,
      Duration(milliseconds: 120),
      Duration(milliseconds: 350),
    ]) {
      Future<void>.delayed(delay, () {
        if (!mounted || _userTyped) return;
        if (_passwordCtrl.text.isNotEmpty) {
          _passwordCtrl.clear();
        }
      });
    }
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _protocolHint() {
    final l10n = widget.l10n;
    return switch (widget.protocol) {
      BeaconConfigureProtocol.hm10Ffe0 =>
        l10n.patrolPointBeaconLoginHm10Hint,
      BeaconConfigureProtocol.joyway =>
        l10n.patrolPointBeaconLoginJoywayHint,
      BeaconConfigureProtocol.nordicNrf52 =>
        l10n.patrolPointBeaconPasswordNordicHint,
      _ => l10n.patrolPointBeaconPasswordOptionalHint,
    };
  }

  void _onContinue() {
    Navigator.of(context).pop(_passwordCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final passwordMaxLen =
        widget.protocol == BeaconConfigureProtocol.joyway ? 12 : 32;

    return AlertDialog(
      backgroundColor: PatrolShellColors.surface,
      title: Text(
        l10n.patrolPointBeaconLoginDialogTitle,
        style: const TextStyle(color: Colors.white),
      ),
      content: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _protocolHint(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('patrol_beacon_connect_password'),
              controller: _passwordCtrl,
              autofillHints: const <String>[],
              enableIMEPersonalizedLearning: false,
              enableSuggestions: false,
              obscureText: true,
              maxLength: passwordMaxLen,
              keyboardType: widget.protocol == BeaconConfigureProtocol.joyway
                  ? TextInputType.visiblePassword
                  : const TextInputType.numberWithOptions(
                      signed: false,
                      decimal: false,
                    ),
              autocorrect: false,
              onChanged: (_) => _userTyped = true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.patrolPointBeaconPasswordLabel,
                hintText: l10n.patrolPointBeaconPasswordOptionalHint,
                labelStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: PatrolShellColors.accent),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.patrolRoundCancel),
        ),
        FilledButton(
          onPressed: _onContinue,
          child: Text(l10n.patrolPointBeaconPasswordContinue),
        ),
      ],
    );
  }
}
