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

  test('background mode re-prompts on interval even when standing still', () {
    expect(
      PatrolProximityNavigationTts.shouldSpeakForState(
        nav: nav,
        state: remembered,
        backgroundReminder: true,
        now: spokeAt.add(const Duration(seconds: 9)),
      ),
      isFalse,
    );
    expect(
      PatrolProximityNavigationTts.shouldSpeakForState(
        nav: nav,
        state: remembered,
        backgroundReminder: true,
        now: spokeAt.add(const Duration(seconds: 10)),
      ),
      isTrue,
    );
  });

  test('background mode speaks sooner when distance changes', () {
    final closer = CheckPointProximityNavigationHints(
      northAbsDeltaM: 8,
      northMove: CheckPointMoveDirection.north,
      eastAbsDeltaM: 4,
      eastMove: CheckPointMoveDirection.east,
      horizontalDistanceM: 11,
    );

    expect(
      PatrolProximityNavigationTts.shouldSpeakForState(
        nav: closer,
        state: remembered,
        backgroundReminder: true,
        now: spokeAt.add(const Duration(seconds: 3)),
      ),
      isTrue,
    );
  });
}
