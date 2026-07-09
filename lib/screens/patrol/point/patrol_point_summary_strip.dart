part of '../patrol_point_screen.dart';

String _shortBeaconUuid(String uuid) {
  final s = uuid.trim();
  if (s.length <= 18) return s;
  return '${s.substring(0, 8)}…${s.substring(s.length - 4)}';
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.theme,
    required this.loading,
    this.siteId,
    this.beaconUuid,
    this.siteName,
    this.siteAddress,
    required this.points,
    required this.failure,
    required this.onReload,
    required this.l10n,
  });

  final TextTheme theme;
  final bool loading;
  final int? siteId;
  final String? beaconUuid;
  final String? siteName;
  final String? siteAddress;
  final List<CheckPoint>? points;
  final ApiFailure? failure;
  final VoidCallback onReload;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final n = points?.length ?? 0;
    final missing = points == null
        ? 0
        : points!.where((p) => !p.hasCoordinates).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PatrolShellColors.surfaceElevated.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: loading
                ? Text(
                    l10n.patrolPointListLoading,
                    style: theme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  )
                : failure != null
                ? Text(
                    failure!.userMessage(
                      configMissing: l10n.toastApiNotConfigured,
                      network: l10n.toastNetworkErrorShort,
                      unauthorized: l10n.patrolPointUnauthorized,
                      badResponse: l10n.patrolPointLoadFailed,
                      server: l10n.patrolPointLoadFailed,
                    ),
                    style: theme.bodySmall?.copyWith(
                      color: Colors.orangeAccent.withValues(alpha: 0.9),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (siteName != null && siteName!.trim().isNotEmpty) ...[
                        Text(
                          siteName!.trim(),
                          style: theme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (siteAddress != null &&
                          siteAddress!.trim().isNotEmpty) ...[
                        Text(
                          '${l10n.patrolPointSiteAddressLabel}: ${siteAddress!.trim()}',
                          style: theme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.55),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (siteId != null && siteId! > 0) ...[
                        Text(
                          '${l10n.patrolPointSiteIdLabel}: $siteId',
                          style: theme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.55),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (beaconUuid != null &&
                          beaconUuid!.trim().isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '${l10n.patrolPointBeaconUuidLabel}: ',
                              style: theme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.55),
                                height: 1.35,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _shortBeaconUuid(beaconUuid!),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  height: 1.35,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              tooltip: l10n.patrolPointCopyUuidTooltip,
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: beaconUuid!.trim()),
                                );
                              },
                              icon: Icon(
                                Icons.copy_rounded,
                                size: 18,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        l10n.patrolPointCountSummary(n),
                        style: theme.labelLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (n > 0 && missing > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          l10n.patrolPointMissingCoordsSummary(missing),
                          style: theme.bodySmall?.copyWith(
                            color: PatrolShellColors.accentMuted.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          IconButton.filledTonal(
            onPressed: loading ? null : onReload,
            style: IconButton.styleFrom(
              backgroundColor: PatrolShellColors.accent.withValues(alpha: 0.18),
              foregroundColor: PatrolShellColors.accent,
            ),
            tooltip: l10n.patrolPointReload,
            icon: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PatrolShellColors.accent,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

