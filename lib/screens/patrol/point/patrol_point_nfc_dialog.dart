part of '../patrol_point_screen.dart';

class _NfcIdentifierInputDialog extends StatefulWidget {
  const _NfcIdentifierInputDialog({
    this.initial,
    required this.messenger,
  });

  final String? initial;
  final ScaffoldMessengerState messenger;

  @override
  State<_NfcIdentifierInputDialog> createState() =>
      _NfcIdentifierInputDialogState();
}

class _NfcIdentifierInputDialogState extends State<_NfcIdentifierInputDialog> {
  late final TextEditingController _controller;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_scanning) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _scanning = true);
    final result = await readNfcTagIdentifier(
      iosAlertMessage: l10n.patrolPointNfcScanning,
    );
    if (!mounted) return;
    setState(() => _scanning = false);
    if (result.ok) {
      _controller.text = result.identifier!;
    } else if (result.failure != null) {
      widget.messenger.showSnackBar(
        SnackBar(
          content: Text(_nfcScanFailureMessage(l10n, result.failure!)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canScan = isNfcScanSupported;

    return AlertDialog(
      backgroundColor: PatrolShellColors.surface,
      title: Text(
        l10n.patrolPointNfcDialogTitle,
        style: const TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canScan) ...[
            OutlinedButton.icon(
              onPressed: _scanning ? null : _startScan,
              icon: _scanning
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PatrolShellColors.accent.withValues(
                          alpha: 0.9,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.nfc_rounded,
                      color: PatrolShellColors.accent.withValues(alpha: 0.95),
                    ),
              label: Text(
                _scanning
                    ? l10n.patrolPointNfcScanning
                    : l10n.patrolPointNfcScanButton,
                style: TextStyle(
                  color: _scanning ? Colors.white54 : PatrolShellColors.accent,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autofocus: !canScan,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: l10n.patrolPointNfcDialogHint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _scanning ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.patrolRoundCancel),
        ),
        FilledButton(
          onPressed: _scanning
              ? null
              : () => Navigator.of(context).pop(_controller.text.trim()),
          style: FilledButton.styleFrom(
            backgroundColor: PatrolShellColors.accent,
            foregroundColor: PatrolShellColors.background,
          ),
          child: Text(l10n.patrolPointDialogSave),
        ),
      ],
    );
  }
}

