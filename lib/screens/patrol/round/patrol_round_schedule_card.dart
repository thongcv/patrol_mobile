part of '../patrol_round_screen.dart';

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.theme,
    required this.l10n,
    required this.loading,
    required this.data,
    this.failure,
    this.failureMessage,
  });

  final TextTheme theme;
  final AppLocalizations l10n;
  final bool loading;
  final ActivePatrolRound? data;
  final ApiFailure? failure;
  final String? failureMessage;

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
        ? formatShiftWindow(schedule.startTime, schedule.endTime)
        : null;
    final effective = schedule != null
        ? formatEffectiveDateRange(
            schedule.startEffectiveDate,
            schedule.endEffectiveDate,
          )
        : null;
    final freq = schedule?.frequencyMinutes;
    final roundMin = schedule?.roundMinutes;
    final scheduleShowsName =
        schedule != null && schedule.name.trim().isNotEmpty;

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
                  scheduleShowsName
                      ? schedule.name
                      : l10n.patrolRoundScheduleHeading,
                  style: scheduleShowsName
                      ? theme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        )
                      : theme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                ),
              ),
              if (schedule != null)
                _StatusChip(
                  label: schedule.active
                      ? l10n.patrolRoundScheduleActive
                      : l10n.patrolRoundScheduleInactive,
                  color: schedule.active
                      ? const Color(0xFF34D399)
                      : Colors.white54,
                  filled: schedule.active,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            Text(
              l10n.patrolRoundLoading,
              style: theme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            )
          else if (failure != null)
            Text(
              failureMessage ?? l10n.patrolRoundLoadFailed,
              style: theme.bodyMedium?.copyWith(
                color: Colors.orangeAccent.withValues(alpha: 0.9),
                height: 1.4,
              ),
            )
          else if (data == null)
            Text(
              l10n.patrolRoundEmpty,
              style: theme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
                height: 1.5,
              ),
            )
          else ...[
            _InfoRow(
              theme: theme,
              icon: Icons.schedule_rounded,
              label: l10n.patrolRoundShiftWindow,
              value: window!,
            ),
            if (effective!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(
                theme: theme,
                icon: Icons.date_range_rounded,
                label: l10n.patrolRoundEffective,
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
                        label: l10n.patrolRoundFrequency,
                        value: l10n.patrolRoundMinutes(freq),
                      ),
                    ),
                  if (freq != null && roundMin != null)
                    const SizedBox(width: 10),
                  if (roundMin != null)
                    Expanded(
                      child: _MiniStat(
                        theme: theme,
                        icon: Icons.timelapse_rounded,
                        label: l10n.patrolRoundDuration,
                        value: l10n.patrolRoundMinutes(roundMin),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            _InfoRow(
              theme: theme,
              icon: Icons.place_outlined,
              label: l10n.patrolRoundSiteId,
              value: data!.schedule.siteName ?? '',
            ),
            if (data!.schedule.siteAddress != null &&
                data!.schedule.siteAddress!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(
                theme: theme,
                icon: Icons.location_on_outlined,
                label: l10n.patrolPointSiteAddressLabel,
                value: data!.schedule.siteAddress!.trim(),
              ),
            ],
            if (data!.schedule.totalCheckPoints != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                theme: theme,
                icon: Icons.flag_outlined,
                label: l10n.patrolRoundScheduleTotalCheckPoints,
                value: '${data!.schedule.totalCheckPoints}',
              ),
            ],
            const SizedBox(height: 14),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            const SizedBox(height: 12),
            Text(
              l10n.patrolRoundCountSummary(n),
              style: theme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (n > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${l10n.patrolRoundWithGpsSummary(withGps)} · '
                '${l10n.patrolRoundWithQrSummary(withQr)}',
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

