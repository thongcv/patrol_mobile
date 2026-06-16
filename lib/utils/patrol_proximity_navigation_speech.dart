import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../background/patrol_background_service.dart';
import '../l10n/app_localizations.dart';
import '../services/app_locale_store.dart';
import 'check_point_proximity.dart';
import 'patrol_checkpoint_tts.dart';

/// Throttle inputs for proximity navigation TTS (testable).
@immutable
class PatrolProximityNavigationTtsState {
  const PatrolProximityNavigationTtsState({
    this.lastNorth,
    this.lastEast,
    this.lastAlt,
    this.lastHorizontalRounded,
    this.lastSpokeAt,
  });

  final CheckPointMoveDirection? lastNorth;
  final CheckPointMoveDirection? lastEast;
  final CheckPointMoveDirection? lastAlt;
  final int? lastHorizontalRounded;
  final DateTime? lastSpokeAt;
}

/// Builds TTS phrases from proximity navigation hints and speaks with throttle.
abstract final class PatrolProximityNavigationTts {
  PatrolProximityNavigationTts._();

  static const Duration _minInterval = Duration(seconds: 12);
  static const Duration _backgroundReminderInterval = Duration(seconds: 10);
  static const int _distanceChangeM = 3;

  static CheckPointMoveDirection? _lastNorth;
  static CheckPointMoveDirection? _lastEast;
  static CheckPointMoveDirection? _lastAlt;
  static int? _lastHorizontalRounded;
  static DateTime? _lastSpokeAt;

  /// Clears throttle state when a foreground GPS scan session ends.
  static void reset() {
    _lastNorth = null;
    _lastEast = null;
    _lastAlt = null;
    _lastHorizontalRounded = null;
    _lastSpokeAt = null;
  }

  /// Speaks turn-by-turn hint when [snapshot] changes meaningfully.
  ///
  /// [backgroundReminder] — FGS auto-scan: re-prompt on a fixed interval even
  /// when the user is standing still, so pocket/screen-off patrol still gets
  /// audible guidance toward the next checkpoint.
  static Future<void> maybeSpeak({
    required CheckPointProximitySnapshot snapshot,
    Locale? locale,
    bool backgroundReminder = false,
  }) async {
    final nav = CheckPointProximityNavigationHints.fromSnapshot(snapshot);
    if (!_shouldSpeak(nav, backgroundReminder: backgroundReminder)) return;

    final resolvedLocale = locale ?? await AppLocaleStore.readLocale();
    final l10n = lookupAppLocalizations(resolvedLocale);
    final message = formatProximityNavigationSpeech(l10n, nav);
    if (message.isEmpty) return;

    _remember(nav);
    final spoke = await PatrolCheckpointTts.speakProximityNavigation(
      message: message,
      locale: resolvedLocale,
      dedupeWindow: backgroundReminder
          ? _backgroundReminderInterval
          : null,
    );
    if (!spoke && PatrolBackgroundService.isBackgroundIsolate) {
      PatrolBackgroundService.relayProximityNavigationToUi(message);
    }
  }

  @visibleForTesting
  static bool shouldSpeakForState({
    required CheckPointProximityNavigationHints nav,
    required PatrolProximityNavigationTtsState state,
    bool backgroundReminder = false,
    DateTime? now,
  }) {
    return _shouldSpeak(
      nav,
      backgroundReminder: backgroundReminder,
      state: state,
      now: now ?? DateTime.now(),
    );
  }

