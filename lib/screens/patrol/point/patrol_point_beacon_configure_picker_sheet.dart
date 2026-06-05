part of '../patrol_point_screen.dart';

/// Bottom sheet: scan BLE devices; user taps Connect to proceed.
Future<BleConfigureDeviceEntry?> _showPatrolBeaconConfigurePickerSheet(
  BuildContext context,
) async {
  if (!isIBeaconConfigureSupported) return null;

  try {
    if (!await beaconBleEnsurePermissions()) return null;
  } catch (_) {
    return null;
  }

  if (!context.mounted) return null;

  return showModalBottomSheet<BleConfigureDeviceEntry>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => const _PatrolBeaconConfigurePickerSheet(),
  );
}

class _PatrolBeaconConfigurePickerSheet extends StatefulWidget {
  const _PatrolBeaconConfigurePickerSheet();

  @override
  State<_PatrolBeaconConfigurePickerSheet> createState() =>
      _PatrolBeaconConfigurePickerSheetState();
}

class _PatrolBeaconConfigurePickerSheetState
    extends State<_PatrolBeaconConfigurePickerSheet> {
  BleConfigureDeviceScanHandle? _scanHandle;
  List<BleConfigureDeviceEntry> _devices = const [];
  bool _scanning = true;
  String? _errorKey;
  String? _revealedDeviceId;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _errorKey = null;
      _devices = const [];
    });

    await _scanHandle?.stop();

    if (!await beaconBleEnsurePermissions()) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _errorKey = 'permission';
      });
      return;
    }

    if (!await beaconBleEnsureAdapterOn()) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _errorKey = 'disabled';
      });
      return;
    }

    try {
      _scanHandle = await beaconBleStartConfigureDeviceScan(
        scanDuration: const Duration(seconds: 35),
        onUpdate: (list) {
          if (!mounted) return;
          setState(() {
            _devices = list;
            if (list.isNotEmpty) _scanning = false;
          });
        },
        onScanError: (msg) {
          if (!mounted || msg == null || msg.isEmpty) return;
          setState(() => _errorKey = 'failed');
        },
        onScanFinished: () {
          if (!mounted) return;
          setState(() => _scanning = false);
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _errorKey = 'failed';
      });
    }
  }

  void _connectDevice(BleConfigureDeviceEntry device) {
    unawaited(_scanHandle?.stop());
    beaconBleStartWarmConnect(device);
    Navigator.pop(context, device);
  }

  @override
  void dispose() {
    _scanHandle?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mat = Theme.of(context);
    final maxH = MediaQuery.sizeOf(context).height * 0.72;

    return SizedBox(
      height: maxH,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.patrolPointBeaconConfigurePickerTitle,
                        style: mat.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.patrolPointBeaconConfigurePickerHint,
                        style: mat.textTheme.bodySmall?.copyWith(
                          color: mat.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _scanning ? null : _startScan,
                  tooltip: l10n.patrolPointBeaconConfigurePickerRescan,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: MaterialLocalizations.of(context).cancelButtonLabel,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          if (_scanning)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _devices.isEmpty
                          ? l10n.patrolPointBeaconConfigurePickerScanning
                          : l10n.patrolPointBeaconConfigurePickerScanningCount(
                              _devices.length,
                            ),
                      style: mat.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          if (_errorKey != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                switch (_errorKey) {
                  'disabled' => l10n.patrolPointBluetoothDisabled,
                  'permission' => l10n.patrolPointBluetoothPermissionDenied,
                  _ => l10n.patrolPointBluetoothScanFailed,
                },
                style: mat.textTheme.bodyMedium?.copyWith(
                  color: mat.colorScheme.error,
                ),
              ),
            ),
          Expanded(child: _buildList(l10n, mat)),
        ],
      ),
    );
  }

  Widget _buildList(AppLocalizations l10n, ThemeData mat) {
    if (_devices.isEmpty && !_scanning && _errorKey == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.patrolPointBeaconConfigurePickerEmpty,
            textAlign: TextAlign.center,
            style: mat.textTheme.bodyMedium?.copyWith(
              color: mat.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: _devices
          .map(
            (d) => _PickerDeviceTile(
              device: d,
              l10n: l10n,
              mat: mat,
              revealed: _revealedDeviceId == d.remoteId,
              onReveal: () {
                setState(() {
                  _revealedDeviceId =
                      _revealedDeviceId == d.remoteId ? null : d.remoteId;
                });
              },
              onConnect: () => _connectDevice(d),
            ),
          )
          .toList(),
    );
  }
}

