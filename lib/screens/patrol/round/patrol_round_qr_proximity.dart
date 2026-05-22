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
      final dist = proximity.distanceM?.toStringAsFixed(0) ?? '—';
      return _QrScanProximityStatus(
        headline: l10n.patrolRoundQrAltitudeOutOfRange(dist, radius),
        snapshot: snapshot,
      );
    case CheckPointProximityIssue.horizontalOutOfRange:
      final dist = (snapshot.slantRangeM ?? snapshot.horizontalM)
          .toStringAsFixed(0);
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

String _qrFmtDeltaM(double signedM) => signedM.abs().toStringAsFixed(1);

String _qrFmtDistanceToCheckpointM(CheckPointProximitySnapshot s) {
  final slant = s.slantRangeM;
  final distanceM = (slant != null && slant.isFinite) ? slant : s.horizontalM;
  return distanceM.toStringAsFixed(1);
}

String _qrNorthMoveDirection(AppLocalizations l10n, double signedNorthM) {
  if (signedNorthM.abs() < 0.05) return l10n.patrolRoundQrMoveOnTarget;
  return signedNorthM > 0
      ? l10n.patrolRoundQrMoveNorth
      : l10n.patrolRoundQrMoveSouth;
}

String _qrEastMoveDirection(AppLocalizations l10n, double signedEastM) {
  if (signedEastM.abs() < 0.05) return l10n.patrolRoundQrMoveOnTarget;
  return signedEastM > 0
      ? l10n.patrolRoundQrMoveEast
      : l10n.patrolRoundQrMoveWest;
}

String _qrAltMoveDirection(AppLocalizations l10n, double signedAltDeltaM) {
  if (signedAltDeltaM.abs() < 0.05) return l10n.patrolRoundQrMoveOnTarget;
  return signedAltDeltaM > 0
      ? l10n.patrolRoundQrMoveDown
      : l10n.patrolRoundQrMoveUp;
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
      l10n.patrolRoundQrDeltaNorth(
        _qrFmtDeltaM(s.signedNorthToCheckpointM),
        _qrNorthMoveDirection(l10n, s.signedNorthToCheckpointM),
      ),
      l10n.patrolRoundQrDeltaEast(
        _qrFmtDeltaM(s.signedEastToCheckpointM),
        _qrEastMoveDirection(l10n, s.signedEastToCheckpointM),
      ),
      l10n.patrolRoundQrDeltaHorizontal(
        _qrFmtDistanceToCheckpointM(s),
        radius,
      ),
    ];

    final horizontalAcc = s.horizontalAccuracyM;
    if (horizontalAcc != null) {
      lines.add(
        l10n.patrolRoundQrGpsAccuracy(horizontalAcc.toStringAsFixed(0)),
      );
    }

    final gpsAltAcc = s.gpsAltitudeAccuracyM;
    if (gpsAltAcc != null && !s.usesBaroAltitude) {
      lines.add(
        l10n.patrolRoundQrGpsAltitudeAccuracy(gpsAltAcc.toStringAsFixed(0)),
      );
    }

    final altDelta = s.signedAltitudeDeltaM;
    if (s.checkpointAltitude != null &&
        altDelta != null &&
        altDelta.isFinite) {
      lines.add(
        '${l10n.patrolRoundQrDeltaAltitude(_qrFmtDeltaM(altDelta), radius)} · ${_qrAltMoveDirection(l10n, altDelta)}',
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

