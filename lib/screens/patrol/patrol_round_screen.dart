import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../http/api_failure.dart';
import '../../l10n/auth_strings.dart';
import '../../models/active_patrol_round.dart';
import '../../models/check_point.dart';
import '../../services/patrol_round_service.dart';
import '../../utils/api_media_url.dart';
import 'patrol_shell.dart';

/// Tuần tra — `link`: `patrol-round`.
/// GET `/api/patrol-rounds/me/active`.
class PatrolRoundScreen extends StatefulWidget {
  const PatrolRoundScreen({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
    this.embedded = false,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  /// `true` khi hiển thị trong tab Trang chủ (không push route mới).
  final bool embedded;

  @override
  State<PatrolRoundScreen> createState() => _PatrolRoundScreenState();
}

class _PatrolRoundScreenState extends State<PatrolRoundScreen> {
  ActivePatrolRoundDto? _active;
  bool _loading = true;
  ApiFailure? _failure;

  AuthStrings get s => AuthStrings(widget.locale);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });

    final r = await PatrolRoundService.instance.fetchMyActivePatrolRound();

    if (!mounted) return;
    if (r.ok) {
      setState(() {
        _active = r.data;
        _loading = false;
        _failure = null;
      });
    } else {
      setState(() {
        _active = null;
        _loading = false;
        _failure = r.failure;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageForFailure(r.failure!))),
      );
    }
  }

  String _messageForFailure(ApiFailure f) {
    return f.userMessage(
      configMissing: s.toastApiNotConfigured,
      network: s.toastNetworkErrorShort,
      unauthorized: s.patrolRoundUnauthorized,
      badResponse: s.patrolRoundLoadFailed,
      server: s.patrolRoundLoadFailed,
    );
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return s.patrolRoundStatusPending;
      case 'IN_PROGRESS':
      case 'INPROGRESS':
        return s.patrolRoundStatusInProgress;
      case 'COMPLETED':
      case 'DONE':
        return s.patrolRoundStatusCompleted;
      case 'CANCELLED':
      case 'CANCELED':
        return s.patrolRoundStatusCancelled;
      default:
        return status.isEmpty ? s.patrolRoundStatusOther : status;
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

  @override
  Widget build(BuildContext context) {
    final theme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);
    final data = _active;

    final subtitle = _loading
        ? s.patrolRoundLoading
        : data == null
            ? s.patrolRoundSubtitle
            : s.patrolRoundSubtitleActive(
                data.schedule.name,
                _statusLabel(data.round.status),
              );

    return PatrolFeatureScaffold(
      useOuterScaffold: !widget.embedded,
      locale: widget.locale,
      title: widget.embedded ? null : s.patrolRoundTitle,
      heroIcon: Icons.shield_moon_rounded,
      heroColor: const Color(0xFF34D399),
      subtitle: data == null ? s.patrolRoundSubtitle : null,
      subtitleSlot: data != null || _loading
          ? Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
                letterSpacing: 0.3,
                height: 1.2,
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScheduleCard(
            theme: theme,
            strings: s,
            loading: _loading,
            failure: _failure,
            data: data,
            onReload: _load,
            failureMessage:
                _failure != null ? _messageForFailure(_failure!) : null,
          ),
          if (!_loading && _failure == null && data != null) ...[
            const SizedBox(height: 12),
            _RoundCard(
              theme: theme,
              strings: s,
              round: data.round,
              statusLabel: _statusLabel(data.round.status),
              statusColor: _statusColor(data.round.status),
              locale: widget.locale,
            ),
            const SizedBox(height: 20),
            Text(
              s.patrolRoundRouteHeading,
              style: theme.titleSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (data.checkPoints.isEmpty)
              Text(
                s.patrolPointEmpty,
                style: theme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.65),
                  height: 1.5,
                ),
              )
            else
              ...data.checkPoints.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RoutePointCard(
                    theme: theme,
                    strings: s,
                    point: p,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.theme,
    required this.strings,
    required this.loading,
    required this.data,
    required this.onReload,
    this.failure,
    this.failureMessage,
  });

  final TextTheme theme;
  final AuthStrings strings;
  final bool loading;
  final ActivePatrolRoundDto? data;
  final ApiFailure? failure;
  final String? failureMessage;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final schedule = data?.schedule;
    final points = data?.checkPoints;
    final n = points?.length ?? 0;
    final withGps = points?.where((p) => p.hasCoordinates).length ?? 0;
    final withQr = points
            ?.where(
              (p) => p.qrImage != null && p.qrImage!.trim().isNotEmpty,
            )
            .length ??
        0;

    final window = schedule != null
        ? _formatShiftWindow(schedule.startTime, schedule.endTime)
        : null;
    final effective = schedule != null
        ? _formatEffectiveRange(
            schedule.startEffectiveDate,
            schedule.endEffectiveDate,
          )
        : null;
    final freq = schedule?.frequencyMinutes;
    final roundMin = schedule?.roundMinutes;

    return _PatrolPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 20,
                color: Color(0xFF6EE7B7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.patrolRoundScheduleHeading,
                  style: theme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (schedule != null)
                _StatusChip(
                  label: schedule.active
                      ? strings.patrolRoundScheduleActive
                      : strings.patrolRoundScheduleInactive,
                  color: schedule.active
                      ? const Color(0xFF34D399)
                      : Colors.white54,
                  filled: schedule.active,
                ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                onPressed: loading ? null : onReload,
                style: IconButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF34D399).withValues(alpha: 0.18),
                  foregroundColor: const Color(0xFF34D399),
                ),
                tooltip: strings.patrolRoundReload,
                icon: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF34D399),
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            Text(
              strings.patrolRoundLoading,
              style: theme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            )
          else if (failure != null)
            Text(
              failureMessage ?? strings.patrolRoundLoadFailed,
              style: theme.bodyMedium?.copyWith(
                color: Colors.orangeAccent.withValues(alpha: 0.9),
                height: 1.4,
              ),
            )
          else if (data == null)
            Text(
              strings.patrolRoundEmpty,
              style: theme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
                height: 1.5,
              ),
            )
          else ...[
            Text(
              schedule!.name,
              style: theme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _InfoRow(
              theme: theme,
              icon: Icons.schedule_rounded,
              label: strings.patrolRoundShiftWindow,
              value: window!,
            ),
            if (effective!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(
                theme: theme,
                icon: Icons.date_range_rounded,
                label: strings.patrolRoundEffective,
                value: effective,
              ),
            ],
            if (freq != null || roundMin != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (freq != null)
                    Expanded(
                      child: _MiniStat(
                        theme: theme,
                        icon: Icons.repeat_rounded,
                        label: strings.patrolRoundFrequency,
                        value: strings.patrolRoundMinutes
                            .replaceAll('{n}', '$freq'),
                      ),
                    ),
                  if (freq != null && roundMin != null)
                    const SizedBox(width: 10),
                  if (roundMin != null)
                    Expanded(
                      child: _MiniStat(
                        theme: theme,
                        icon: Icons.timelapse_rounded,
                        label: strings.patrolRoundDuration,
                        value: strings.patrolRoundMinutes
                            .replaceAll('{n}', '$roundMin'),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            _InfoRow(
              theme: theme,
              icon: Icons.place_outlined,
              label: strings.patrolRoundSiteId,
              value: '${schedule.siteId}',
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            const SizedBox(height: 12),
            Text(
              strings.patrolRoundCountSummary.replaceAll('{n}', '$n'),
              style: theme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (n > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${strings.patrolRoundWithGpsSummary.replaceAll('{n}', '$withGps')} · '
                '${strings.patrolRoundWithQrSummary.replaceAll('{n}', '$withQr')}',
                style: theme.bodySmall?.copyWith(
                  color: const Color(0xFF6EE7B7).withValues(alpha: 0.85),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _RoundCard extends StatelessWidget {
  const _RoundCard({
    required this.theme,
    required this.strings,
    required this.round,
    required this.statusLabel,
    required this.statusColor,
    required this.locale,
  });

  final TextTheme theme;
  final AuthStrings strings;
  final PatrolRoundDto round;
  final String statusLabel;
  final Color statusColor;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final assignee = round.assignedName?.trim();

    return _PatrolPanel(
      accent: statusColor.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.route_rounded,
                size: 20,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.patrolRoundRoundHeading,
                  style: theme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusChip(
                label: statusLabel,
                color: statusColor,
                filled: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '#${round.id}',
            style: theme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          _InfoRow(
            theme: theme,
            icon: Icons.play_circle_outline_rounded,
            label: strings.patrolRoundExpectedStart,
            value: _formatIsoDateTime(round.expectedStartTime, locale),
          ),
          const SizedBox(height: 8),
          _InfoRow(
            theme: theme,
            icon: Icons.stop_circle_outlined,
            label: strings.patrolRoundExpectedEnd,
            value: _formatIsoDateTime(round.expectedEndTime, locale),
          ),
          if (_isPatrolRoundOverdue(round)) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: strings.patrolRoundOverdue,
                  color: const Color(0xFFEF4444),
                  filled: true,
                ),
              ],
            ),
          ],
          if (assignee != null && assignee.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(
              theme: theme,
              icon: Icons.person_outline_rounded,
              label: strings.patrolRoundAssigned,
              value: assignee,
            ),
          ],
        ],
      ),
    );
  }
}

class _RoutePointCard extends StatelessWidget {
  const _RoutePointCard({
    required this.theme,
    required this.strings,
    required this.point,
  });

  final TextTheme theme;
  final AuthStrings strings;
  final CheckPointDto point;

  @override
  Widget build(BuildContext context) {
    final qrUrl = resolveApiMediaUrl(point.qrImage);
    final qrPreview = _checkPointQrPreview(qrUrl, size: 56);
    final hasNfc = point.nfc != null && point.nfc!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: PatrolShellColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  '${point.sequenceOrder}',
                  style: theme.titleSmall?.copyWith(
                    color: const Color(0xFF6EE7B7),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (qrPreview != null) ...[
                const SizedBox(width: 8),
                qrPreview,
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FeatureChip(
                theme: theme,
                label: point.hasCoordinates
                    ? strings.patrolRoundChipGps
                    : strings.patrolRoundChipNoGps,
                icon: point.hasCoordinates
                    ? Icons.gps_fixed_rounded
                    : Icons.gps_off_rounded,
                color: point.hasCoordinates
                    ? PatrolShellColors.accentMuted
                    : Colors.amberAccent.withValues(alpha: 0.9),
              ),
              if (qrUrl != null)
                _FeatureChip(
                  theme: theme,
                  label: strings.patrolRoundChipQr,
                  icon: Icons.qr_code_2_rounded,
                  color: const Color(0xFF6EE7B7),
                ),
              if (hasNfc)
                _FeatureChip(
                  theme: theme,
                  label: strings.patrolRoundChipNfc,
                  icon: Icons.nfc_rounded,
                  color: Colors.white70,
                ),
              if (!point.active)
                _FeatureChip(
                  theme: theme,
                  label: strings.patrolPointInactive,
                  icon: Icons.block_rounded,
                  color: Colors.white54,
                ),
            ],
          ),
        ],
      ),
    );
  }
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

String _formatShiftWindow(String? start, String? end) {
  final s = _trimTime(start);
  final e = _trimTime(end);
  if (s.isEmpty && e.isEmpty) return '—';
  if (s.isEmpty) return e;
  if (e.isEmpty) return s;
  return '$s – $e';
}

String _trimTime(String? raw) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return '';
  final parts = t.split(':');
  if (parts.length >= 2) {
    return '${parts[0]}:${parts[1]}';
  }
  return t;
}

