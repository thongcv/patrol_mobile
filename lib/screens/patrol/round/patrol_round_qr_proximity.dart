part of '../patrol_round_screen.dart';

class _QrScanProximityStatus {
  const _QrScanProximityStatus({
    required this.headline,
    this.snapshot,
    this.baroPending = false,
  });

  final String headline;
  final CheckPointProximitySnapshot? snapshot;
  final bool baroPending;
}

_QrScanProximityStatus _qrScanProximityStatus({
  required AppLocalizations l10n,
  required CheckPointProximityResult proximity,
  CheckPointProximitySnapshot? snapshot,
}) {
  if (snapshot == null) {
    return _QrScanProximityStatus(
      headline: l10n.patrolRoundQrWaitingPosition,
    );
  }

  final nav = CheckPointProximityNavigationHints.fromSnapshot(snapshot);
  final radius = snapshot.allowedRadiusM.toStringAsFixed(0);

  switch (proximity.issue) {
    case CheckPointProximityIssue.baroAltitudePending:
      return _QrScanProximityStatus(
        headline: l10n.patrolRoundQrWaitingBaro,
        snapshot: snapshot,
        baroPending: true,
      );
    case CheckPointProximityIssue.baroAltitudeOutOfRange:
    case CheckPointProximityIssue.gpsAltitudeOutOfRange:
      final dist = nav.altitudeAbsDeltaM != null
          ? formatPatrolDistanceM(nav.altitudeAbsDeltaM!)
          : proximity.distanceM != null
              ? formatPatrolDistanceM(proximity.distanceM!)
              : '—';
      return _QrScanProximityStatus(
        headline: l10n.patrolRoundQrAltitudeOutOfRange(dist, radius),
        snapshot: snapshot,
      );
    case CheckPointProximityIssue.horizontalOutOfRange:
      final dist = formatPatrolDistanceM(nav.horizontalDistanceM);
      return _QrScanProximityStatus(
        headline: l10n.patrolRoundQrOutOfRange(dist, radius),
        snapshot: snapshot,
      );
    case CheckPointProximityIssue.noCheckpointCoordinates:
    case null:
      return _QrScanProximityStatus(
        headline: l10n.patrolRoundQrWaitingPosition,
        snapshot: snapshot,
      );
  }
}

String _qrFmtCoord(double value) => value.toStringAsFixed(6);

String _qrL10nMoveDirection(
  AppLocalizations l10n,
  CheckPointMoveDirection direction,
) {
  return switch (direction) {
    CheckPointMoveDirection.onTarget => l10n.patrolRoundQrMoveOnTarget,
    CheckPointMoveDirection.north => l10n.patrolRoundQrMoveNorth,
    CheckPointMoveDirection.south => l10n.patrolRoundQrMoveSouth,
    CheckPointMoveDirection.east => l10n.patrolRoundQrMoveEast,
    CheckPointMoveDirection.west => l10n.patrolRoundQrMoveWest,
    CheckPointMoveDirection.up => l10n.patrolRoundQrMoveUp,
    CheckPointMoveDirection.down => l10n.patrolRoundQrMoveDown,
  };
}

class _QrProximityDetailPanel extends StatelessWidget {
  const _QrProximityDetailPanel({
    required this.l10n,
    required this.snapshot,
    this.baroPending = false,
  });

  final AppLocalizations l10n;
  final CheckPointProximitySnapshot snapshot;
  final bool baroPending;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final nav = CheckPointProximityNavigationHints.fromSnapshot(s);
    final altKind =
        s.usesBaroAltitude ? l10n.patrolRoundQrAltKindBaro : l10n.patrolRoundQrAltKindGps;
    final radius = s.allowedRadiusM.toStringAsFixed(0);
    final muted = Colors.white.withValues(alpha: 0.72);
    final lineStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: muted,
          height: 1.45,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    String coordsLine({
      required bool checkpoint,
      required double lat,
      required double lng,
      required double? altitude,
    }) {
      final latStr = _qrFmtCoord(lat);
      final lngStr = _qrFmtCoord(lng);
      if (altitude != null && altitude.isFinite) {
        final altStr = altitude.toStringAsFixed(1);
        return checkpoint
            ? l10n.patrolRoundQrCheckpointCoordsWithAlt(
                latStr,
                lngStr,
                altStr,
                altKind,
              )
            : l10n.patrolRoundQrDeviceCoordsWithAlt(
                latStr,
                lngStr,
                altStr,
                altKind,
              );
      }
      if (!checkpoint && baroPending && s.usesBaroAltitude) {
        return l10n.patrolRoundQrDeviceCoordsWithAlt(
          latStr,
          lngStr,
          l10n.patrolRoundQrAltPending,
          altKind,
        );
      }
      return checkpoint
          ? l10n.patrolRoundQrCheckpointCoords(latStr, lngStr)
          : l10n.patrolRoundQrDeviceCoords(latStr, lngStr);
    }

    final lines = <String>[
      coordsLine(
        checkpoint: true,
        lat: s.checkpointLat,
        lng: s.checkpointLng,
        altitude: s.checkpointAltitude,
      ),
      coordsLine(
        checkpoint: false,
        lat: s.deviceLat,
        lng: s.deviceLng,
        altitude: s.deviceAltitude,
      ),
    ];

    if (nav.northMove != CheckPointMoveDirection.onTarget) {
      lines.add(
        l10n.patrolRoundQrDeltaNorth(
          formatPatrolDistanceM(nav.northAbsDeltaM),
          _qrL10nMoveDirection(l10n, nav.northMove),
        ),
      );
    }
    if (nav.eastMove != CheckPointMoveDirection.onTarget) {
      lines.add(
        l10n.patrolRoundQrDeltaEast(
          formatPatrolDistanceM(nav.eastAbsDeltaM),
          _qrL10nMoveDirection(l10n, nav.eastMove),
        ),
      );
    }
    if (nav.horizontalDistanceM >= kCheckPointOnTargetThresholdM) {
      lines.add(
        l10n.patrolRoundQrDeltaHorizontal(
          formatPatrolDistanceM(nav.horizontalDistanceM),
          radius,
        ),
      );
    }

    final altDeltaM = nav.altitudeAbsDeltaM;
    final altMove = nav.altitudeMove;
    if (altMove != null &&
        altMove != CheckPointMoveDirection.onTarget &&
        altDeltaM != null &&
        altDeltaM >= kCheckPointOnTargetThresholdM) {
      lines.add(
        '${l10n.patrolRoundQrDeltaAltitude(formatPatrolDistanceM(altDeltaM), radius)} · ${_qrL10nMoveDirection(l10n, altMove)}',
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line, style: lineStyle),
            ),
        ],
      ),
    );
  }
}

