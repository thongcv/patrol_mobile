import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/patrol_background_location_prompt.dart';
import '../utils/top_toast.dart';
import 'patrol_background_service.dart';
import 'patrol_realtime_track_service.dart';
import 'patrol_session_listen.dart';

/// GPS + emit vị trí + FGS — tách khỏi đồng bộ vòng tuần tra ([PatrolActiveRoundCoordinator]).
abstract final class PatrolRealtimeTrackCoordinator {
  PatrolRealtimeTrackCoordinator._();

  static final PatrolSessionListen _session = PatrolSessionListen(
    onAuthenticated: _onAuthenticated,
    onSessionEnded: onSessionEnded,
  );

  static GlobalKey<NavigatorState>? _navigatorKey;
  static Locale Function()? _currentLocale;

  static StreamSubscription<bool>? _mockAlertSub;

  static void attach({
    required GlobalKey<NavigatorState> navigatorKey,
    required Locale Function() currentLocale,
  }) {
    _navigatorKey = navigatorKey;
    _currentLocale = currentLocale;

    _mockAlertSub ??=
        PatrolRealtimeTrackService.instance.mockViolationAlerts.listen((_) {
      _showMockGpsAlert();
    });

    PatrolBackgroundService.relayFgsMockLocationAlert =
        PatrolRealtimeTrackService.instance.notifyServerMockLocationAlert;
  }

  static void detach() {
    _mockAlertSub?.cancel();
    _mockAlertSub = null;
    PatrolBackgroundService.relayFgsMockLocationAlert = null;
    _navigatorKey = null;
    _currentLocale = null;
  }

  static Future<void> resumeIfSession() => _session.resumeIfSession();

  /// Called from [PatrolStartupCoordinator] after location gate — not via
  /// [PatrolSessionListen.resumeIfSession] (separate [_session] + in-flight skip).
  static Future<void> bootstrapAuthenticatedSession() async {
    _session.sessionActive = true;
    await _onAuthenticated();
  }

  static Future<void> _onAuthenticated() async {
    await PatrolRealtimeTrackService.instance.onAuthenticated();
    final service = PatrolRealtimeTrackService.instance;
    if (service.isSessionTracking) {
      await service.refreshActiveTracking();
      await syncTrackingAfterRoundPersisted(force: true);
    } else {
      await service.startSessionTracking();
      await syncTrackingAfterRoundPersisted(force: true);
    }
    _promptBackgroundLocationIfNeeded();
  }

  static Future<void> onSessionEnded() async {
    _session.sessionActive = false;
    _lastSyncTrackingAfterRound = null;
    await PatrolRealtimeTrackService.instance.onSessionEnded();
    await PatrolBackgroundService.stopPatrolTracking();
  }

  static DateTime? _lastSyncTrackingAfterRound;

  /// Sau [PatrolActiveRoundSync] ghi prefs — refresh FGS/GPS (auto-scan prefs).
  ///
  /// [force] skips coordinator debounce (bootstrap / STOMP after round persist).
  /// Does not start tracking — caller must run [bootstrapAuthenticatedSession] first.
  static Future<void> syncTrackingAfterRoundPersisted({bool force = false}) async {
    if (!PatrolRealtimeTrackService.instance.isSessionTracking) {
      return;
    }

    if (!force) {
      final now = DateTime.now();
      final last = _lastSyncTrackingAfterRound;
      if (last != null &&
          now.difference(last) < const Duration(milliseconds: 1500)) {
        return;
      }
      _lastSyncTrackingAfterRound = now;
    } else {
      _lastSyncTrackingAfterRound = DateTime.now();
    }

    await PatrolRealtimeTrackService.instance.syncTrackingAfterRoundPersisted();
  }

  /// Sau location gate / cấp quyền Always — gắn lại GPS nếu đang track.
  static Future<void> refreshTracking() async {
    if (!await _session.ensureSessionActive()) return;
    await PatrolRealtimeTrackService.instance.refreshActiveTracking();
    await syncTrackingAfterRoundPersisted();
  }

  static void _promptBackgroundLocationIfNeeded() {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = nav.context;
      if (!ctx.mounted) return;
      unawaited(showPatrolBackgroundLocationPromptIfNeeded(ctx));
    });
  }

  /// Tạm dừng auto-scan nền khi user quét thủ công trên UI (không dừng emit vị trí).
  static Future<void> setRoundScanBusy(bool busy) async {
    await PatrolRealtimeTrackService.instance.setForegroundRoundScanBusy(busy);
  }

  static void _showMockGpsAlert() {
    final nav = _navigatorKey?.currentState;
    final locale = _currentLocale?.call();
    if (nav == null || locale == null) return;

    final ctx = nav.context;
    final l10n = lookupAppLocalizations(locale);
    TopToast.show(
      ctx,
      '${l10n.patrolTrackMockGpsTitle}\n${l10n.patrolTrackMockGpsBody}',
      duration: const Duration(seconds: 6),
      backgroundColor: const Color(0xFFDC2626),
    );
  }

}
