import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../background/patrol_background_service.dart';
import '../l10n/app_localizations.dart';
import '../models/patrol_tracking_config.dart';
import '../services/app_locale_store.dart';
import '../services/patrol_tracking_config_store.dart';
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

  /// Floor applied to noisy walking speed when estimating time-to-arrival.
  static const double _walkingFloorMps = 0.7;

  /// Re-announce after the user has covered this many seconds of travel…
  static const double _distanceStepSeconds = 3;

  /// …bounded by this minimum and maximum distance step (m).
  static const int _distanceChangeM = 3;
  static const double _maxDistanceStepM = 20;

  /// Speak after roughly this fraction of the remaining ETA has elapsed.
  static const double _etaIntervalFraction = 1 / 3;

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
  /// [speedMps] — current ground speed (GPS), used to pace hints by ETA so the
  /// guidance comes more often on final approach and stays quiet when idle.
  static Future<void> maybeSpeak({
    required CheckPointProximitySnapshot snapshot,
    Locale? locale,
    bool backgroundReminder = false,
    double? speedMps,
  }) async {
    final config = await PatrolTrackingConfigStore.load();
    final nav = CheckPointProximityNavigationHints.fromSnapshot(snapshot);
    if (!_shouldSpeak(
      nav,
      config: config,
      backgroundReminder: backgroundReminder,
      speedMps: speedMps,
    )) {
      return;
    }

    // Defer (without advancing throttle/relaying) while a checkpoint-scan or
    // round announcement is speaking, so guidance never cuts it off.
    if (await PatrolCheckpointTts.isPriorityAnnouncementActive()) return;

    final resolvedLocale = locale ?? await AppLocaleStore.readLocale();
    final l10n = lookupAppLocalizations(resolvedLocale);
    final message = formatProximityNavigationSpeech(l10n, nav);
    if (message.isEmpty) return;

    _remember(nav);
    final spoke = await PatrolCheckpointTts.speakProximityNavigation(
      message: message,
      locale: resolvedLocale,
      dedupeWindow: backgroundReminder
          ? Duration(seconds: config.navHintBgSec)
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
    double? speedMps,
    DateTime? now,
    PatrolTrackingConfig config = PatrolTrackingConfig.defaults,
  }) {
    return _shouldSpeak(
      nav,
      config: config,
      backgroundReminder: backgroundReminder,
      speedMps: speedMps,
      state: state,
      now: now ?? DateTime.now(),
    );
  }

  static bool _shouldSpeak(
    CheckPointProximityNavigationHints nav, {
    required PatrolTrackingConfig config,
    bool backgroundReminder = false,
    double? speedMps,
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

    final horizontalR = nav.horizontalDistanceM.round();
    final northChanged = nav.northMove != resolvedState.lastNorth;
    final eastChanged = nav.eastMove != resolvedState.lastEast;
    final altChanged = nav.altitudeMove != resolvedState.lastAlt;
    final directionChanged = northChanged || eastChanged || altChanged;

    final distanceStep = _resolveDistanceStepM(speedMps);
    final distChanged = resolvedState.lastHorizontalRounded == null ||
        (horizontalR - resolvedState.lastHorizontalRounded!).abs() >=
            distanceStep;

    if (resolvedState.lastSpokeAt == null) return true;

    final elapsed = clock.difference(resolvedState.lastSpokeAt!);
    final minGap = Duration(seconds: config.navHintGapSec);
    // Never fire two hints back-to-back, even on a direction flip.
    if (elapsed < minGap) return false;

    final interval = _resolveInterval(
      config: config,
      backgroundReminder: backgroundReminder,
      speedMps: speedMps,
      distanceM: nav.horizontalDistanceM,
    );

    if (elapsed >= interval) {
      // Background keeps a periodic nudge for screen-off / pocketed patrol.
      return backgroundReminder ? true : (directionChanged || distChanged);
    }

    // Within the interval, only a meaningful route change breaks through.
    return directionChanged || distChanged;
  }

  /// Pace between hints: ETA-based while moving (more frequent on approach),
  /// stretched while standing still, and clamped to min gap…cap.
  static Duration _resolveInterval({
    required PatrolTrackingConfig config,
    required bool backgroundReminder,
    required double? speedMps,
    required double distanceM,
  }) {
    final minGap = Duration(seconds: config.navHintGapSec);
    final speed = _sanitizeSpeed(speedMps);
    if (speed < config.navStationarySpeedMps) {
      final stationarySec = backgroundReminder
          ? config.navStationaryBgSec
          : config.navStationaryFgSec;
      return Duration(seconds: stationarySec);
    }

    final cap = Duration(
      seconds: backgroundReminder ? config.navHintBgSec : config.navHintMinSec,
    );
    final effectiveSpeed = math.max(speed, _walkingFloorMps);
    final etaSeconds =
        distanceM.isFinite && distanceM > 0 ? distanceM / effectiveSpeed : 0.0;
    final dynamicMs = (etaSeconds * _etaIntervalFraction * 1000).round();
    final clampedMs =
        dynamicMs.clamp(minGap.inMilliseconds, cap.inMilliseconds);
    return Duration(milliseconds: clampedMs);
  }

  /// Distance the user must cover before a hint repeats — scales with speed so
  /// fast movement doesn't trigger a hint on every meter, slow movement still does.
  static double _resolveDistanceStepM(double? speedMps) {
    final speed = _sanitizeSpeed(speedMps);
    final step = speed * _distanceStepSeconds;
    return step.clamp(_distanceChangeM.toDouble(), _maxDistanceStepM);
  }

  static double _sanitizeSpeed(double? speedMps) {
    if (speedMps == null || !speedMps.isFinite || speedMps <= 0) return 0;
    return speedMps;
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
