import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../navigation/patrol_session.dart';
import '../utils/patrol_background_location_prompt.dart';
import '../utils/top_toast.dart';
import 'account_session_store.dart';
import 'patrol_background_service.dart';
import 'patrol_realtime_track_service.dart';

import 'patrol_tracking_config_store.dart';

/// GPS + emit vị trí + FGS — tách khỏi đồng bộ vòng tuần tra ([PatrolActiveRoundCoordinator]).
abstract final class PatrolRealtimeTrackCoordinator {
  PatrolRealtimeTrackCoordinator._();

  static GlobalKey<NavigatorState>? _navigatorKey;
  static Locale Function()? _currentLocale;

  static StreamSubscription<void>? _authSub;
  static StreamSubscription<void>? _sessionEndedSub;
  static StreamSubscription<bool>? _mockAlertSub;

  static int? _trackedRoundId;
  static bool _sessionActive = false;

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

    _mockAlertSub ??=
        PatrolRealtimeTrackService.instance.mockViolationAlerts.listen((_) {
      _showMockGpsAlert();
    });
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
    _trackedRoundId = null;
    _sessionActive = false;
  }

  static Future<void> resumeIfSession() async {
    if (!await AccountSessionStore.instance.hasStoredSession()) return;
    await onAuthenticated();
  }

  static Future<void> onAuthenticated() async {
    _sessionActive = true;
    await PatrolRealtimeTrackService.instance.onAuthenticated();
    await _initBackgroundIfConfigured();
  }

  static Future<void> onSessionEnded() async {
    _trackedRoundId = null;
    _sessionActive = false;
    await PatrolRealtimeTrackService.instance.onSessionEnded();
    await PatrolBackgroundService.stopPatrolTracking();
  }

  /// Bật/tắt tracking GPS theo vòng tuần tra — gọi từ [PatrolActiveRoundCoordinator].
  static Future<void> applyActiveRound(int? roundId) async {
    if (!_sessionActive) return;

    if (roundId == null || roundId <= 0) {
      if (_trackedRoundId != null) {
        _trackedRoundId = null;
        await PatrolRealtimeTrackService.instance.stopRoundTracking();
      }
      return;
    }

    if (_trackedRoundId == roundId &&
        PatrolRealtimeTrackService.instance.isTrackingRound) {
      await refreshTracking();
      return;
    }

    _trackedRoundId = roundId;
    await PatrolRealtimeTrackService.instance.startRoundTracking(
      roundId: roundId,
    );
    _promptBackgroundLocationIfNeeded();
  }

  /// Sau location gate / cấp quyền Always — gắn lại GPS nếu đang track.
  static Future<void> refreshTracking() async {
    if (!_sessionActive) return;
    await PatrolRealtimeTrackService.instance.refreshActiveTracking();
  }

  static Future<void> _initBackgroundIfConfigured() async {
    final cfg = await PatrolTrackingConfigStore.load();
    if (!cfg.background) return;
    await PatrolBackgroundService.ensureInitialized();
    await PatrolBackgroundService.startPatrolTracking();
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
