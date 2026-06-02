part of '../patrol_round_screen.dart';

/// Map overlay refresh: empty [checkpointIds] = rebuild all markers.
class _RouteMapUpdate {
  const _RouteMapUpdate({required this.seq, this.checkpointIds = const {}});

  final int seq;
  final Set<int> checkpointIds;
}

enum _RoundAutoScanKind { gps, bluetooth }

enum _RoundManualScanKind { qr, nfc }

