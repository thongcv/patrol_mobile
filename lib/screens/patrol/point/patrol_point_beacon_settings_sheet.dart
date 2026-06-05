part of '../patrol_point_screen.dart';

/// Values confirmed in the beacon configure form.
class PatrolBeaconConfigureFormResult {
  const PatrolBeaconConfigureFormResult({
    required this.name,
    required this.newBeaconPassword,
    required this.uuid,
    required this.major,
    required this.minor,
    required this.txPowerAt1m,
    this.joywayExtended,
  });

  /// BLE broadcast name written to hardware when supported (empty = skip).
  final String name;
  /// New password to write on the beacon (empty = keep current).
  final String newBeaconPassword;
  final String uuid;
  final int major;
  final int minor;
  /// RSSI at 1 m for Joyway; measured power for other protocols.
  final int txPowerAt1m;
  final JoywayBeaconExtendedSettings? joywayExtended;
}

/// Edit beacon values (name, password, UUID, major, minor) before programming.
Future<PatrolBeaconConfigureFormResult?> _showPatrolBeaconSettingsSheet(
  BuildContext context, {
  required BleConfigureDeviceEntry device,
  required BeaconConfigureProtocol protocol,
  required String targetUuid,
  required int targetMajor,
  required int targetMinor,
  required String pointName,
  String? initialNewBeaconPassword,
  bool lockNewBeaconPassword = false,
}) async {
  return showModalBottomSheet<PatrolBeaconConfigureFormResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    showDragHandle: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: PatrolShellColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final topInset = MediaQuery.viewPaddingOf(ctx).top;
      final bottomInset = MediaQuery.viewPaddingOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(top: topInset),
        child: _PatrolBeaconSettingsSheet(
          device: device,
          protocol: protocol,
          targetUuid: targetUuid,
          targetMajor: targetMajor,
          targetMinor: targetMinor,
          pointName: pointName,
          initialNewBeaconPassword: initialNewBeaconPassword,
          lockNewBeaconPassword: lockNewBeaconPassword,
          bottomSafeInset: bottomInset,
        ),
      );
    },
  );
}

class _PatrolBeaconSettingsSheet extends StatefulWidget {
  const _PatrolBeaconSettingsSheet({
    required this.device,
    required this.protocol,
    required this.targetUuid,
    required this.targetMajor,
    required this.targetMinor,
    required this.pointName,
    this.initialNewBeaconPassword,
    this.lockNewBeaconPassword = false,
    required this.bottomSafeInset,
  });

  final BleConfigureDeviceEntry device;
  final BeaconConfigureProtocol protocol;
  final String targetUuid;
  final int targetMajor;
  final int targetMinor;
  final String pointName;
  final String? initialNewBeaconPassword;
  final bool lockNewBeaconPassword;
  final double bottomSafeInset;

  @override
  State<_PatrolBeaconSettingsSheet> createState() =>
      _PatrolBeaconSettingsSheetState();
}

