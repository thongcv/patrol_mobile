abstract final class PatrolApiEndpoints {
  PatrolApiEndpoints._();

  static const String accountsLoginPath = '/accounts/login';
  static const String accountsRefreshPath = '/accounts/refresh';
  static const String accountsMePath = '/accounts/me';
  static const String accountsAvatarPath = '/accounts/avatar';
  static const String storagePresignPath = '/storage/presign';
  static const String storageConfirmPath = '/storage/confirm';
  static const String publicPresignPath = '/public/presign';
  static const String accountsUserInfoPath = '/accounts/user-info';
  static const String sitesAccessiblePath = '/sites/accessible';
  static const String issuesPath = '/issues';
  static const String issuesMyPostedViewPath = '/issues/my-posted-view';
  static String issuesAssignmentsPath(int issueId) =>
      '/issues/$issueId/assignments';
  static const String patrolRoundsSearchViewPath = '/patrol-rounds/search-view';
}
