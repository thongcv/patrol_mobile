import 'package:flutter/widgets.dart';

import '../background/patrol_background_service.dart';
import '../l10n/app_localizations.dart';
import '../services/app_locale_store.dart';
import 'check_point_proximity.dart';
import 'patrol_checkpoint_tts.dart';

/// Builds TTS phrases from proximity navigation hints and speaks with throttle.
abstract final class PatrolProximityNavigationTts {
  PatrolProximityNavigationTts._();

  static const Duration _minInterval = Duration(seconds: 12);
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
  static Future<void> maybeSpeak({
    required CheckPointProximitySnapshot snapshot,
    Locale? locale,
  }) async {
    final nav = CheckPointProximityNavigationHints.fromSnapshot(snapshot);
    if (!_shouldSpeak(nav)) return;

    final resolvedLocale = locale ?? await AppLocaleStore.readLocale();
    final l10n = lookupAppLocalizations(resolvedLocale);
    final message = formatProximityNavigationSpeech(l10n, nav);
    if (message.isEmpty) return;

    _remember(nav);
    final spoke = await PatrolCheckpointTts.speakProximityNavigation(
      message: message,
      locale: resolvedLocale,
    );
    if (!spoke && PatrolBackgroundService.isBackgroundIsolate) {
      PatrolBackgroundService.relayProximityNavigationToUi(message);
    }
  }

  static bool _shouldSpeak(CheckPointProximityNavigationHints nav) {
    final horizontalR = nav.horizontalDistanceM.round();
    final northChanged = nav.northMove != _lastNorth;
    final eastChanged = nav.eastMove != _lastEast;
    final altChanged = nav.altitudeMove != _lastAlt;
    final distChanged = _lastHorizontalRounded == null ||
        (horizontalR - _lastHorizontalRounded!).abs() >= _distanceChangeM;

    if (_lastSpokeAt == null) return true;

    final elapsed = DateTime.now().difference(_lastSpokeAt!);
    if (elapsed >= _minInterval) {
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
    final meters = _speechMeters(absDeltaM);
    moves.add(formatter(_directionWord(l10n, move), meters.toString()));
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
        _speechMeters(altDeltaM).toString(),
      ),
    );
  }

  final distance = _speechMeters(nav.horizontalDistanceM).toString();
  if (moves.isEmpty) {
    return l10n.patrolProximityTtsNearCheckpoint(distance);
  }
  return l10n.patrolProximityTtsHint(
    distance,
    moves.join(l10n.patrolProximityTtsMoveSeparator),
  );
}

int _speechMeters(double absM) {
  final rounded = absM.round();
  return rounded < 1 ? 1 : rounded;
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