class _PatrolBeaconSettingsSheetState extends State<_PatrolBeaconSettingsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _newPasswordCtrl;
  late final TextEditingController _uuidCtrl;
  late final TextEditingController _majorCtrl;
  late final TextEditingController _minorCtrl;
  late final TextEditingController _rssiAt1mCtrl;
  late final TextEditingController _adv1IntervalCtrl;
  late final TextEditingController _adv1TimeLenCtrl;
  late final TextEditingController _adv2IntervalCtrl;
  late final TextEditingController _adv2TimeLenCtrl;
  late final TextEditingController _buttonDelayCtrl;
  late final TextEditingController _txPowerCtrl;
  bool _showNewPassword = false;
  bool _adv1NeverStop = false;
  bool _adv2NeverStop = true;
  bool _advertiseButtonEvent = false;
  int _txPowerDbm = 0;

  bool get _isJoyway => widget.protocol == BeaconConfigureProtocol.joyway;

  @override
  void initState() {
    super.initState();
    final defaultRssi = widget.device.txPowerAt1m ?? -59;
    final joywayDefaults = joywayDefaultExtendedSettings(rssiAt1m: defaultRssi);

    _nameCtrl = TextEditingController(text: widget.pointName.trim());
    _newPasswordCtrl = TextEditingController(
      text: widget.initialNewBeaconPassword?.trim() ?? '',
    );
    _uuidCtrl = TextEditingController(text: widget.targetUuid.trim());
    _majorCtrl = TextEditingController(text: '${widget.targetMajor}');
    _minorCtrl = TextEditingController(text: '${widget.targetMinor}');
    _rssiAt1mCtrl = TextEditingController(text: '$defaultRssi');
    _adv1IntervalCtrl =
        TextEditingController(text: '${joywayDefaults.adv1IntervalMs}');
    _adv1TimeLenCtrl =
        TextEditingController(text: '${joywayDefaults.adv1TimeLenMs}');
    _adv2IntervalCtrl =
        TextEditingController(text: '${joywayDefaults.adv2IntervalMs}');
    _adv2TimeLenCtrl =
        TextEditingController(text: '${joywayDefaults.adv2TimeLenMs}');
    _buttonDelayCtrl =
        TextEditingController(text: '${joywayDefaults.buttonDelayMs}');
    _txPowerCtrl = TextEditingController(text: '$defaultRssi');
    _adv1NeverStop = joywayDefaults.adv1NeverStop;
    _adv2NeverStop = joywayDefaults.adv2NeverStop;
    _advertiseButtonEvent = joywayDefaults.advertiseButtonEvent;
    _txPowerDbm = joywayDefaults.txPowerDbm;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _newPasswordCtrl.dispose();
    _uuidCtrl.dispose();
    _majorCtrl.dispose();
    _minorCtrl.dispose();
    _rssiAt1mCtrl.dispose();
    _adv1IntervalCtrl.dispose();
    _adv1TimeLenCtrl.dispose();
    _adv2IntervalCtrl.dispose();
    _adv2TimeLenCtrl.dispose();
    _buttonDelayCtrl.dispose();
    _txPowerCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: PatrolShellColors.accent),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
    );
  }

  bool get _supportsNewBeaconPassword => _isJoyway;

  int? _parseAdvIntervalMs(String raw) {
    final value = int.tryParse(raw.trim());
    if (value == null || value < 100 || value > 10000) return null;
    return value;
  }

  int? _parseAdvTimeLenMs(String raw) {
    final value = int.tryParse(raw.trim());
    if (value == null || value < 0) return null;
    return value;
  }

  int? _parseButtonDelayMs(String raw) {
    final value = int.tryParse(raw.trim());
    if (value == null || value < 0 || value > 25500) return null;
    return value;
  }

  JoywayBeaconExtendedSettings? _buildJoywayExtended() {
    if (!_isJoyway) return null;
    return JoywayBeaconExtendedSettings(
      rssiAt1m: int.parse(_rssiAt1mCtrl.text.trim()),
      txPowerDbm: _txPowerDbm,
      adv1IntervalMs: int.parse(_adv1IntervalCtrl.text.trim()),
      adv1TimeLenMs: int.parse(_adv1TimeLenCtrl.text.trim()),
      adv1NeverStop: _adv1NeverStop,
      adv2IntervalMs: int.parse(_adv2IntervalCtrl.text.trim()),
      adv2TimeLenMs: int.parse(_adv2TimeLenCtrl.text.trim()),
      adv2NeverStop: _adv2NeverStop,
      buttonDelayMs: int.parse(_buttonDelayCtrl.text.trim()),
      advertiseButtonEvent: _advertiseButtonEvent,
    );
  }

  String _resolvedAdvertisingName() {
    final raw = _nameCtrl.text.trim();
    if (raw.isEmpty) return '';
    return switch (widget.protocol) {
      BeaconConfigureProtocol.joyway => joywayClipDeviceNameToField(raw),
      BeaconConfigureProtocol.hm10Ffe0 => beaconLatinBroadcastName(
          raw,
          maxLen: kHm10BroadcastNameMaxLen,
        ),
      _ => raw,
    };
  }

  String? _validateDeviceName(String? value, AppLocalizations l10n) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final maxLen = _isJoyway
        ? kJoywayBroadcastNameMaxLen
        : widget.protocol == BeaconConfigureProtocol.hm10Ffe0
            ? kHm10BroadcastNameMaxLen
            : 32;
    final latin = beaconTextToLatin(trimmed);
    if (latin.isNotEmpty && latin.length > maxLen) {
      return l10n.patrolPointBeaconSettingsNameTooLong;
    }
    return null;
  }

  Future<void> _onUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;

    final rssiOrTx = _isJoyway
        ? int.parse(_rssiAt1mCtrl.text.trim())
        : int.parse(_txPowerCtrl.text.trim());

    Navigator.pop(
      context,
      PatrolBeaconConfigureFormResult(
        name: _resolvedAdvertisingName(),
        newBeaconPassword: _newPasswordCtrl.text.trim(),
        uuid: _uuidCtrl.text.trim(),
        major: int.parse(_majorCtrl.text.trim()),
        minor: int.parse(_minorCtrl.text.trim()),
        txPowerAt1m: rssiOrTx,
        joywayExtended: _buildJoywayExtended(),
      ),
    );
  }

  Widget _sectionTitle(ThemeData mat, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        title,
        style: mat.textTheme.labelMedium?.copyWith(
          color: PatrolShellColors.accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _joywayAdvFields(AppLocalizations l10n, ThemeData mat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(mat, l10n.patrolPointBeaconSettingsAdv1Section),
        TextFormField(
          controller: _adv1IntervalCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white),
          decoration: _fieldDecoration(
            l10n.patrolPointBeaconSettingsAdv1IntervalLabel,
          ),
          validator: (value) {
            if (_parseAdvIntervalMs(value ?? '') == null) {
              return l10n.patrolPointBeaconSettingsInvalidAdvInterval;
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _adv1TimeLenCtrl,
          enabled: !_adv1NeverStop,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white),
          decoration: _fieldDecoration(
            l10n.patrolPointBeaconSettingsAdv1TimeLenLabel,
          ),
          validator: (value) {
            if (_adv1NeverStop) return null;
            if (_parseAdvTimeLenMs(value ?? '') == null) {
              return l10n.patrolPointBeaconSettingsInvalidAdvTimeLen;
            }
            return null;
          },
        ),
        CheckboxListTile(
          value: _adv1NeverStop,
          onChanged: (v) => setState(() => _adv1NeverStop = v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            l10n.patrolPointBeaconSettingsAdv1NeverStop,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
          activeColor: PatrolShellColors.accent,
        ),
        _sectionTitle(mat, l10n.patrolPointBeaconSettingsAdv2Section),
        TextFormField(
          controller: _adv2IntervalCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white),
          decoration: _fieldDecoration(
            l10n.patrolPointBeaconSettingsAdv2IntervalLabel,
          ),
          validator: (value) {
            if (_parseAdvIntervalMs(value ?? '') == null) {
              return l10n.patrolPointBeaconSettingsInvalidAdvInterval;
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _adv2TimeLenCtrl,
          enabled: !_adv2NeverStop,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white),
          decoration: _fieldDecoration(
            l10n.patrolPointBeaconSettingsAdv2TimeLenLabel,
          ),
          validator: (value) {
            if (_adv2NeverStop) return null;
            if (_parseAdvTimeLenMs(value ?? '') == null) {
              return l10n.patrolPointBeaconSettingsInvalidAdvTimeLen;
            }
            return null;
          },
        ),
        CheckboxListTile(
          value: _adv2NeverStop,
          onChanged: (v) => setState(() => _adv2NeverStop = v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            l10n.patrolPointBeaconSettingsAdv2NeverStop,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
          activeColor: PatrolShellColors.accent,
        ),
        _sectionTitle(mat, l10n.patrolPointBeaconSettingsButtonSection),
        TextFormField(
          controller: _buttonDelayCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white),
          decoration: _fieldDecoration(
            l10n.patrolPointBeaconSettingsButtonDelayLabel,
          ),
          validator: (value) {
            if (_parseButtonDelayMs(value ?? '') == null) {
              return l10n.patrolPointBeaconSettingsInvalidButtonDelay;
            }
            return null;
          },
        ),
        CheckboxListTile(
          value: _advertiseButtonEvent,
          onChanged: (v) => setState(() => _advertiseButtonEvent = v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            l10n.patrolPointBeaconSettingsAdvertiseButtonEvent,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
          activeColor: PatrolShellColors.accent,
        ),
      ],
    );
  }
  int? _parseUint16(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final value = int.tryParse(trimmed);
    if (value == null || value < 0 || value > 0xFFFF) return null;
    return value;
  }

  int? _parseRssiAt1m(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final value = int.tryParse(trimmed);
    if (value == null || value < -100 || value > 0) return null;
    return value;
  }

  int? _parseTxPowerAt1m(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final value = int.tryParse(trimmed);
    if (value == null || value < -128 || value > 127) return null;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mat = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final navBarInset =
        widget.bottomSafeInset > 0 ? widget.bottomSafeInset : 24.0;
    final maxH = MediaQuery.sizeOf(context).height * 0.9;
    final passwordMaxLen = _isJoyway ? 12 : 32;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.patrolPointBeaconSettingsTitle,
                        style: mat.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.patrolPointBeaconSettingsHint,
                        style: mat.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.65),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (widget.device.uuid != null &&
                          widget.device.uuid!.trim().isNotEmpty)
                        _settingsSection(
                          mat,
                          l10n.patrolPointBeaconSettingsCurrentSection,
                          [
                            _settingsRow(
                              mat,
                              'UUID',
                              widget.device.uuid!.trim(),
                              monospace: true,
                            ),
                            if (widget.device.major != null ||
                                widget.device.minor != null)
                              _settingsRow(
                                mat,
                                'Major / Minor',
                                '${widget.device.major ?? '—'} / '
                                '${widget.device.minor ?? '—'}',
                              ),
                            if (widget.device.txPowerAt1m != null)
                              _settingsRow(
                                mat,
                                l10n.patrolPointBeaconSettingsRssiAt1mLabel,
                                '${widget.device.txPowerAt1m} dBm',
                              ),
                          ],
                        ),
                      _sectionTitle(
                        mat,
                        l10n.patrolPointBeaconSettingsTargetSection,
                      ),
                      TextFormField(
                        controller: _nameCtrl,
                        autocorrect: false,
                        style: const TextStyle(color: Colors.white),
                        decoration: _fieldDecoration(
                          l10n.patrolPointBeaconSettingsDeviceName,
                          hint: _isJoyway
                              ? l10n.patrolPointBeaconSettingsNameHintJoyway
                              : l10n.patrolPointBeaconSettingsNameHint,
                        ),
                        validator: (value) => _validateDeviceName(value, l10n),
                      ),
                      const SizedBox(height: 12),
                      if (_supportsNewBeaconPassword) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 148,
                              child: TextFormField(
                                controller: _newPasswordCtrl,
                                readOnly: widget.lockNewBeaconPassword,
                                obscureText: !_showNewPassword,
                                maxLength: passwordMaxLen,
                                keyboardType: TextInputType.text,
                                autocorrect: false,
                                style: const TextStyle(color: Colors.white),
                                decoration: _fieldDecoration(
                                  l10n
                                      .patrolPointBeaconSettingsNewPasswordLabel,
                                  hint: l10n
                                      .patrolPointBeaconSettingsNewPasswordHint,
                                ).copyWith(counterText: ''),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Checkbox(
                              value: _showNewPassword,
                              onChanged: (v) => setState(
                                () => _showNewPassword = v ?? false,
                              ),
                              activeColor: PatrolShellColors.accent,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => _showNewPassword = !_showNewPassword,
                                ),
                                child: Text(
                                  l10n.patrolPointBeaconSettingsShowPassword,
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.85),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _uuidCtrl,
                        autocorrect: false,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        decoration:
                            _fieldDecoration(l10n.patrolPointBeaconUuidLabel),
                        validator: (value) {
                          final raw = value?.trim() ?? '';
                          if (!isBluetoothUuidIdentifier(raw)) {
                            return l10n.patrolPointBeaconSettingsInvalidUuid;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _majorCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: const TextStyle(color: Colors.white),
                              decoration: _fieldDecoration(
                                l10n.patrolPointBeaconSettingsMajorLabel,
                              ),
                              validator: (value) {
                                if (_parseUint16(value ?? '') == null) {
                                  return l10n
                                      .patrolPointBeaconSettingsInvalidMajor;
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _minorCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: const TextStyle(color: Colors.white),
                              decoration: _fieldDecoration(
                                l10n.patrolPointBeaconSettingsMinorLabel,
                              ),
                              validator: (value) {
                                if (_parseUint16(value ?? '') == null) {
                                  return l10n
                                      .patrolPointBeaconSettingsInvalidMinor;
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isJoyway) ...[
                        TextFormField(
                          controller: _rssiAt1mCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^-?\d*'),
                            ),
                          ],
                          style: const TextStyle(color: Colors.white),
                          decoration: _fieldDecoration(
                            l10n.patrolPointBeaconSettingsRssiAt1mLabel,
                            hint: l10n.patrolPointBeaconSettingsRssiAt1mHint,
                          ),
                          validator: (value) {
                            if (_parseRssiAt1m(value ?? '') == null) {
                              return l10n
                                  .patrolPointBeaconSettingsInvalidRssiAt1m;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _txPowerDbm,
                          dropdownColor: PatrolShellColors.surfaceElevated,
                          style: const TextStyle(color: Colors.white),
                          decoration: _fieldDecoration(
                            l10n.patrolPointBeaconSettingsTxPowerDbmLabel,
                          ),
                          items: [
                            for (final v in kJoywayTxPowerDbmValues)
                              DropdownMenuItem(
                                value: v,
                                child: Text('$v dBm'),
                              ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _txPowerDbm = v);
                          },
                        ),
                        _joywayAdvFields(l10n, mat),
                      ] else
                        TextFormField(
                          controller: _txPowerCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^-?\d*'),
                            ),
                          ],
                          style: const TextStyle(color: Colors.white),
                          decoration: _fieldDecoration(
                            l10n.patrolPointBeaconSettingsTxPowerLabel,
                            hint: l10n.patrolPointBeaconSettingsTxPowerHint,
                          ),
                          validator: (value) {
                            if (_parseTxPowerAt1m(value ?? '') == null) {
                              return l10n
                                  .patrolPointBeaconSettingsInvalidTxPower;
                            }
                            return null;
                          },
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + navBarInset),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Colors.white.withValues(alpha: 0.85),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(l10n.patrolRoundCancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _onUpdate,
                        child: Text(l10n.patrolPointBeaconSettingsUpdate),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsSection(
    ThemeData mat,
    String title,
    List<Widget> rows,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: mat.textTheme.labelMedium?.copyWith(
              color: PatrolShellColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _settingsRow(
    ThemeData mat,
    String label,
    String value, {
    bool monospace = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: mat.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: mat.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
                fontFamily: monospace ? 'monospace' : null,
                fontSize: monospace ? 11 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
