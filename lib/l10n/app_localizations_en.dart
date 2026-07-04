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
  String get locationTitle => 'GPS & always-on location';

  @override
  String get locationBody =>
      'Turn on location services and choose \"Always allow\" so patrol tracking works when the screen is off.';

  @override
  String get locationServiceOff => 'Location services (GPS) are turned off.';

  @override
  String get locationPermissionDenied => 'Location permission was not granted.';

  @override
  String get locationPermissionBackground =>
      'Only \"While using the app\" was granted. Choose \"Always allow\" for background patrol.';

  @override
  String get locationPermissionForever =>
      'Location permission permanently denied. Open app settings to enable.';

  @override
  String get notificationPermissionDenied =>
      'Notifications are disabled. Enable them in app settings to get next-round alerts when the app is closed.';

  @override
  String get dndPolicyPermissionDenied =>
      'Do Not Disturb access was not granted. Allow SPS Patrol to modify notification policy so next-round popups can break through silent mode.';

  @override
  String get openLocationSettings => 'Open location settings';

  @override
  String get openAppSettings => 'Open app settings';

  @override
  String get openDndPolicySettings => 'Open Do Not Disturb settings';

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
  String get historySubtitle => 'List of past patrol rounds';

  @override
  String get historyEmpty => 'No patrol history yet.';

  @override
  String get historyInDevelopment => 'This feature is under development.';

  @override
  String get historyColWindow => 'Time window';

  @override
  String get historyColAssignee => 'Patrol officer';

  @override
  String get historyColAssignees => 'Assignees';

  @override
  String get historyColSite => 'Area';

  @override
  String get historyColUpdated => 'Updated at';

  @override
  String get historyStatusCompleted => 'Completed';

  @override
  String get historyStatusMissed => 'Missed';

  @override
  String get historyStatusInProgress => 'In progress';

  @override
  String get historyStatusPending => 'Pending';

  @override
  String get historyStatusCancelled => 'Cancelled';

  @override
  String historyRoundFallback(int id) {
    return 'Round #$id';
  }

  @override
  String historyShowingRange(int from, int to, int total) {
    return 'SHOWING $from-$to / $total RECORDS';
  }

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
  String get profileFieldNote => 'Note';

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
  String get profileLanguageHeading => 'Language';

  @override
  String get profileSave => 'Save';

  @override
  String get profileSaveSuccess => 'Profile updated.';

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
  String get patrolRoundMap => 'Route map';

  @override
  String get patrolRoundMapYou => 'You';

  @override
  String get patrolRoundMapSwipeDismiss => 'Swipe up or down to close';

  @override
  String get patrolRoundMapCheckpointScanned => 'Scanned checkpoint';

  @override
  String get patrolRoundMapCheckpointPending => 'Pending checkpoint';

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
  String get patrolRoundOverdueNoteTooltip => 'Report objective delay';

  @override
  String get patrolRoundOverdueNoteTitle => 'Objective delay';

  @override
  String get patrolRoundOverdueNoteMessage =>
      'Enter why this checkpoint could not be completed on time. The checkpoint will be marked as scanned.';

  @override
  String get patrolRoundOverdueNoteHint =>
      'e.g. elevator out of service, area blocked…';

  @override
  String get patrolRoundOverdueNoteSubmit => 'Submit';

  @override
  String get patrolRoundOverdueNotePrefix => '[Objective delay] ';

  @override
  String get patrolRoundOverdueNoteEmpty => 'Please enter a reason.';

  @override
  String get patrolRoundOverdueNoteSuccess =>
      'Checkpoint recorded with delay reason.';

  @override
  String get patrolRoundOverdueNoteFailed => 'Could not save the patrol log.';

  @override
  String get patrolRoundOverdueNoteNoGps =>
      'GPS unavailable and checkpoint has no coordinates.';

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
  String get patrolRoundAutoScan => 'Auto scan GPS';

  @override
  String get patrolRoundAutoScanBluetooth => 'Auto scan Bluetooth';

  @override
  String get patrolRoundAutoScanBluetoothNone =>
      'No checkpoints with Bluetooth left to scan on this route.';

  @override
  String get patrolRoundBluetoothWaiting => 'Searching for Bluetooth beacon…';

  @override
  String get patrolRoundBluetoothScanFailed =>
      'Could not read a nearby Bluetooth beacon.';

  @override
  String get patrolRoundAutoScanNone =>
      'No checkpoints left to scan on this route.';

  @override
  String get patrolRoundAutoScanComplete =>
      'All checkpoints on this route have been scanned.';

  @override
  String get patrolRoundResumeBackgroundScan => 'Background scan';

  @override
  String get patrolRoundPauseBackgroundScan => 'Pause background scan';

  @override
  String get patrolRoundBackgroundScanResumed => 'Background scanning resumed.';

  @override
  String get patrolRoundBackgroundScanPaused => 'Background scanning paused.';

  @override
  String get patrolRoundNfcNotFound =>
      'No checkpoint on this route matches that NFC tag.';

  @override
  String get patrolRoundNfcAlreadyScanned =>
      'This checkpoint was already scanned.';

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
  String get patrolRoundChipBluetooth => 'BT';

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
    return 'Move about $distance m closer to enter the allowed zone (radius $radius m).';
  }

  @override
  String patrolRoundQrAltitudeOutOfRange(String distance, String radius) {
    return 'Adjust altitude by about $distance m (radius $radius m).';
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
    return 'Move closer by: $delta m (radius $radius m)';
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
    return 'Adjust altitude by: $delta m (radius $radius m)';
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
  String patrolProximityTtsHint(String distance, String moves) {
    return 'Distance to checkpoint $distance meters. $moves';
  }

  @override
  String patrolProximityTtsNearCheckpoint(String distance) {
    return 'You are near the checkpoint, $distance meters away';
  }

  @override
  String patrolProximityTtsMove(String direction, String distance) {
    return 'move $direction $distance meters';
  }

  @override
  String patrolProximityTtsMoveVertical(String direction, String distance) {
    return 'move $direction $distance meters';
  }

  @override
  String get patrolProximityTtsMoveSeparator => ', ';

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
  String get patrolPointGpsMocked =>
      'Mock location detected. Disable fake GPS to assign coordinates.';

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
  String get patrolPointCheckpointCoordsLabel => 'Coordinates';

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
  String get patrolPointSiteIdLabel => 'Site ID';

  @override
  String get patrolPointBeaconUuidLabel => 'Beacon UUID';

  @override
  String get patrolPointBeaconProtocolLabel => 'Beacon programming protocol';

  @override
  String get patrolPointBeaconProtocolHm10 => 'HM-10 / FFE0 (AT commands)';

  @override
  String get patrolPointBeaconProtocolHm10Hint =>
      'TQ clones, UART service FFE0 · char FFE1';

  @override
  String get patrolPointBeaconProtocolNordic => 'Nordic nRF52 OEM';

  @override
  String get patrolPointBeaconProtocolNordicHint =>
      '21-byte write to advertisement content (7650/7651)';

  @override
  String get patrolPointBeaconProtocolJoyway => 'Joyway';

  @override
  String get patrolPointBeaconProtocolJoywayHint =>
      'Joyway JW1404 — BLE scan, pick beacon, program via UART (hold config button if connect fails)';

  @override
  String get patrolPointBeaconProtocolFeasycom => 'Feasycom (FeasyBeacon)';

  @override
  String get patrolPointBeaconProtocolMinew => 'Minew (mBeacon)';

  @override
  String get patrolPointBeaconProtocolEddystone => 'Eddystone-GATT (FEAA)';

  @override
  String get patrolPointBeaconProtocolComingSoon =>
      'Requires vendor SDK — not available in this app yet';

  @override
  String get patrolPointBeaconProtocolUnsupported =>
      'This protocol is not supported yet. Choose HM-10, Nordic nRF52, or Joyway.';

  @override
  String patrolPointBeaconProtocolUseCheckpoint(String protocol) {
    return 'Continue with checkpoint protocol ($protocol)';
  }

  @override
  String get patrolPointCompanyBeaconUuidMissing =>
      'Company beacon UUID is not configured.';

  @override
  String get patrolPointIBeaconConfigModeRequired =>
      'No configurable beacon found. Press the beacon button to enter config mode, then try again.';

  @override
  String get patrolPointIBeaconConfigureFailed =>
      'Could not program the iBeacon. Try again near the device.';

  @override
  String get patrolPointBeaconConfiguring => 'Programming beacon…';

  @override
  String get patrolPointBeaconConfiguringHint =>
      'Keep the phone close to the device. Do not leave the app.';

  @override
  String get patrolPointBeaconLoginVerifying => 'Connecting to beacon…';

  @override
  String get patrolPointBeaconLoginVerifyingHint =>
      'Checking the password. Stay close to the device.';

  @override
  String get patrolPointIBeaconWrongPassword =>
      'Beacon password/PIN was rejected. Check the password and try again.';

  @override
  String get patrolPointBeaconLoginDialogTitle => 'Log in to beacon';

  @override
  String get patrolPointBeaconPasswordDialogTitle =>
      'Beacon password (optional)';

  @override
  String get patrolPointBeaconPasswordLabel => 'Current password / PIN';

  @override
  String get patrolPointBeaconPasswordOptionalHint =>
      'Leave empty if not required';

  @override
  String get patrolPointBeaconLoginHm10Hint =>
      'HM-10 / FFE0: enter the current 6-digit PIN to unlock config. Leave empty for factory default (000000) or open config.';

  @override
  String get patrolPointBeaconLoginJoywayHint =>
      'Joyway: enter the current password to unlock the beacon (max 12 characters). Leave empty for factory default. Press the config button and stay close.';

  @override
  String get patrolPointBeaconPasswordHm10Hint =>
      'HM-10 / FFE0: enter the 6-digit PIN if the module requires it. Leave empty for factory default (000000) or open config.';

  @override
  String get patrolPointBeaconPasswordJoywayHint =>
      'Joyway: max 12 characters. This password is saved on the beacon (empty = factory default). If the beacon is new, leave empty once; if it already has a password, enter that password first. Press the config button and stay close.';

  @override
  String get patrolPointBeaconPasswordNordicHint =>
      'Nordic nRF52: password is not used for GATT programming in this app — leave empty.';

  @override
  String get patrolPointBeaconPasswordRemember =>
      'Remember password on this device';

  @override
  String get patrolPointBeaconPasswordContinue => 'Continue';

  @override
  String get patrolPointBeaconConfigurePickerTitle =>
      'Select beacon to program';

  @override
  String get patrolPointBeaconConfigurePickerHint =>
      'Only devices advertising iBeacon (UUID/Major/Minor on air). Select a device and tap Connect — keep the phone close (~1 m).';

  @override
  String get patrolPointBeaconConfigurePickerManualMacLabel =>
      'MAC from BLE Scanner';

  @override
  String get patrolPointBeaconConfigurePickerManualMacUse => 'Use MAC';

  @override
  String get patrolPointBeaconConfigurePickerScanning =>
      'Scanning Bluetooth (BLE)…';

  @override
  String patrolPointBeaconConfigurePickerScanningCount(int count) {
    return 'Scanning… $count device(s) seen';
  }

  @override
  String get patrolPointBeaconConfigurePickerJoywayFailed =>
      'Could not start Joyway scan. Enable Bluetooth, grant Location and Bluetooth permissions, rebuild the app, then tap Rescan.';

  @override
  String get patrolPointBeaconConfigurePickerEmpty =>
      'No iBeacon found. Tap Rescan and keep the phone close to the beacon (~1 m).';

  @override
  String get patrolPointBeaconConfigurePickerIBeaconSection =>
      'iBeacon (UUID in advert)';

  @override
  String get patrolPointBeaconConfigurePickerLikelyJoywaySection =>
      'Possible Joyway (press beacon button if no iBeacon row)';

  @override
  String get patrolPointBeaconConfigurePickerLikelyJoywayBadge => 'Joyway?';

  @override
  String get patrolPointBeaconConfigurePickerOtherDevicesSection =>
      'Other Bluetooth devices';

  @override
  String get patrolPointBeaconConfigurePickerConfigModeSection =>
      'Config mode (no UUID on air — press beacon button; UUID shows after programming or in normal broadcast mode)';

  @override
  String get patrolPointBeaconConfigurePickerConfigModeBadge => 'Config';

  @override
  String get patrolPointBeaconConfigurePickerRescan => 'Rescan';

  @override
  String get patrolPointBeaconConfigurePickerCompanyUuid =>
      'Company beacon UUID';

  @override
  String get patrolPointBeaconConfigurePickerOtherIBeacon =>
      'Other iBeacon (different UUID)';

  @override
  String get patrolPointBeaconConfigurePickerRecommended => 'Recommended';

  @override
  String get patrolPointBeaconConfigurePickerOther => 'Other nearby devices';

  @override
  String patrolPointBeaconConfigurePickerRssi(int rssi) {
    return 'RSSI: $rssi dBm';
  }

  @override
  String patrolPointBeaconConfigurePickerMacLabel(String mac) {
    return 'MAC: $mac';
  }

  @override
  String patrolPointBeaconConfigurePickerUuidLabel(String uuid) {
    return 'UUID: $uuid';
  }

  @override
  String patrolPointBeaconConfigurePickerMajorMinorLabel(
    String major,
    String minor,
  ) {
    return 'Major/Minor: $major/$minor';
  }

  @override
  String patrolPointBeaconConfigurePickerMacRssiLabel(String mac, int rssi) {
    return 'MAC: $mac · $rssi dBm';
  }

  @override
  String patrolPointBeaconConfigurePickerBroadcastNameLabel(String name) {
    return 'Broadcast: $name';
  }

  @override
  String get patrolPointBeaconConfigurePickerConnectable => 'Connectable';

  @override
  String patrolPointBeaconConfigurePickerProtocolLabel(String protocols) {
    return 'Protocol: $protocols';
  }

  @override
  String get patrolPointBeaconConfigurePickerProtocolUnknown =>
      'Protocol: not detected from advert (choose after connect)';

  @override
  String patrolPointBeaconConfigurePickerServicesLabel(String services) {
    return 'BLE services: $services';
  }

  @override
  String patrolPointBeaconConfigurePickerCheckpointProtocol(String protocol) {
    return 'Checkpoint protocol: $protocol';
  }

  @override
  String get patrolPointBeaconConfigurePickerConnect => 'Connect';

  @override
  String get patrolPointBeaconSettingsTitle => 'Beacon settings';

  @override
  String get patrolPointBeaconSettingsHint =>
      'Edit the values to write to the beacon, then tap Update to program the device and save this checkpoint.';

  @override
  String get patrolPointBeaconSettingsDeviceSection => 'Selected device';

  @override
  String get patrolPointBeaconSettingsDeviceName => 'Checkpoint name';

  @override
  String get patrolPointBeaconSettingsNameHint =>
      'BLE broadcast name (defaults to this checkpoint)';

  @override
  String get patrolPointBeaconSettingsNameHintJoyway =>
      'Max 12 bytes UTF-8 (Vietnamese OK, e.g. \"Điểm 1\")';

  @override
  String get patrolPointBeaconSettingsNameTooLong =>
      'Name is too long for the beacon (max 12 UTF-8 bytes).';

  @override
  String get patrolPointBeaconSettingsNewPasswordLabel => 'New beacon password';

  @override
  String get patrolPointBeaconSettingsNewPasswordHint =>
      'Leave empty to keep current password';

  @override
  String get patrolPointBeaconSettingsNewPasswordJoywayHint =>
      'Joyway: written to the beacon when you tap Update (max 12 characters). Leave empty to keep the existing password on the device.';

  @override
  String get patrolPointBeaconSettingsShowPassword => 'Show password';

  @override
  String get patrolPointBeaconSettingsRssiAt1mLabel => 'RSSI at 1 m (dBm)';

  @override
  String get patrolPointBeaconSettingsRssiAt1mHint => '-100 to 0';

  @override
  String get patrolPointBeaconSettingsTxPowerDbmLabel => 'TX power (dBm)';

  @override
  String get patrolPointBeaconSettingsAdv1Section => 'Advertising 1';

  @override
  String get patrolPointBeaconSettingsAdv1IntervalLabel =>
      'Adv 1 interval (ms)';

  @override
  String get patrolPointBeaconSettingsAdv1TimeLenLabel =>
      'Adv 1 time length (ms)';

  @override
  String get patrolPointBeaconSettingsAdv1NeverStop => 'Adv 1 never stop';

  @override
  String get patrolPointBeaconSettingsAdv2Section => 'Advertising 2';

  @override
  String get patrolPointBeaconSettingsAdv2IntervalLabel =>
      'Adv 2 interval (ms)';

  @override
  String get patrolPointBeaconSettingsAdv2TimeLenLabel =>
      'Adv 2 time length (ms)';

  @override
  String get patrolPointBeaconSettingsAdv2NeverStop => 'Adv 2 never stop';

  @override
  String get patrolPointBeaconSettingsButtonSection => 'Button';

  @override
  String get patrolPointBeaconSettingsButtonDelayLabel =>
      'Button delay for turning on (ms)';

  @override
  String get patrolPointBeaconSettingsAdvertiseButtonEvent =>
      'Advertise button event';

  @override
  String get patrolPointBeaconSettingsInvalidRssiAt1m =>
      'RSSI at 1 m must be −100 to 0 dBm.';

  @override
  String get patrolPointBeaconSettingsInvalidAdvInterval =>
      'Interval must be 100–10000 ms.';

  @override
  String get patrolPointBeaconSettingsInvalidAdvTimeLen =>
      'Enter a valid time length in ms.';

  @override
  String get patrolPointBeaconSettingsInvalidButtonDelay =>
      'Button delay must be 0–25500 ms.';

  @override
  String get patrolPointBeaconSettingsCurrentSection => 'Currently advertising';

  @override
  String get patrolPointBeaconSettingsTargetSection => 'Values to write';

  @override
  String get patrolPointBeaconSettingsMajorLabel => 'Major';

  @override
  String get patrolPointBeaconSettingsMinorLabel => 'Minor';

  @override
  String get patrolPointBeaconSettingsTxPowerLabel => 'Tx power at 1 m';

  @override
  String get patrolPointBeaconSettingsTxPowerHint => '-59 (Apple default)';

  @override
  String get patrolPointBeaconSettingsInvalidTxPower =>
      'Tx power must be −128 to 127 dBm.';

  @override
  String get patrolPointBeaconSettingsInvalidUuid =>
      'Enter a valid beacon UUID.';

  @override
  String get patrolPointBeaconSettingsInvalidMajor => 'Major must be 0–65535.';

  @override
  String get patrolPointBeaconSettingsInvalidMinor => 'Minor must be 0–65535.';

  @override
  String get patrolPointBeaconSettingsUpdate => 'Update';

  @override
  String get patrolPointCopyUuidTooltip => 'Copy UUID';

  @override
  String get patrolPointUpdateNfcTooltip => 'Assign NFC tag ID to this point';

  @override
  String get patrolPointUpdateBluetoothTooltip =>
      'Assign Bluetooth ID to this point';

  @override
  String get patrolPointChangeBluetoothTooltip =>
      'Reconfigure Bluetooth beacon for this point';

  @override
  String get patrolPointDialogSave => 'Save';

  @override
  String get patrolPointNfcDialogTitle => 'NFC tag ID';

  @override
  String get patrolPointNfcDialogHint => 'Scan a tag or enter the NFC ID';

  @override
  String get patrolPointNfcScanButton => 'Scan NFC tag';

  @override
  String get patrolPointNfcScanning => 'Hold the tag near your device…';

  @override
  String get patrolPointNfcUnavailable =>
      'NFC is not available on this device.';

  @override
  String get patrolPointNfcDisabled => 'Turn on NFC in your device settings.';

  @override
  String get patrolPointNfcScanFailed => 'Could not read the NFC tag.';

  @override
  String get patrolPointNfcScanTimeout => 'No tag detected. Try again.';

  @override
  String get patrolPointBluetoothDialogTitle => 'Bluetooth ID';

  @override
  String get patrolPointBluetoothDialogHint =>
      'Scan a beacon or enter MAC / UUID';

  @override
  String get patrolPointBluetoothScanButton => 'Scan nearby beacon';

  @override
  String get patrolPointBluetoothScanning => 'Searching for Bluetooth beacons…';

  @override
  String get patrolPointBluetoothUnavailable =>
      'Bluetooth is not available on this device.';

  @override
  String get patrolPointBluetoothDisabled =>
      'Turn on Bluetooth in your device settings.';

  @override
  String get patrolPointBluetoothPermissionDenied =>
      'Bluetooth permission was not granted.';

  @override
  String get patrolPointBluetoothScanFailed => 'Could not scan for beacons.';

  @override
  String get patrolPointBluetoothScanTimeout =>
      'No beacon detected. Try again.';

  @override
  String patrolPointBluetoothScanSummary(int rssi, String distance) {
    return 'Signal: $rssi dBm · Distance: ~$distance m';
  }

  @override
  String patrolPointBluetoothScanMeta(
    String address,
    String major,
    String minor,
  ) {
    return 'MAC: $address · Major: $major · Minor: $minor';
  }

  @override
  String patrolPointBluetoothScanName(String name) {
    return 'Name: $name';
  }

  @override
  String get patrolPointIdentifierEmpty => 'ID cannot be empty.';

  @override
  String patrolPointNfcValue(String value) {
    return 'NFC: $value';
  }

  @override
  String patrolPointBluetoothValue(String value) {
    return 'Bluetooth: $value';
  }

  @override
  String get patrolPointFieldUpdateSuccess => 'Updated.';

  @override
  String get patrolPointFieldUpdateFailed => 'Could not update.';

  @override
  String get patrolPointCheckpointMetaChange => 'Change';

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

  @override
  String get patrolTrackMockGpsTitle => 'FAKE GPS ALERT';

  @override
  String get patrolTrackMockGpsBody =>
      'Mock location detected. Disable fake GPS apps and continue a valid patrol.';

  @override
  String get patrolBackgroundNotificationTitle => 'SPS Notification';

  @override
  String get patrolBackgroundNotificationInitialContent =>
      'Patrol in progress — realtime location';

  @override
  String get patrolBackgroundNotificationContent =>
      'Sending realtime patrol location';

  @override
  String patrolBackgroundCheckpointScanned(String name) {
    return 'Scanned: $name';
  }

  @override
  String get patrolBackgroundLocationTitle => 'Background location required';

  @override
  String get patrolBackgroundLocationBody =>
      'Allow \"Always\" location so patrol tracking and checkpoint auto-scan continue when the screen is off or the app is in the background.';

  @override
  String get patrolBackgroundLocationGrantAlways => 'Allow always';

  @override
  String get patrolBackgroundNextRoundTitle => 'Next patrol round';

  @override
  String get patrolBackgroundNextRoundBody =>
      'The next patrol round is ready. Tap Confirm to auto-scan, or Cancel.';

  @override
  String get patrolBackgroundNextRoundActionOk => 'Confirm';

  @override
  String get patrolBackgroundNextRoundActionCancel => 'Cancel';

  @override
  String get patrolBackgroundNextRoundConfirmed =>
      'Confirmed — background auto-scan started.';

  @override
  String get patrolBackgroundRoundCompleted => 'Your patrol round has ended.';

  @override
  String get issuesTitle => 'Issues';

  @override
  String get issuesListTitle => 'Issues I reported';

  @override
  String get issuesListSubtitle => 'List of issues created by your account';

  @override
  String get issuesEmpty => 'No issues reported yet.';

  @override
  String get issuesReportAction => 'Report issue';

  @override
  String get issuesReportTitle => 'Report issue';

  @override
  String get issuesDetailAction => 'Details';

  @override
  String get issuesEditAction => 'Update';

  @override
  String get issuesEditTitle => 'Update issue';

  @override
  String get issuesCancel => 'Cancel';

  @override
  String get issuesSubmit => 'Send report';

  @override
  String get issuesUpdateSubmit => 'Save changes';

  @override
  String get issuesFieldTitle => 'Issue title';

  @override
  String get issuesFieldTitleHint => 'Short description of the issue';

  @override
  String get issuesFieldDescription => 'Detailed description';

  @override
  String get issuesFieldDescriptionHint => 'Full description of what happened';

  @override
  String get issuesFieldAssignee => 'Assignee';

  @override
  String get issuesFieldAssigneeHint => 'Assignee name';

  @override
  String get issuesFieldNote => 'Initial note';

  @override
  String get issuesFieldNoteHint => 'Reason or instructions for the recipient';

  @override
  String get issuesFieldSite => 'Area (optional)';

  @override
  String get issuesFieldSiteHint => '— Select area —';

  @override
  String get issuesFieldPhotos => 'Attached images';

  @override
  String get issuesFieldPhotosHint => 'Select images (max 5 files)';

  @override
  String get issuesColAssignee => 'Assignee';

  @override
  String get issuesColSite => 'Area';

  @override
  String get issuesColReportedAt => 'Reported at';

  @override
  String get issuesStatusOpen => 'New';

  @override
  String get issuesStatusResolved => 'Resolved';

  @override
  String get issuesTitleRequired => 'Please enter an issue title.';

  @override
  String get issuesAssigneeRequired => 'Please enter an assignee account.';

  @override
  String issuesShowingRange(int from, int to, int total) {
    return 'SHOWING $from-$to / $total RECORDS';
  }
}
