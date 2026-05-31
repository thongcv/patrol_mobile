import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../services/app_locale_store.dart';
import '../services/patrol_active_round_coordinator.dart';
import '../services/patrol_realtime_track_coordinator.dart';
import '../services/patrol_realtime_track_service.dart';
import '../services/patrol_tracking_config_store.dart';
import '../utils/patrol_checkpoint_tts.dart';
import 'patrol_fgs_invoke_events.dart';
import 'patrol_fgs_relay_state.dart';

/// Relay FGS → UI when main isolate is alive (app in foreground).
abstract final class PatrolFgsMainRelay {
  PatrolFgsMainRelay._();

  static final List<StreamSubscription<dynamic>> _mainFgsRelaySubs = [];
  static StreamSubscription<dynamic>? _checkpointSuccessSub;

  static void attach({required FlutterBackgroundService fgs}) {
    for (final sub in _mainFgsRelaySubs) {
      unawaited(sub.cancel());
    }
    _mainFgsRelaySubs.clear();
    unawaited(_checkpointSuccessSub?.cancel());
    _checkpointSuccessSub = null;

    void safeRelay(String event, void Function(dynamic payload) onEvent) {
      try {
        final sub = fgs
            .on(event)
            .handleError((Object _, StackTrace _) {})
            .listen(
              onEvent,
              onError: (Object _, StackTrace _) {},
              cancelOnError: false,
            );
        _mainFgsRelaySubs.add(sub);
      } on MissingPluginException {
        // Event channel may be unavailable in startup plugin races.
      } on PlatformException {
        // Event channel may be unavailable in startup plugin races.
      }
    }

    try {
      _checkpointSuccessSub = fgs
          .on(PatrolFgsInvokeEvents.checkpointSuccess)
          .handleError((Object _, StackTrace _) {})
          .listen(
            (payload) {
              final map = payload is Map
                  ? Map<Object?, Object?>.from(payload as Map)
                  : null;
              if (map == null) return;
              final checkpointName =
                  (map['checkpointName'] as String?)?.trim() ?? '';
              if (checkpointName.isEmpty) return;
              unawaited(_speakCheckpointOnMainIsolate(checkpointName));
            },
            onError: (Object _, StackTrace _) {},
            cancelOnError: false,
          );
    } on MissingPluginException {
      //
    } on PlatformException {
      //
    }

    safeRelay(
      PatrolFgsInvokeEvents.activeRoundChanged,
      (payload) {
        final map = payload is Map
            ? Map<Object?, Object?>.from(payload)
            : null;
        unawaited(PatrolActiveRoundCoordinator.applyFgsRoundUpdate(payload: map));
      },
    );
    safeRelay(
      PatrolFgsInvokeEvents.trackingConfigChanged,
      (_) => unawaited(PatrolRealtimeTrackCoordinator.refreshTracking()),
    );
    safeRelay(
      PatrolFgsInvokeEvents.socketConnected,
      (_) async {
        // FGS owns STOMP in background mode — syncing here re-triggers refresh loops.
        if (await PatrolTrackingConfigStore.backgroundEnabled()) return;
        unawaited(PatrolActiveRoundCoordinator.syncFromServer());
      },
    );
    safeRelay(
      PatrolFgsInvokeEvents.mockLocationAlert,
      (_) => PatrolFgsRelayState.relayFgsMockLocationAlert?.call(),
    );
    safeRelay(
      PatrolFgsInvokeEvents.positionUpdate,
      PatrolRealtimeTrackService.instance.notifyPositionFromFgsRelay,
    );
  }

  static Future<void> _speakCheckpointOnMainIsolate(String checkpointName) async {
    final locale = await AppLocaleStore.readLocale();
    await PatrolCheckpointTts.speakCheckpoint(
      checkpointName: checkpointName,
      locale: locale,
    );
  }
}
