import 'package:flutter_test/flutter_test.dart';
import 'package:sps/utils/check_point_proximity.dart';
import 'package:sps/utils/patrol_proximity_navigation_speech.dart';

void main() {
  const nav = CheckPointProximityNavigationHints(
    northAbsDeltaM: 12,
    northMove: CheckPointMoveDirection.north,
    eastAbsDeltaM: 5,
    eastMove: CheckPointMoveDirection.east,
    horizontalDistanceM: 15,
  );

  final spokeAt = DateTime(2026, 6, 16, 10, 0, 0);
  final remembered = PatrolProximityNavigationTtsState(
    lastNorth: CheckPointMoveDirection.north,
    lastEast: CheckPointMoveDirection.east,
    lastAlt: null,
    lastHorizontalRounded: 15,
    lastSpokeAt: spokeAt,
  );

  test('foreground mode stays silent when standing still within interval', () {
    expect(
      PatrolProximityNavigationTts.shouldSpeakForState(
        nav: nav,
        state: remembered,
        now: spokeAt.add(const Duration(seconds: 15)),
      ),
      isFalse,
    );
  });

  test('standing still stretches the background reminder interval', () {
    // Was 10s; with no movement we now hold off until the stationary window.
    expect(
      PatrolProximityNavigationTts.shouldSpeakForState(
        nav: nav,
        state: remembered,
        backgroundReminder: true,
        speedMps: 0,
        now: spokeAt.add(const Duration(seconds: 10)),
      ),
      isFalse,
    );
    expect(
      PatrolProximityNavigationTts.shouldSpeakForState(
        nav: nav,
        state: remembered,
        backgroundReminder: true,
        speedMps: 0,
        now: spokeAt.add(const Duration(seconds: 20)),
      ),
      isTrue,
    );
  });

  test('anti-chatter floor blocks a direction flip fired too soon', () {
    final turned = CheckPointProximityNavigationHints(
      northAbsDeltaM: 12,
      northMove: CheckPointMoveDirection.south,
      eastAbsDeltaM: 5,
      eastMove: CheckPointMoveDirection.east,
      horizontalDistanceM: 15,
    );

    expect(
      PatrolProximityNavigationTts.shouldSpeakForState(
        nav: turned,
        state: remembered,
        speedMps: 1.4,
        now: spokeAt.add(const Duration(seconds: 3)),
      ),
      isFalse,
    );
    expect(
      PatrolProximityNavigationTts.shouldSpeakForState(
        nav: turned,
        state: remembered,
        speedMps: 1.4,
        now: spokeAt.add(const Duration(seconds: 6)),
      ),
      isTrue,
    );
  });

  test('walking close to the checkpoint shortens the interval via ETA', () {
    // ~3 m away at 1.5 m/s → ETA ~2s collapses the interval to the 5s floor,
    // so the next hint comes right after the anti-chatter gap (not the 10s cap).
    final closer = CheckPointProximityNavigationHints(
      northAbsDeltaM: 3,
      northMove: CheckPointMoveDirection.north,
      eastAbsDeltaM: 0,
      eastMove: CheckPointMoveDirection.onTarget,
      horizontalDistanceM: 3,
    );
    final near = PatrolProximityNavigationTtsState(
      lastNorth: CheckPointMoveDirection.north,
      lastEast: CheckPointMoveDirection.onTarget,
      lastAlt: null,
      lastHorizontalRounded: 3,
      lastSpokeAt: spokeAt,
    );

    expect(
      PatrolProximityNavigationTts.shouldSpeakForState(
        nav: closer,
        state: near,
        backgroundReminder: true,
        speedMps: 1.5,
        now: spokeAt.add(const Duration(seconds: 4)),
      ),
      isFalse,
    );
    expect(
      PatrolProximityNavigationTts.shouldSpeakForState(
        nav: closer,
        state: near,
        backgroundReminder: true,
        speedMps: 1.5,
        now: spokeAt.add(const Duration(seconds: 6)),
      ),
      isTrue,
    );
  });

  test('moving fast does not re-prompt on every meter of travel', () {
    // 5 m/s → distance step ~15m, so a 5m change stays silent within interval.
    final moved = CheckPointProximityNavigationHints(
      northAbsDeltaM: 7,
      northMove: CheckPointMoveDirection.north,
      eastAbsDeltaM: 5,
      eastMove: CheckPointMoveDirection.east,
      horizontalDistanceM: 10,
    );

    expect(
      PatrolProximityNavigationTts.shouldSpeakForState(
        nav: moved,
        state: remembered,
        speedMps: 5,
        now: spokeAt.add(const Duration(seconds: 6)),
      ),
      isFalse,
    );
  });
}
