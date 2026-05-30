import 'account_session_store.dart';
import 'patrol_active_round_cache.dart';
import 'patrol_active_round_coordinator.dart';
import 'patrol_active_round_sync.dart';
import 'patrol_realtime_track_coordinator.dart';
import 'patrol_session_listen.dart';
import '../utils/device_location.dart';

/// One serialized bootstrap after location gate / login — avoids duplicate
/// [PatrolRealtimeTrackService.startSessionTracking] from parallel coordinators.
abstract final class PatrolStartupCoordinator {
  PatrolStartupCoordinator._();

  static final PatrolSessionListen _session = PatrolSessionListen(
    onAuthenticated: _onAuthenticated,
    onSessionEnded: _onSessionEnded,
  );

  static Future<void>? _resumeChain;

  /// Cleared on each process start — [LocationGateScreen] sets true after checks.
  static bool _locationGatePassedThisLaunch = false;

  /// Call from [main] before [attach] so stale prefs cannot bootstrap before gate.
  static void resetForNewProcessLaunch() {
    _locationGatePassedThisLaunch = false;
    _resumeChain = null;
    PatrolBackgroundLocationReadiness.invalidate();
  }

  /// After [LocationGateScreen] permission checks (with or without stored session).
  static void markLocationGatePassed() {
    _locationGatePassedThisLaunch = true;
    PatrolBackgroundLocationReadiness.markReady();
  }

  static void attach() => _session.attach();

  static void detach() => _session.detach();

  /// Location gate / post-login entry — active round (auto-scan prefs) then tracking.
  static Future<void> resumeSessionAfterLocationReady() {
    _resumeChain =
        (_resumeChain ?? Future<void>.value()).then((_) => _resumeImpl());
    return _resumeChain!;
  }

  static Future<void> _onAuthenticated() async {
    await resumeSessionAfterLocationReady();
  }

  static Future<void> _onSessionEnded() async {
    _locationGatePassedThisLaunch = false;
    _resumeChain = null;
    await PatrolRealtimeTrackCoordinator.onSessionEnded();
    await PatrolActiveRoundCoordinator.onSessionEnded();
  }

  static Future<void> _resumeImpl() async {
    if (!await AccountSessionStore.instance.hasStoredSession()) return;
    if (!_locationGatePassedThisLaunch &&
        !await PatrolBackgroundLocationReadiness.isRecentlyVerifiedAcrossIsolates()) {
      return;
    }
    // Main may have cleared this in [startSessionTracking]; FGS must not read a stale `true`
    // left from a killed mid-scan session (PatrolRoundScreen may not mount yet).
    await PatrolActiveRoundCache.setForegroundScanBusy(false);
    await PatrolActiveRoundSync.clearBackgroundAutoScanArmed();
    await PatrolActiveRoundCoordinator.bootstrapAuthenticatedSession();
    // Round prefs first; tracking bootstrap ends with syncTrackingAfterRoundPersisted(force).
    await PatrolRealtimeTrackCoordinator.bootstrapAuthenticatedSession();
  }
}
