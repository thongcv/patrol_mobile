import 'dart:async';



import 'package:flutter/material.dart';



import '../l10n/app_localizations.dart';

import '../navigation/patrol_session.dart';

import '../utils/top_toast.dart';

import 'account_session_store.dart';

import 'patrol_active_round_cache.dart';

import 'patrol_realtime_track_service.dart';

import 'patrol_round_service.dart';



/// UI-independent realtime positioning — polls active round and toggles tracking.

abstract final class PatrolRealtimeTrackCoordinator {

  PatrolRealtimeTrackCoordinator._();



  static const Duration _activeRoundPollInterval = Duration(minutes: 1);



  static GlobalKey<NavigatorState>? _navigatorKey;

  static Locale Function()? _currentLocale;



  static StreamSubscription<void>? _authSub;

  static StreamSubscription<void>? _sessionEndedSub;

  static StreamSubscription<bool>? _mockAlertSub;

  static Timer? _pollTimer;

  static int? _trackedRoundId;

  static bool _polling = false;



  static void attach({

    required GlobalKey<NavigatorState> navigatorKey,

    required Locale Function() currentLocale,

  }) {

    _navigatorKey = navigatorKey;

    _currentLocale = currentLocale;

    _authSub ??= PatrolSession.authStoredChanges.listen((_) {
      unawaited(resumeIfSession());
    });

    _sessionEndedSub ??= PatrolSession.sessionEnded.listen((_) {
      unawaited(onSessionEnded());
    });

    _mockAlertSub ??= PatrolRealtimeTrackService.instance.mockViolationAlerts.listen((_) {

      _showMockGpsAlert();

    });

    unawaited(resumeIfSession());

  }



  static void detach() {

    _authSub?.cancel();

    _authSub = null;

    _sessionEndedSub?.cancel();

    _sessionEndedSub = null;

    _mockAlertSub?.cancel();

    _mockAlertSub = null;

    _navigatorKey = null;

    _currentLocale = null;

    _stopPolling();

  }

  /// Khôi phục sau đăng nhập hoặc mở app có token.

  static Future<void> resumeIfSession() async {

    if (!await AccountSessionStore.instance.hasStoredSession()) return;

    await onAuthenticated();

  }

  static Future<void> onAuthenticated() async {
    await PatrolRealtimeTrackService.instance.onAuthenticated();
    _startPolling();
    await _syncActiveRound();

  }

  static Future<void> onSessionEnded() async {

    _trackedRoundId = null;

    _stopPolling();

    await PatrolRealtimeTrackService.instance.onSessionEnded();

  }



  static void _startPolling() {

    if (_polling) return;

    _polling = true;

    _pollTimer?.cancel();

    _pollTimer = Timer.periodic(_activeRoundPollInterval, (_) {
      unawaited(_syncActiveRound());
    });

  }



  static void _stopPolling() {

    _polling = false;

    _pollTimer?.cancel();

    _pollTimer = null;

  }



  static Future<void> _syncActiveRound() async {

    if (!_polling) return;

    final r = await PatrolRoundService.instance.fetchMyActivePatrolRound();
    if (PatrolSession.isUnauthorized(r.failure)) {
      await PatrolSession.endSessionAndNavigateToLogin();
      return;
    }

    if (!r.ok) return;

    final roundId = r.data?.round.id;

    if (roundId == null || roundId <= 0) {
      if (_trackedRoundId != null) {
        _trackedRoundId = null;
        await PatrolActiveRoundCache.save(null);
        await PatrolRealtimeTrackService.instance.stopRoundTracking();
      }
      return;
    }

    if (_trackedRoundId == roundId 
        && PatrolRealtimeTrackService.instance.isTrackingRound) {
      return;
    }

    _trackedRoundId = roundId;

    await PatrolActiveRoundCache.save(r.data);

    await PatrolRealtimeTrackService.instance.startRoundTracking(

      roundId: roundId,

    );

  }



  /// Báo coordinator: user đang quét thủ công / auto-scan trên UI.

  /// Chỉ tắt auto-scan nền, không dừng socket.

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

