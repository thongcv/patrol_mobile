// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get langViShort => 'VI';

  @override
  String get langEnShort => 'EN';

  @override
  String get badgeText => 'ACTIVE PROTECTION';

  @override
  String get title => 'SYSTEMS ACCESS';

  @override
  String get forgotTitle => 'RESET PASSWORD';

  @override
  String get loginSub => 'Multi-layer security sign-in';

  @override
  String get forgotSub => 'Enter your email to receive a temporary password';

  @override
  String get placeholderUsername => 'Username';

  @override
  String get placeholderPassword => 'Password';

  @override
  String get placeholderResetEmail => 'Registered email';

  @override
  String get placeholderResetPhone => 'Username or phone';

  @override
  String get sslText => 'SSL Encrypted';

  @override
  String get forgotHint => 'A temporary password will be sent to your email';

  @override
  String get backToLogin => 'BACK TO SIGN IN';

  @override
  String get portalLabel => 'SECURE PORTAL';

  @override
  String get copyright => 'SPS SECURITY © 2024';

  @override
  String get forgotPassword => 'FORGOT PASSWORD?';

  @override
  String get forgotSubmit => 'SEND REQUEST';

  @override
  String get forgotSubmitLoading => 'SENDING...';

  @override
  String get submit => 'SIGN IN';

  @override
  String get submitLoading => 'VERIFYING...';

  @override
  String get locationChecking => 'Checking location...';

  @override
  String get locationTitle => 'GPS & location required';

  @override
  String get locationBody =>
      'Patrol requires location services on and location permission before sign-in.';

  @override
  String get locationServiceOff => 'Location services (GPS) are turned off.';

  @override
  String get locationPermissionDenied => 'Location permission was not granted.';

  @override
  String get locationPermissionForever =>
      'Location permission permanently denied. Open app settings to enable.';

  @override
  String get openLocationSettings => 'Open location settings';

  @override
  String get openAppSettings => 'Open app settings';

  @override
  String get retry => 'Try again';

  @override
  String get grantPermission => 'Grant permission';

  @override
  String get toastApiNotConfigured => 'API URL not configured.';

  @override
  String get toastNetworkErrorShort => 'Network error.';

  @override
  String get toastUnreadableData => 'Could not read data.';

  @override
  String get toastDialerUnavailable => 'Cannot open dialer.';

  @override
  String get toastNotificationsComingSoon => 'Notifications — coming soon';

  @override
  String get homeLoadErrorConfig => 'API base URL is not configured.';

  @override
  String get homeLoadErrorNetwork => 'Could not reach the server.';

  @override
  String get homeLoadErrorBadResponse => 'Invalid server response.';

  @override
  String get homeLoadingWorkspace => 'Loading your workspace…';

  @override
  String get roleManager => 'Manager';

  @override
  String get roleStaff => 'Staff';

  @override
  String get navHome => 'HOME';

  @override
  String get navHistory => 'HISTORY';

  @override
  String get navProfile => 'PROFILE';

  @override
  String get userFallbackDisplayName => 'User';

  @override
  String get homeSystemBanner => 'PATROL SYSTEM';

  @override
  String get homeEmptyMenus => 'No operations assigned.';

  @override
  String get homeEmergencySupport => 'EMERGENCY SUPPORT';

  @override
  String get historyTitle => 'Patrol history';

  @override
  String get historyInDevelopment => 'This feature is under development.';

  @override
  String get labelEmail => 'Email';

  @override
  String get profileAccountHeading => 'Account';

  @override
  String get profileFieldAccountId => 'Account ID';

  @override
  String get profileFieldPhone => 'Phone';

  @override
  String get profileFieldAddress => 'Address';

  @override
  String get profileFieldBranch => 'Branch';

  @override
  String get profileFieldMerchant => 'Merchant';

  @override
  String get profileManagerHeading => 'Manager';

  @override
  String get profileFieldFullName => 'Name';

  @override
  String get profileFieldManagerPhone => 'Manager phone';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutFailed => 'Sign out failed.';

  @override
  String get signOutSessionInvalid => 'Session invalid or expired.';

  @override
  String get patrolRoundTitle => 'Patrol round';

  @override
  String get patrolRoundSubtitle => 'Shift & route';

  @override
  String get patrolRoundSectionTitle => 'Patrol workflow';

  @override
  String get patrolRoundPlaceholderBody =>
      'Shift list, checklist and reporting will be integrated here.';

  @override
  String get patrolRoundReload => 'Reload';

  @override
  String get patrolRoundLoading => 'Loading active patrol…';

  @override
  String get patrolRoundLoadFailed => 'Could not load patrol round.';

  @override
  String get patrolRoundUnauthorized => 'Session expired or forbidden.';

  @override
  String get patrolRoundEmpty => 'No active patrol round right now.';

  @override
  String get patrolRoundScheduleHeading => 'Schedule';

  @override
  String get patrolRoundRoundHeading => 'Patrol round';

  @override
  String get patrolRoundRouteHeading => 'Route';

  @override
  String get patrolRoundShiftWindow => 'Time window';

  @override
  String get patrolRoundEffective => 'Effective';

  @override
  String get patrolRoundFrequency => 'Frequency';

  @override
  String get patrolRoundDuration => 'Round duration';

  @override
  String patrolRoundMinutes(int count) {
    return '$count min';
  }

  @override
  String get patrolRoundExpectedStart => 'Expected start';

  @override
  String get patrolRoundExpectedEnd => 'Expected end';

  @override
  String get patrolRoundOverdue => 'Overdue';

  @override
  String get patrolRoundScanQr => 'Scan checkpoint QR';

  @override
  String get patrolRoundQrNotFound =>
      'No checkpoint on this route matches that QR code.';

  @override
  String get patrolRoundQrAlreadyScanned =>
      'This checkpoint was already scanned.';

  @override
  String get patrolRoundQrCameraDenied =>
      'Camera permission is required to scan QR codes.';

  @override
  String get patrolRoundAutoScan => 'Auto scan';

  @override
  String get patrolRoundAutoScanNone =>
      'No checkpoints left to scan on this route.';

  @override
  String get patrolRoundAutoScanComplete =>
      'All checkpoints on this route have been scanned.';

  @override
  String get patrolRoundAssigned => 'Assigned to';

  @override
  String get patrolRoundSiteId => 'Site';

  @override
  String get patrolRoundScheduleTotalCheckPoints => 'Checkpoints on schedule';

  @override
  String patrolRoundCountSummary(int count) {
    return '$count points on route';
  }

  @override
  String patrolRoundWithGpsSummary(int count) {
    return '$count with coordinates';
  }

  @override
  String patrolRoundWithQrSummary(int count) {
    return '$count with QR';
  }

  @override
  String get patrolRoundStatusPending => 'Pending';

  @override
  String get patrolRoundStatusInProgress => 'In progress';

  @override
  String get patrolRoundStatusCompleted => 'Completed';

  @override
  String get patrolRoundStatusCancelled => 'Cancelled';

  @override
  String get patrolRoundStatusOther => 'Status';

  @override
  String get patrolRoundScheduleActive => 'Active';

  @override
  String get patrolRoundScheduleInactive => 'Inactive';

  @override
  String get patrolRoundChipGps => 'GPS';

  @override
  String get patrolRoundChipNoGps => 'No GPS';

  @override
  String get patrolRoundChipQr => 'QR';

  @override
  String get patrolRoundChipNfc => 'NFC';

  @override
  String get patrolRoundChipScanned => 'Scanned';

  @override
  String get patrolRoundChipNotScanned => 'Not scanned';

  @override
  String get patrolRoundQrPhotoTitle => 'Take photos?';

  @override
  String get patrolRoundQrPhotoMessage =>
      'You can attach one or more photos to this checkpoint scan.';

  @override
  String get patrolRoundQrPhotoTake => 'Take photo';

  @override
  String get patrolRoundQrPhotoAddMore => 'Add another photo';

  @override
  String patrolRoundQrPhotoDone(int count) {
    return 'Continue ($count)';
  }

  @override
  String get patrolRoundQrPhotoRemove => 'Remove photo';

  @override
  String get patrolRoundQrPhotoSkip => 'Continue without photo';

  @override
  String get patrolRoundCancel => 'Cancel';

  @override
  String patrolRoundQrOutOfRange(String distance, String radius) {
    return 'You are about $distance m from the checkpoint (allowed $radius m). Move closer to the saved location.';
  }

  @override
  String patrolRoundQrAltitudeOutOfRange(String distance, String radius) {
    return 'Altitude does not match the saved checkpoint (difference $distance m, allowed $radius m).';
  }

  @override
  String get patrolRoundQrNoCheckpointGps =>
      'This checkpoint has no saved coordinates. Set GPS on the point first.';

  @override
  String get patrolRoundQrGpsUnavailable =>
      'Could not read GPS. Enable location services and grant permission.';

  @override
  String get patrolRoundQrScanning => 'Saving scan…';

  @override
  String get patrolRoundQrScanSuccess => 'Checkpoint scanned.';

  @override
  String get patrolRoundQrScanFailed => 'Could not save patrol log.';

  @override
  String get patrolRoundQrWaitingPosition =>
      'Move closer to the checkpoint. GPS is updating…';

  @override
  String patrolRoundQrDistanceStatus(String distance, String radius) {
    return 'About $distance m away (allowed $radius m)';
  }

  @override
  String get patrolRoundQrPositionOkSaving => 'Position OK — saving scan…';

  @override
  String get patrolRoundQrWaitingBaro => 'Reading barometric altitude…';

  @override
  String patrolRoundQrCheckpointCoords(String lat, String lng) {
    return 'Checkpoint: $lat, $lng';
  }

  @override
  String patrolRoundQrCheckpointCoordsWithAlt(
    String lat,
    String lng,
    String alt,
    String altKind,
  ) {
    return 'Checkpoint: $lat, $lng · alt $alt m ($altKind)';
  }

  @override
  String patrolRoundQrDeviceCoords(String lat, String lng) {
    return 'You: $lat, $lng';
  }

  @override
  String patrolRoundQrDeviceCoordsWithAlt(
    String lat,
    String lng,
    String alt,
    String altKind,
  ) {
    return 'You: $lat, $lng · alt $alt m ($altKind)';
  }

  @override
  String get patrolRoundQrAltKindBaro => 'baro';

  @override
  String get patrolRoundQrAltKindGps => 'GPS';

  @override
  String get patrolRoundQrAltPending => 'reading…';

  @override
  String get patrolRoundQrAltNone => '—';

  @override
  String patrolRoundQrDeltaNorth(String delta, String direction) {
    return 'North–south: $delta m · move $direction';
  }

  @override
  String patrolRoundQrDeltaEast(String delta, String direction) {
    return 'East–west: $delta m · move $direction';
  }

  @override
  String patrolRoundQrDeltaHorizontal(String delta, String radius) {
    return 'Distance to checkpoint: $delta m (max $radius m)';
  }

  @override
  String patrolRoundQrGpsAccuracy(String accuracy) {
    return 'Horizontal GPS accuracy ±$accuracy m';
  }

  @override
  String patrolRoundQrGpsAltitudeAccuracy(String accuracy) {
    return 'GPS altitude accuracy ±$accuracy m';
  }

  @override
  String patrolRoundQrDeltaAltitude(String delta, String radius) {
    return 'Δ altitude: $delta m (max $radius m)';
  }

  @override
  String get patrolRoundQrMoveNorth => 'north';

  @override
  String get patrolRoundQrMoveSouth => 'south';

  @override
  String get patrolRoundQrMoveEast => 'east';

  @override
  String get patrolRoundQrMoveWest => 'west';

  @override
  String get patrolRoundQrMoveUp => 'up';

  @override
  String get patrolRoundQrMoveDown => 'down';

  @override
  String get patrolRoundQrMoveOnTarget => 'on target';

  @override
  String patrolRoundSubtitleActive(String scheduleName, String statusLabel) {
    return '$scheduleName · $statusLabel';
  }

  @override
  String get patrolPointTitle => 'Point location';

  @override
  String get patrolPointSubtitle => 'Field positioning';

  @override
  String get patrolPointSectionTitle => 'Patrol content';

  @override
  String get patrolPointPlaceholderBody =>
      'This screen will show the map and patrol points. API and GPS flows will plug in here.';

  @override
  String get patrolPointPointsHeading => 'Site check points';

  @override
  String get patrolPointReload => 'Reload list';

  @override
  String get patrolPointListLoading => 'Loading list…';

  @override
  String get patrolPointEmpty => 'No check points for this site.';

  @override
  String get patrolPointLoadFailed => 'Could not load check points.';

  @override
  String get patrolPointUnauthorized => 'Session expired or forbidden.';

  @override
  String get patrolPointDeviceLocationHeading => 'Device position (GPS)';

  @override
  String get patrolPointGpsLoading => 'Getting location…';

  @override
  String get patrolPointGpsTapRefresh =>
      'No coordinates yet — tap the icon to retry';

  @override
  String get patrolPointGpsServiceOff => 'Location services are off.';

  @override
  String get patrolPointGpsDenied => 'Location permission denied.';

  @override
  String get patrolPointGpsError => 'Could not read position.';

  @override
  String patrolPointCountSummary(int count) {
    return '$count points total';
  }

  @override
  String patrolPointMissingCoordsSummary(int count) {
    return '$count points without coordinates on server';
  }

  @override
  String get patrolPointServerNoCoords => 'No coordinates';

  @override
  String patrolPointServerCoords(String lat, String lng) {
    return 'Current position: $lat, $lng';
  }

  @override
  String patrolPointServerCoordsWithAlt(String lat, String lng, String alt) {
    return 'Current position: $lat, $lng · altitude $alt m';
  }

  @override
  String get patrolPointInactive => 'Inactive';

  @override
  String get patrolPointUpdateCoordsTooltip => 'Send current GPS to this point';

  @override
  String get patrolPointUpdateNeedGps =>
      'Could not get a GPS fix — enable location services and grant permission.';

  @override
  String get patrolPointUpdateSuccess => 'Coordinates updated.';

  @override
  String get patrolPointUpdateFailed => 'Could not update coordinates.';

  @override
  String get patrolPointSiteAddressLabel => 'Address';

  @override
  String get featureComingSoon => 'Feature coming soon';

  @override
  String get apiBaseMissing =>
      'API not configured: set API_BASE_URL or AppConfig.devFallbackBaseUrl';

  @override
  String get loginFailed => 'Sign-in failed. Check credentials or server.';

  @override
  String get networkError => 'Network error. Check API URL and connectivity.';

  @override
  String get forgotRequestSent => 'Request sent. Check your email.';
}
