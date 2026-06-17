/// Patrol round `status` values from GET `/me/active`.
abstract final class PatrolRoundStatus {
  PatrolRoundStatus._();

  static String normalize(String status) => status.trim().toUpperCase();

  /// FGS auto-scan and next-round notify only run in these states.
  static bool isPendingOrInProgress(String status) {
    final normalized = normalize(status);
    return normalized == 'PENDING' ||
        normalized == 'IN_PROGRESS' ||
        normalized == 'INPROGRESS';
  }

  static bool isEnded(String status) {
    final normalized = normalize(status);
    return normalized == 'COMPLETED' ||
        normalized == 'CANCELLED' ||
        normalized == 'CANCELED';
  }
}
