import 'package:flutter_test/flutter_test.dart';
import 'package:sps/utils/patrol_round_status.dart';

void main() {
  group('PatrolRoundStatus.isPendingOrInProgress', () {
    test('accepts PENDING and in-progress variants', () {
      expect(PatrolRoundStatus.isPendingOrInProgress('PENDING'), isTrue);
      expect(PatrolRoundStatus.isPendingOrInProgress('pending'), isTrue);
      expect(PatrolRoundStatus.isPendingOrInProgress('IN_PROGRESS'), isTrue);
      expect(PatrolRoundStatus.isPendingOrInProgress('INPROGRESS'), isTrue);
    });

    test('rejects ended and other statuses', () {
      expect(PatrolRoundStatus.isPendingOrInProgress('COMPLETED'), isFalse);
      expect(PatrolRoundStatus.isPendingOrInProgress('CANCELLED'), isFalse);
      expect(PatrolRoundStatus.isPendingOrInProgress('ACTIVE'), isFalse);
      expect(PatrolRoundStatus.isPendingOrInProgress(''), isFalse);
    });
  });
}
