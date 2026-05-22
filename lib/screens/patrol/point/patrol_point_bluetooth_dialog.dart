part of '../patrol_point_screen.dart';

class _BluetoothIdentifierInputDialog extends StatefulWidget {
  const _BluetoothIdentifierInputDialog({
    this.initial,
    required this.messenger,
  });

  final String? initial;
  final ScaffoldMessengerState messenger;

  @override
  State<_BluetoothIdentifierInputDialog> createState() =>
      _BluetoothIdentifierInputDialogState();
}

class _BluetoothIdentifierInputDialogState
    extends State<_BluetoothIdentifierInputDialog> {
  late final TextEditingController _controller;
  bool _scanning = false;
  BluetoothBeaconDetails? _lastBeacon;

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
    final result = await readBluetoothBeaconIdentifier(
      timeout: kBluetoothDiscoveryScanTimeout,
      minRssi: kBluetoothDiscoveryMinRssi,
      successRssi: kBluetoothDiscoverySuccessRssi,
      stableHits: kBluetoothDiscoveryStableHits,
    );
    if (!mounted) return;
    if (result.ok) {
      setState(() {
        _scanning = false;
        _controller.text = result.identifier!;
        _lastBeacon = result.beacon;
      });
    } else {
      setState(() => _scanning = false);
    }
    if (!result.ok && result.failure != null) {
      widget.messenger.showSnackBar(
        SnackBar(
          content: Text(_bluetoothScanFailureMessage(l10n, result.failure!)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canScan = isBluetoothScanSupported;

    return AlertDialog(
      backgroundColor: PatrolShellColors.surface,
      title: Text(
        l10n.patrolPointBluetoothDialogTitle,
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
                      Icons.bluetooth_rounded,
                      color: PatrolShellColors.accent.withValues(alpha: 0.95),
                    ),
              label: Text(
                _scanning
                    ? l10n.patrolPointBluetoothScanning
                    : l10n.patrolPointBluetoothScanButton,
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
          if (_lastBeacon != null) ...[
            Text(
              _bluetoothScanSummary(l10n, _lastBeacon!),
              style: TextStyle(
                color: PatrolShellColors.accent.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
            if (_bluetoothScanMetaLine(l10n, _lastBeacon!) != null) ...[
              const SizedBox(height: 4),
              Text(
                _bluetoothScanMetaLine(l10n, _lastBeacon!)!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
            ],
            if (_lastBeacon!.deviceName != null &&
                _lastBeacon!.deviceName!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                l10n.patrolPointBluetoothScanName(
                  _lastBeacon!.deviceName!.trim(),
                ),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autofocus: !canScan,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: l10n.patrolPointBluetoothDialogHint,
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
            onSubmitted: (v) => Navigator.of(context).pop(
                  BluetoothReadResult.success(
                    v.trim(),
                    beacon: _lastBeacon,
                  ),
                ),
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
              : () => Navigator.of(context).pop(
                    BluetoothReadResult.success(
                      _controller.text.trim(),
                      beacon: _lastBeacon,
                    ),
                  ),
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

