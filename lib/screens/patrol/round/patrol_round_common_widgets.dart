part of '../patrol_round_screen.dart';

bool _isRoundActive(String status) {
  final normalized = status.toUpperCase();
  return normalized == 'PENDING' ||
      normalized == 'IN_PROGRESS' ||
      normalized == 'INPROGRESS' ||
      normalized == 'ACTIVE';
}

String _statusLabel(String status, AppLocalizations l10n) {
  switch (status.toUpperCase()) {
    case 'PENDING':
      return l10n.patrolRoundStatusPending;
    case 'IN_PROGRESS':
      return l10n.patrolRoundStatusInProgress;
    case 'COMPLETED':
      return l10n.patrolRoundStatusCompleted;
    case 'CANCELED':
      return l10n.patrolRoundStatusCancelled;
    default:
      return status.isEmpty ? l10n.patrolRoundStatusOther : status;
  }
}

Color _statusColor(String status) {
  switch (status.toUpperCase()) {
    case 'PENDING':
      return const Color(0xFFFBBF24);
    case 'IN_PROGRESS':
    case 'INPROGRESS':
      return const Color(0xFF34D399);
    case 'COMPLETED':
    case 'DONE':
      return PatrolShellColors.accent;
    case 'CANCELLED':
    case 'CANCELED':
      return Colors.white54;
    default:
      return Colors.white70;
  }
}

bool _isRoundOngoing(PatrolRound round) =>
    _isRoundActive(round.status) || _isRoundActive(round.detailStatus);

bool _isRoundNotCompleted(PatrolRound round) {
  switch (round.status.trim().toUpperCase()) {
    case 'COMPLETED':
    case 'DONE':
      return false;
    default:
      return true;
  }
}

DateTime? _roundExpectedEndDeadline(ActivePatrolRound data) {
  final direct = parsePatrolApiInstant(data.round.expectedEndTime);
  if (direct != null) return direct;

  final start = parsePatrolApiInstant(data.round.expectedStartTime);
  final roundMin = data.schedule.roundMinutes;
  if (start != null && roundMin != null && roundMin > 0) {
    return start.add(Duration(minutes: roundMin));
  }
  return null;
}

bool _isRoundOverdue(ActivePatrolRound data) {
  final end = _roundExpectedEndDeadline(data);
  if (end == null) return false;
  return DateTime.now().isAfter(end);
}

String _messageForFailure(ApiFailure f, AppLocalizations l10n) {
  return f.userMessage(
    configMissing: l10n.toastApiNotConfigured,
    network: l10n.toastNetworkErrorShort,
    unauthorized: l10n.patrolRoundUnauthorized,
    badResponse: l10n.patrolRoundLoadFailed,
    server: l10n.patrolRoundLoadFailed,
  );
}

String _messageForScanFailure(ApiFailure f, AppLocalizations l10n) {
  return f.userMessage(
    configMissing: l10n.toastApiNotConfigured,
    network: l10n.toastNetworkErrorShort,
    unauthorized: l10n.patrolRoundUnauthorized,
    badResponse: l10n.patrolRoundQrScanFailed,
    server: l10n.patrolRoundQrScanFailed,
  );
}

String _gpsMessageFromKey(String? key, AppLocalizations l10n) {
  return switch (key) {
    'service' => l10n.patrolPointGpsServiceOff,
    'denied' => l10n.patrolPointGpsDenied,
    'error' => l10n.patrolPointGpsError,
    'unavailable' => l10n.patrolRoundQrGpsUnavailable,
    _ => l10n.patrolRoundQrGpsUnavailable,
  };
}

String _nfcScanFailureMessage(AppLocalizations l10n, NfcReadFailure failure) {
  return switch (failure) {
    NfcReadFailure.disabled => l10n.patrolPointNfcDisabled,
    NfcReadFailure.timeout => l10n.patrolPointNfcScanTimeout,
    NfcReadFailure.unavailable => l10n.patrolPointNfcUnavailable,
    NfcReadFailure.noIdentifier || NfcReadFailure.failed =>
      l10n.patrolPointNfcScanFailed,
  };
}

