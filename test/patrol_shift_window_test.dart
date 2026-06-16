import 'package:flutter_test/flutter_test.dart';
import 'package:sps/models/patrol_tracking_config.dart';
import 'package:sps/utils/patrol_datetime_format.dart';
import 'package:sps/utils/patrol_shift_window.dart';

void main() {
  group('parsePatrolApiInstant', () {
    test('parses UTC Z to local', () {
      const raw = '2026-06-13T10:50:00Z';
      final local = parsePatrolApiInstant(raw);
      expect(local, DateTime.parse(raw).toLocal());
    });
  });

  group('parsePatrolLocalDate', () {
    test('parses yyyy-MM-dd without timezone shift', () {
      expect(
        parsePatrolLocalDate('2026-06-13'),
        DateTime(2026, 6, 13),
      );
    });

    test('uses date part only when ISO suffix present', () {
      // LocalDate must not follow Z offset — calendar date stays 2026-06-13.
      expect(
        parsePatrolLocalDate('2026-06-13T00:00:00Z'),
        DateTime(2026, 6, 13),
      );
      expect(
        parsePatrolLocalDate('2026-06-13T17:00:00+07:00'),
        DateTime(2026, 6, 13),
      );
    });
  });

  group('formatPatrolDateOnly vs formatPatrolIsoDateTime', () {
    test('schedule LocalDate display', () {
      expect(formatPatrolDateOnly('2026-06-13'), '13/06/2026');
    });

    test('round instant display in local time', () {
      final formatted = formatPatrolIsoDateTime('2026-06-13T10:50:00Z');
      final local = parsePatrolApiInstant('2026-06-13T10:50:00Z')!;
      expect(formatted, contains('${local.day.toString().padLeft(2, '0')}/'));
      expect(formatted, contains('${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}'));
    });
  });

  group('isPatrolLocalDateInRange', () {
    test('inclusive calendar range', () {
      expect(
        isPatrolLocalDateInRange(
          now: DateTime(2026, 6, 13),
          start: '2026-06-01',
          end: '2026-06-30',
        ),
        isTrue,
      );
      expect(
        isPatrolLocalDateInRange(
          now: DateTime(2026, 7, 1),
          start: '2026-06-01',
          end: '2026-06-30',
        ),
        isFalse,
      );
    });
  });

  group('PatrolShiftWindow.isWithinWindow', () {
    test('inside round window with BE UTC Z', () {
      const start = '2026-06-13T10:50:00Z';
      const end = '2026-06-13T11:25:00Z';
      final startLocal = parsePatrolApiInstant(start)!;
      final endLocal = parsePatrolApiInstant(end)!;

      expect(
        PatrolShiftWindow.isWithinWindow(
          now: startLocal.add(const Duration(minutes: 10)),
          expectedStartTime: start,
          expectedEndTime: end,
        ),
        isTrue,
      );
      expect(
        PatrolShiftWindow.isWithinWindow(
          now: startLocal.subtract(const Duration(minutes: 14)),
          expectedStartTime: start,
          expectedEndTime: end,
        ),
        isTrue,
      );
      expect(
        PatrolShiftWindow.isWithinWindow(
          now: startLocal.subtract(const Duration(minutes: 16)),
          expectedStartTime: start,
          expectedEndTime: end,
        ),
        isFalse,
      );
      expect(
        PatrolShiftWindow.isWithinWindow(
          now: endLocal,
          expectedStartTime: start,
          expectedEndTime: end,
        ),
        isTrue,
      );
      expect(
        PatrolShiftWindow.isWithinWindow(
          now: endLocal.add(const Duration(minutes: 15)),
          expectedStartTime: start,
          expectedEndTime: end,
        ),
        isFalse,
      );
    });

    test('no bounds means unrestricted', () {
      expect(
        PatrolShiftWindow.isWithinWindow(now: DateTime(2026, 6, 14, 23, 0)),
        isTrue,
      );
    });
  });

  group('PatrolShiftWindowSnapshot.nextBoundaryAfter', () {
    test('returns end while inside BE round window', () {
      const window = PatrolShiftWindowSnapshot(
        expectedStartTime: '2026-06-13T10:50:00Z',
        expectedEndTime: '2026-06-13T11:25:00Z',
      );
      final startLocal = parsePatrolApiInstant('2026-06-13T10:50:00Z')!;
      final endLocal = parsePatrolApiInstant('2026-06-13T11:25:00Z')!;
      expect(
        window.nextBoundaryAfter(startLocal.add(const Duration(minutes: 5))),
        endLocal.add(
          const Duration(minutes: PatrolTrackingConfig.defaultShiftWindowGraceMinutes),
        ),
      );
    });

    test('fromJson ignores legacy schedule cache', () {
      final window = PatrolShiftWindowSnapshot.fromJson({
        'scheduleActive': false,
        'startTime': '08:00',
        'endTime': '17:00',
      });
      expect(window.contains(DateTime(2026, 6, 14, 23, 0)), isTrue);
    });
  });
}
