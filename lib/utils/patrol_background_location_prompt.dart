import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n/app_localizations.dart';
import '../services/patrol_realtime_track_coordinator.dart';
import 'device_location.dart';

/// Shows a dialog when patrol tracking needs "Always" location (iOS / Android).
Future<void> showPatrolBackgroundLocationPromptIfNeeded(
  BuildContext context,
) async {
  if (!context.mounted) return;
  if (!await patrolNeedsBackgroundLocationUpgrade()) return;
  if (!context.mounted) return;

  final l10n = AppLocalizations.of(context)!;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(l10n.patrolBackgroundLocationTitle),
        content: Text(l10n.patrolBackgroundLocationBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.retry),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              var permission = await Geolocator.checkPermission();
              if (permission == LocationPermission.whileInUse ||
                  permission == LocationPermission.deniedForever) {
                await Geolocator.openAppSettings();
              } else {
                await ensurePatrolBackgroundLocationReady();
                permission = await Geolocator.checkPermission();
                if (permission == LocationPermission.whileInUse) {
                  await Geolocator.openAppSettings();
                }
              }
              if (!await patrolNeedsBackgroundLocationUpgrade()) {
                PatrolBackgroundLocationReadiness.markReady();
              }
              unawaited(PatrolRealtimeTrackCoordinator.refreshTracking());
            },
            child: Text(l10n.patrolBackgroundLocationGrantAlways),
          ),
        ],
      );
    },
  );
}
