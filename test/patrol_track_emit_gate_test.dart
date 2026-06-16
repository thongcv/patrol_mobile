import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sps/models/active_patrol_round.dart';
import 'package:sps/models/check_point.dart';
import 'package:sps/models/patrol_round.dart';
import 'package:sps/models/patrol_schedule.dart';
import 'package:sps/models/patrol_tracking_config.dart';
import 'package:sps/services/patrol_active_round_cache.dart';
import 'package:sps/services/patrol_tracking_config_store.dart';
import 'package:sps/utils/patrol_datetime_format.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PatrolActiveRoundCache.invalidateTrackingEmitGateCache();
    await PatrolTrackingConfigStore.clear();
    await PatrolActiveRoundCache.save(null);
    await PatrolActiveRoundCache.setBackgroundAutoScanArmed(false);
  });

  group('isTrackLocationEmitAllowed', () {
    test('true when no round and trackByShiftWindow is false', () async {
      await PatrolTrackingConfigStore.save(
        const PatrolTrackingConfig(trackByShiftWindow: false),
      );

      expect(await PatrolActiveRoundCache.isTrackLocationEmitAllowed(), isTrue);
    });

    test('false when no round and trackByShiftWindow is true', () async {
      await PatrolTrackingConfigStore.save(
        const PatrolTrackingConfig(trackByShiftWindow: true),
      );

      expect(await PatrolActiveRoundCache.isTrackLocationEmitAllowed(), isFalse);
    });

    test('false when armed but no cached round and trackByShiftWindow is true', () async {
      await PatrolTrackingConfigStore.save(
        const PatrolTrackingConfig(
          trackByShiftWindow: true,
          backgroundAutoScan: true,
        ),
      );
      await PatrolActiveRoundCache.setBackgroundAutoScanArmed(true);

      expect(await PatrolActiveRoundCache.isTrackLocationEmitAllowed(), isFalse);
    });

    test('true with round when trackByShiftWindow is false', () async {
      await PatrolTrackingConfigStore.save(
        const PatrolTrackingConfig(trackByShiftWindow: false),
      );
      await _saveTestRound(
        expectedStartTime: '2026-06-13T10:50:00Z',
        expectedEndTime: '2026-06-13T11:25:00Z',
      );

      expect(await PatrolActiveRoundCache.isTrackLocationEmitAllowed(), isTrue);
    });

    test('true inside shift window when trackByShiftWindow is true', () async {
      await PatrolTrackingConfigStore.save(
        const PatrolTrackingConfig(trackByShiftWindow: true),
      );
      await _saveTestRound(
        expectedStartTime: '2026-06-13T10:50:00Z',
        expectedEndTime: '2026-06-13T11:25:00Z',
      );
      final startLocal = parsePatrolApiInstant('2026-06-13T10:50:00Z')!;

      expect(
        await PatrolActiveRoundCache.isTrackLocationEmitAllowed(
          now: startLocal.add(const Duration(minutes: 10)),
        ),
        isTrue,
      );
    });

    test('false outside shift window when trackByShiftWindow is true', () async {
      await PatrolTrackingConfigStore.save(
        const PatrolTrackingConfig(trackByShiftWindow: true),
      );
      await _saveTestRound(
        expectedStartTime: '2026-06-13T10:50:00Z',
        expectedEndTime: '2026-06-13T11:25:00Z',
      );
      final startLocal = parsePatrolApiInstant('2026-06-13T10:50:00Z')!;

      expect(
        await PatrolActiveRoundCache.isTrackLocationEmitAllowed(
          now: startLocal.subtract(const Duration(minutes: 16)),
        ),
        isFalse,
      );
    });

    test('true outside shift when auto-scan armed and round cached', () async {
      await PatrolTrackingConfigStore.save(
        const PatrolTrackingConfig(
          trackByShiftWindow: true,
          backgroundAutoScan: true,
        ),
      );
      await _saveTestRound(
        expectedStartTime: '2026-06-13T10:50:00Z',
        expectedEndTime: '2026-06-13T11:25:00Z',
      );
      await PatrolActiveRoundCache.setBackgroundAutoScanArmed(true);
      final startLocal = parsePatrolApiInstant('2026-06-13T10:50:00Z')!;

      expect(
        await PatrolActiveRoundCache.isTrackLocationEmitAllowed(
          now: startLocal.subtract(const Duration(minutes: 1)),
        ),
        isTrue,
      );
    });
  });
}

Future<void> _saveTestRound({
  required String expectedStartTime,
  required String expectedEndTime,
}) {
  return PatrolActiveRoundCache.save(
    ActivePatrolRound(
      schedule: PatrolSchedule(
        id: 1,
        name: 'Test schedule',
        siteId: 1,
        active: true,
      ),
      round: PatrolRound(
        id: 42,
        scheduleId: 1,
        status: 'IN_PROGRESS',
        detailStatus: 'ACTIVE',
        expectedStartTime: expectedStartTime,
        expectedEndTime: expectedEndTime,
      ),
      checkPoints: [
        CheckPoint(
          id: 1,
          siteId: 1,
          name: 'CP1',
          sequenceOrder: 1,
          active: true,
          latitude: 10.0,
          longitude: 106.0,
        ),
      ],
    ),
    preserveLocalVerified: false,
  );
}