  static bool _shouldSpeak(
    CheckPointProximityNavigationHints nav, {
    bool backgroundReminder = false,
    PatrolProximityNavigationTtsState? state,
    DateTime? now,
  }) {
    final resolvedState = state ??
        PatrolProximityNavigationTtsState(
          lastNorth: _lastNorth,
          lastEast: _lastEast,
          lastAlt: _lastAlt,
          lastHorizontalRounded: _lastHorizontalRounded,
          lastSpokeAt: _lastSpokeAt,
        );
    final clock = now ?? DateTime.now();
    final minInterval =
        backgroundReminder ? _backgroundReminderInterval : _minInterval;

    final horizontalR = nav.horizontalDistanceM.round();
    final northChanged = nav.northMove != resolvedState.lastNorth;
    final eastChanged = nav.eastMove != resolvedState.lastEast;
    final altChanged = nav.altitudeMove != resolvedState.lastAlt;
    final distChanged = resolvedState.lastHorizontalRounded == null ||
        (horizontalR - resolvedState.lastHorizontalRounded!).abs() >=
            _distanceChangeM;

    if (resolvedState.lastSpokeAt == null) return true;

    final elapsed = clock.difference(resolvedState.lastSpokeAt!);
    if (backgroundReminder && elapsed >= minInterval) {
      return true;
    }

    if (elapsed >= minInterval) {
      return northChanged || eastChanged || altChanged || distChanged;
    }

    if (backgroundReminder) {
      return northChanged || eastChanged || altChanged || distChanged;
    }

    return northChanged || eastChanged || altChanged;
  }

  static void _remember(CheckPointProximityNavigationHints nav) {
    _lastNorth = nav.northMove;
    _lastEast = nav.eastMove;
    _lastAlt = nav.altitudeMove;
    _lastHorizontalRounded = nav.horizontalDistanceM.round();
    _lastSpokeAt = DateTime.now();
  }
}

/// Localized phrase for TTS (no Flutter UI dependencies beyond [AppLocalizations]).
String formatProximityNavigationSpeech(
  AppLocalizations l10n,
  CheckPointProximityNavigationHints nav,
) {
  final moves = <String>[];

  void addAxisMove({
    required CheckPointMoveDirection move,
    required double absDeltaM,
    required String Function(String direction, String distance) formatter,
  }) {
    if (move == CheckPointMoveDirection.onTarget) return;
    moves.add(formatter(_directionWord(l10n, move), formatPatrolDistanceM(absDeltaM)));
  }

  addAxisMove(
    move: nav.northMove,
    absDeltaM: nav.northAbsDeltaM,
    formatter: l10n.patrolProximityTtsMove,
  );
  addAxisMove(
    move: nav.eastMove,
    absDeltaM: nav.eastAbsDeltaM,
    formatter: l10n.patrolProximityTtsMove,
  );

  final altMove = nav.altitudeMove;
  final altDeltaM = nav.altitudeAbsDeltaM;
  if (altMove != null &&
      altDeltaM != null &&
      altMove != CheckPointMoveDirection.onTarget) {
    moves.add(
      l10n.patrolProximityTtsMoveVertical(
        _directionWord(l10n, altMove),
        formatPatrolDistanceM(altDeltaM),
      ),
    );
  }

  final distance = formatPatrolDistanceM(nav.horizontalDistanceM);
  if (moves.isEmpty) {
    return l10n.patrolProximityTtsNearCheckpoint(distance);
  }
  return l10n.patrolProximityTtsHint(
    distance,
    moves.join(l10n.patrolProximityTtsMoveSeparator),
  );
}

String _directionWord(AppLocalizations l10n, CheckPointMoveDirection direction) {
  return switch (direction) {
    CheckPointMoveDirection.onTarget => l10n.patrolRoundQrMoveOnTarget,
    CheckPointMoveDirection.north => l10n.patrolRoundQrMoveNorth,
    CheckPointMoveDirection.south => l10n.patrolRoundQrMoveSouth,
    CheckPointMoveDirection.east => l10n.patrolRoundQrMoveEast,
    CheckPointMoveDirection.west => l10n.patrolRoundQrMoveWest,
    CheckPointMoveDirection.up => l10n.patrolRoundQrMoveUp,
    CheckPointMoveDirection.down => l10n.patrolRoundQrMoveDown,
  };
}
