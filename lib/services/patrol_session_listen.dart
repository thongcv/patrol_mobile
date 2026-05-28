import 'dart:async';

import '../navigation/patrol_session.dart';
import 'account_session_store.dart';

/// Shared [PatrolSession] auth / session-ended wiring for patrol coordinators.
final class PatrolSessionListen {
  PatrolSessionListen({
    required Future<void> Function() onAuthenticated,
    required Future<void> Function() onSessionEnded,
  })  : _onAuthenticated = onAuthenticated,
        _onSessionEnded = onSessionEnded;

  final Future<void> Function() _onAuthenticated;
  final Future<void> Function() _onSessionEnded;

  StreamSubscription<void>? _authSub;
  StreamSubscription<void>? _sessionEndedSub;
  Future<void>? _authInFlight;

  bool sessionActive = false;

  void attach() {
    _authSub?.cancel();
    _authSub = PatrolSession.authStoredChanges.listen((_) {
      unawaited(resumeIfSession());
    });

    _sessionEndedSub?.cancel();
    _sessionEndedSub = PatrolSession.sessionEnded.listen((_) {
      unawaited(_onSessionEnded());
    });
  }

  void detach() {
    _authSub?.cancel();
    _authSub = null;
    _sessionEndedSub?.cancel();
    _sessionEndedSub = null;
    sessionActive = false;
  }

  Future<void> resumeIfSession() async {
    if (!await AccountSessionStore.instance.hasStoredSession()) return;
    await runAuthenticated();
  }

  Future<void> runAuthenticated() async {
    final inFlight = _authInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final future = _runAuthenticatedImpl();
    _authInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_authInFlight, future)) {
        _authInFlight = null;
      }
    }
  }

  Future<void> _runAuthenticatedImpl() async {
    sessionActive = true;
    await _onAuthenticated();
  }

  Future<bool> ensureSessionActive() async {
    if (sessionActive) return true;
    if (!await AccountSessionStore.instance.hasStoredSession()) return false;
    await runAuthenticated();
    return sessionActive;
  }
}