String _formatEffectiveRange(String? start, String? end) {
  final s = _formatDateOnly(start);
  final e = _formatDateOnly(end);
  if (s.isEmpty && e.isEmpty) return '';
  if (s.isEmpty) return e;
  if (e.isEmpty) return s;
  return '$s – $e';
}

String _formatDateOnly(String? raw) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return '';
  final datePart = t.contains('T') ? t.split('T').first : t;
  final parts = datePart.split('-');
  if (parts.length == 3) {
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
  return datePart;
}

bool _isPatrolRoundOverdue(PatrolRoundDto round) {
  final endIso = round.expectedEndTime?.trim();
  if (endIso == null || endIso.isEmpty) return false;

  final status = round.status.toUpperCase();
  if (status == 'COMPLETED' ||
      status == 'DONE' ||
      status == 'CANCELLED' ||
      status == 'CANCELED') {
    return false;
  }

  try {
    return DateTime.now().isAfter(DateTime.parse(endIso).toLocal());
  } catch (_) {
    return false;
  }
}

String _formatIsoDateTime(String? iso, Locale locale) {
  final t = iso?.trim();
  if (t == null || t.isEmpty) return '—';
  try {
    final dt = DateTime.parse(t).toLocal();
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  } catch (_) {
    return t;
  }
}

Widget? _checkPointQrPreview(String? qrImage, {double size = 88}) {
  final raw = qrImage?.trim();
  if (raw == null || raw.isEmpty) return null;

  Widget framed(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return framed(
      Image.network(
        raw,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(
          Icons.broken_image_outlined,
          size: size * 0.35,
          color: Colors.black38,
        ),
      ),
    );
  }

  String? b64Payload;
  if (raw.startsWith('data:image')) {
    final comma = raw.indexOf(',');
    if (comma != -1) {
      b64Payload = raw.substring(comma + 1);
    }
  } else {
    b64Payload = raw;
  }

  if (b64Payload == null || b64Payload.isEmpty) return null;

  try {
    final bytes = base64Decode(b64Payload.replaceAll(RegExp(r'\s'), ''));
    return framed(
      Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  } catch (_) {
    return null;
  }
}