String _bluetoothScanFailureMessage(
  AppLocalizations l10n,
  BluetoothReadFailure failure,
) {
  return switch (failure) {
    BluetoothReadFailure.disabled => l10n.patrolPointBluetoothDisabled,
    BluetoothReadFailure.permissionDenied =>
      l10n.patrolPointBluetoothPermissionDenied,
    BluetoothReadFailure.timeout => l10n.patrolPointBluetoothScanTimeout,
    BluetoothReadFailure.unavailable => l10n.patrolPointBluetoothUnavailable,
    BluetoothReadFailure.failed => l10n.patrolRoundBluetoothScanFailed,
  };
}

/// Normalizes QR payload and matches `CheckPoint.qrCode` on the current route.
CheckPoint? _findCheckPointByQrCode(List<CheckPoint> points, String raw) {
  final payload = raw.trim();
  if (payload.isEmpty) return null;
  for (final p in points) {
    if (p.qrCode?.trim() == payload) return p;
  }
  return null;
}

CheckPoint? _findCheckPointByNfc(List<CheckPoint> points, String raw) {
  final payload = raw.trim();
  if (payload.isEmpty) return null;
  for (final p in points) {
    if (p.nfc?.trim() == payload && p.verified != true) return p;
  }
  return null;
}

bool _bluetoothCheckPointBeaconFieldsMatch(
  CheckPoint point, {
  String? scannedUuid,
  int? major,
  int? minor,
  int? rssi,
  required double rssiTolerance,
}) {
  final scanned = scannedUuid?.trim();
  final pUuid = point.uuid?.trim();
  if (scanned == null ||
      scanned.isEmpty ||
      pUuid == null ||
      pUuid.isEmpty ||
      !bluetoothIdentifiersMatch(pUuid, scanned)) {
    return false;
  }

  final targetMajor = point.major;
  if (targetMajor != null && major != targetMajor) return false;

  final targetMinor = point.minor;
  if (targetMinor != null && minor != targetMinor) return false;

  final targetRssi = point.rssi;
  if (targetRssi != null) {
    if (rssi == null) return false;
    if ((rssi - targetRssi).abs() > rssiTolerance) return false;
  }

  return true;
}

CheckPoint? _matchBluetoothCheckPoint(
  List<CheckPoint> candidates, {
  String? uuid,
  int? major,
  int? minor,
  int? rssi,
  required double rssiTolerance,
}) {
  for (final p in candidates) {
    if (_bluetoothCheckPointBeaconFieldsMatch(
      p,
      scannedUuid: uuid,
      major: major,
      minor: minor,
      rssi: rssi,
      rssiTolerance: rssiTolerance,
    )) {
      return p;
    }
  }
  return null;
}

DeviceLocationSample _fallbackLocationSampleForCheckpoint(CheckPoint point) {
  final lat = point.latitude!;
  final lng = point.longitude!;
  return (
    position: Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: double.maxFinite,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    ),
    latitude: lat,
    longitude: lng,
    gpsAltitude: null,
    baroAltitude: null,
  );
}

class _PatrolPanel extends StatelessWidget {
  const _PatrolPanel({
    required this.child,
    this.accent,
  });

  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent ?? PatrolShellColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Square scan button: icon and label in one tile (like QR/NFC).
class _PatrolScanActionTile extends StatelessWidget {
  const _PatrolScanActionTile({
    required this.onTap,
    required this.busy,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onTap;
  final bool busy;
  final IconData icon;
  final String label;

  static const Color _accent = Color(0xFF34D399);

  @override
  Widget build(BuildContext context) {
    final color = busy ? _accent.withValues(alpha: 0.45) : _accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: kPatrolQrPreviewSize,
          height: kPatrolQrPreviewSize,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _accent.withValues(alpha: 0.45)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                busy ? Icons.hourglass_top_rounded : icon,
                size: 26,
                color: color,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.theme,
    required this.icon,
    required this.label,
    required this.value,
  });

  final TextTheme theme;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.45)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.theme,
    required this.icon,
    required this.label,
    required this.value,
  });

  final TextTheme theme;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF6EE7B7)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.theme,
    required this.label,
    required this.icon,
    required this.color,
  });

  final TextTheme theme;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

