part of '../patrol_round_screen.dart';

/// Map overlay refresh: empty [checkpointIds] = rebuild all markers.
class _RouteMapUpdate {
  const _RouteMapUpdate({required this.seq, this.checkpointIds = const {}});

  final int seq;
  final Set<int> checkpointIds;
}

enum CheckPointMatchOrder {
  /// Only [points.first] (sorted by `sequenceOrder`); returns on match.
  sequenceOrder,

  /// Among matches, pick smallest horizontal distance.
  nearest,
}

enum _RoundAutoScanKind { gps, bluetooth }

enum _RoundManualScanKind { qr, nfc }

/// Proximity scan result: matched checkpoint for log and/or UI feedback.
class _CheckPointProximityScan {
  const _CheckPointProximityScan({this.matched, this.feedback});

  final CheckPoint? matched;
  final CheckPointProximityEvaluation? feedback;
}