class _PickerDeviceTile extends StatefulWidget {
  const _PickerDeviceTile({
    required this.device,
    required this.l10n,
    required this.mat,
    required this.revealed,
    required this.onReveal,
    required this.onConnect,
  });

  final BleConfigureDeviceEntry device;
  final AppLocalizations l10n;
  final ThemeData mat;
  final bool revealed;
  final VoidCallback onReveal;
  final VoidCallback onConnect;

  @override
  State<_PickerDeviceTile> createState() => _PickerDeviceTileState();
}

class _PickerDeviceTileState extends State<_PickerDeviceTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.device;
    final l10n = widget.l10n;
    final mat = widget.mat;
    final showConnect = widget.revealed || _hovered;

    final broadcastName = d.pickerBroadcastName?.trim();
    final hasBroadcastName =
        broadcastName != null && broadcastName.isNotEmpty;
    final uuidStr = d.uuid?.trim().isNotEmpty == true ? d.uuid! : '—';
    final majorStr = d.major != null ? '${d.major}' : '—';
    final minorStr = d.minor != null ? '${d.minor}' : '—';
    final bodyStyle = mat.textTheme.bodySmall?.copyWith(
      color: mat.colorScheme.onSurfaceVariant,
      height: 1.2,
    );
    final valueStyle = bodyStyle?.copyWith(
      fontFamily: 'monospace',
      fontSize: 11,
      color: mat.colorScheme.onSurface,
    );
    final titleStyle = mat.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: mat.colorScheme.onSurface,
      height: 1.2,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: mat.colorScheme.surfaceContainerHighest.withValues(
          alpha: widget.revealed ? 0.75 : 0.5,
        ),
        child: InkWell(
          onTap: widget.onReveal,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.bluetooth_rounded,
                  color: mat.colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasBroadcastName ? broadcastName : '—',
                        style: titleStyle,
                      ),
                      const SizedBox(height: 4),
                      _pickerIBeaconLine(
                        l10n.patrolPointBeaconConfigurePickerUuidLabel(uuidStr),
                        bodyStyle,
                        valueStyle,
                      ),
                      const SizedBox(height: 2),
                      _pickerIBeaconLine(
                        l10n.patrolPointBeaconConfigurePickerMacLabel(
                          d.pickerListTitle,
                        ),
                        bodyStyle,
                        valueStyle,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _pickerIBeaconLine(
                            l10n.patrolPointBeaconConfigurePickerRssi(d.rssi),
                            bodyStyle,
                            valueStyle,
                          ),
                          const SizedBox(width: 12),
                          _pickerIBeaconLine(
                            l10n.patrolPointBeaconConfigurePickerMajorMinorLabel(
                              majorStr,
                              minorStr,
                            ),
                            bodyStyle,
                            valueStyle,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: showConnect
                      ? Padding(
                          key: const ValueKey('connect'),
                          padding: const EdgeInsets.only(left: 4),
                          child: FilledButton.tonal(
                            onPressed: widget.onConnect,
                            child: Text(
                              l10n.patrolPointBeaconConfigurePickerConnect,
                            ),
                          ),
                        )
                      : const SizedBox(
                          key: ValueKey('spacer'),
                          width: 4,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Splits "Label: value" so the value uses [valueStyle].
  Widget _pickerIBeaconLine(
    String line,
    TextStyle? bodyStyle,
    TextStyle? valueStyle,
  ) {
    final colon = line.indexOf(':');
    if (colon < 0) {
      return Text(
        line,
        style: bodyStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final label = line.substring(0, colon + 1);
    final value = line.substring(colon + 1).trim();
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: label, style: bodyStyle),
          const TextSpan(text: ' '),
          TextSpan(text: value, style: valueStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
