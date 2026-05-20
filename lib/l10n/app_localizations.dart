import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @langViShort.
  ///
  /// In en, this message translates to:
  /// **'VI'**
  String get langViShort;

  /// No description provided for @langEnShort.
  ///
  /// In en, this message translates to:
  /// **'EN'**
  String get langEnShort;

  /// No description provided for @badgeText.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE PROTECTION'**
  String get badgeText;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'SYSTEMS ACCESS'**
  String get title;

  /// No description provided for @forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'RESET PASSWORD'**
  String get forgotTitle;

  /// No description provided for @loginSub.
  ///
  /// In en, this message translates to:
  /// **'Multi-layer security sign-in'**
  String get loginSub;

  /// No description provided for @forgotSub.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to receive a temporary password'**
  String get forgotSub;

  /// No description provided for @placeholderUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get placeholderUsername;

  /// No description provided for @placeholderPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get placeholderPassword;

  /// No description provided for @placeholderResetEmail.
  ///
  /// In en, this message translates to:
  /// **'Registered email'**
  String get placeholderResetEmail;

  /// No description provided for @placeholderResetPhone.
  ///
  /// In en, this message translates to:
  /// **'Username or phone'**
  String get placeholderResetPhone;

  /// No description provided for @sslText.
  ///
  /// In en, this message translates to:
  /// **'SSL Encrypted'**
  String get sslText;

  /// No description provided for @forgotHint.
  ///
  /// In en, this message translates to:
  /// **'A temporary password will be sent to your email'**
  String get forgotHint;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'BACK TO SIGN IN'**
  String get backToLogin;

  /// No description provided for @portalLabel.
  ///
  /// In en, this message translates to:
  /// **'SECURE PORTAL'**
  String get portalLabel;

  /// No description provided for @copyright.
  ///
  /// In en, this message translates to:
  /// **'SPS SECURITY © 2024'**
  String get copyright;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'FORGOT PASSWORD?'**
  String get forgotPassword;

  /// No description provided for @forgotSubmit.
  ///
  /// In en, this message translates to:
  /// **'SEND REQUEST'**
  String get forgotSubmit;

  /// No description provided for @forgotSubmitLoading.
  ///
  /// In en, this message translates to:
  /// **'SENDING...'**
  String get forgotSubmitLoading;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
  String get submit;

  /// No description provided for @submitLoading.
  ///
  /// In en, this message translates to:
  /// **'VERIFYING...'**
  String get submitLoading;

  /// No description provided for @locationChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking location...'**
  String get locationChecking;

  /// No description provided for @locationTitle.
  ///
  /// In en, this message translates to:
  /// **'GPS & location required'**
  String get locationTitle;

  /// No description provided for @locationBody.
  ///
  /// In en, this message translates to:
  /// **'Patrol requires location services on and location permission before sign-in.'**
  String get locationBody;

  /// No description provided for @locationServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Location services (GPS) are turned off.'**
  String get locationServiceOff;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was not granted.'**
  String get locationPermissionDenied;

  /// No description provided for @locationPermissionForever.
  ///
  /// In en, this message translates to:
  /// **'Location permission permanently denied. Open app settings to enable.'**
  String get locationPermissionForever;

  /// No description provided for @openLocationSettings.
  ///
  /// In en, this message translates to:
  /// **'Open location settings'**
  String get openLocationSettings;

  /// No description provided for @openAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Open app settings'**
  String get openAppSettings;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @grantPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant permission'**
  String get grantPermission;

  /// No description provided for @toastApiNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'API URL not configured.'**
  String get toastApiNotConfigured;

  /// No description provided for @toastNetworkErrorShort.
  ///
  /// In en, this message translates to:
  /// **'Network error.'**
  String get toastNetworkErrorShort;

  /// No description provided for @toastUnreadableData.
  ///
  /// In en, this message translates to:
  /// **'Could not read data.'**
  String get toastUnreadableData;

  /// No description provided for @toastDialerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Cannot open dialer.'**
  String get toastDialerUnavailable;

  /// No description provided for @toastNotificationsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Notifications — coming soon'**
  String get toastNotificationsComingSoon;

  /// No description provided for @homeLoadErrorConfig.
  ///
  /// In en, this message translates to:
  /// **'API base URL is not configured.'**
  String get homeLoadErrorConfig;

  /// No description provided for @homeLoadErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server.'**
  String get homeLoadErrorNetwork;

  /// No description provided for @homeLoadErrorBadResponse.
  ///
  /// In en, this message translates to:
  /// **'Invalid server response.'**
  String get homeLoadErrorBadResponse;

  /// No description provided for @homeLoadingWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Loading your workspace…'**
  String get homeLoadingWorkspace;

  /// No description provided for @roleManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get roleManager;

  /// No description provided for @roleStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get roleStaff;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'HOME'**
  String get navHome;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'HISTORY'**
  String get navHistory;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'PROFILE'**
  String get navProfile;

  /// No description provided for @userFallbackDisplayName.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userFallbackDisplayName;

  /// No description provided for @homeSystemBanner.
  ///
  /// In en, this message translates to:
  /// **'PATROL SYSTEM'**
  String get homeSystemBanner;

  /// No description provided for @homeEmptyMenus.
  ///
  /// In en, this message translates to:
  /// **'No operations assigned.'**
  String get homeEmptyMenus;

  /// No description provided for @homeEmergencySupport.
  ///
  /// In en, this message translates to:
  /// **'EMERGENCY SUPPORT'**
  String get homeEmergencySupport;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Patrol history'**
  String get historyTitle;

  /// No description provided for @historyInDevelopment.
  ///
  /// In en, this message translates to:
  /// **'This feature is under development.'**
  String get historyInDevelopment;

  /// No description provided for @labelEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get labelEmail;

  /// No description provided for @profileAccountHeading.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccountHeading;

  /// No description provided for @profileFieldAccountId.
  ///
  /// In en, this message translates to:
  /// **'Account ID'**
  String get profileFieldAccountId;

  /// No description provided for @profileFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get profileFieldPhone;

  /// No description provided for @profileFieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get profileFieldAddress;

  /// No description provided for @profileFieldBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get profileFieldBranch;

  /// No description provided for @profileFieldMerchant.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get profileFieldMerchant;

  /// No description provided for @profileManagerHeading.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get profileManagerHeading;

  /// No description provided for @profileFieldFullName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileFieldFullName;

  /// No description provided for @profileFieldManagerPhone.
  ///
  /// In en, this message translates to:
  /// **'Manager phone'**
  String get profileFieldManagerPhone;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign out failed.'**
  String get signOutFailed;

  /// No description provided for @signOutSessionInvalid.
  ///
  /// In en, this message translates to:
  /// **'Session invalid or expired.'**
  String get signOutSessionInvalid;

  /// No description provided for @patrolRoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Patrol round'**
  String get patrolRoundTitle;

  /// No description provided for @patrolRoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shift & route'**
  String get patrolRoundSubtitle;

  /// No description provided for @patrolRoundSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Patrol workflow'**
  String get patrolRoundSectionTitle;

  /// No description provided for @patrolRoundPlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'Shift list, checklist and reporting will be integrated here.'**
  String get patrolRoundPlaceholderBody;

  /// No description provided for @patrolRoundReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get patrolRoundReload;

  /// No description provided for @patrolRoundLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading active patrol…'**
  String get patrolRoundLoading;

  /// No description provided for @patrolRoundLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load patrol round.'**
  String get patrolRoundLoadFailed;

  /// No description provided for @patrolRoundUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Session expired or forbidden.'**
  String get patrolRoundUnauthorized;

  /// No description provided for @patrolRoundEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active patrol round right now.'**
  String get patrolRoundEmpty;

  /// No description provided for @patrolRoundScheduleHeading.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get patrolRoundScheduleHeading;

  /// No description provided for @patrolRoundRoundHeading.
  ///
  /// In en, this message translates to:
  /// **'Patrol round'**
  String get patrolRoundRoundHeading;

  /// No description provided for @patrolRoundRouteHeading.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get patrolRoundRouteHeading;

  /// No description provided for @patrolRoundShiftWindow.
  ///
  /// In en, this message translates to:
  /// **'Time window'**
  String get patrolRoundShiftWindow;

  /// No description provided for @patrolRoundEffective.
  ///
  /// In en, this message translates to:
  /// **'Effective'**
  String get patrolRoundEffective;

  /// No description provided for @patrolRoundFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get patrolRoundFrequency;

  /// No description provided for @patrolRoundDuration.
  ///
  /// In en, this message translates to:
  /// **'Round duration'**
  String get patrolRoundDuration;

  /// No description provided for @patrolRoundMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String patrolRoundMinutes(int count);

  /// No description provided for @patrolRoundExpectedStart.
  ///
  /// In en, this message translates to:
  /// **'Expected start'**
  String get patrolRoundExpectedStart;

  /// No description provided for @patrolRoundExpectedEnd.
  ///
  /// In en, this message translates to:
  /// **'Expected end'**
  String get patrolRoundExpectedEnd;

  /// No description provided for @patrolRoundOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get patrolRoundOverdue;

  /// No description provided for @patrolRoundScanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan checkpoint QR'**
  String get patrolRoundScanQr;

  /// No description provided for @patrolRoundQrNotFound.
  ///
  /// In en, this message translates to:
  /// **'No checkpoint on this route matches that QR code.'**
  String get patrolRoundQrNotFound;

  /// No description provided for @patrolRoundQrAlreadyScanned.
  ///
  /// In en, this message translates to:
  /// **'This checkpoint was already scanned.'**
  String get patrolRoundQrAlreadyScanned;

  /// No description provided for @patrolRoundQrCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required to scan QR codes.'**
  String get patrolRoundQrCameraDenied;

  /// No description provided for @patrolRoundAutoScan.
  ///
  /// In en, this message translates to:
  /// **'Auto scan GPS'**
  String get patrolRoundAutoScan;

  /// No description provided for @patrolRoundAutoScanBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Auto scan Bluetooth'**
  String get patrolRoundAutoScanBluetooth;

  /// No description provided for @patrolRoundAutoScanBluetoothNone.
  ///
  /// In en, this message translates to:
  /// **'No checkpoints with Bluetooth left to scan on this route.'**
  String get patrolRoundAutoScanBluetoothNone;

  /// No description provided for @patrolRoundBluetoothWaiting.
  ///
  /// In en, this message translates to:
  /// **'Searching for Bluetooth beacon…'**
  String get patrolRoundBluetoothWaiting;

  /// No description provided for @patrolRoundBluetoothScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read a nearby Bluetooth beacon.'**
  String get patrolRoundBluetoothScanFailed;

  /// No description provided for @patrolRoundAutoScanNone.
  ///
  /// In en, this message translates to:
  /// **'No checkpoints left to scan on this route.'**
  String get patrolRoundAutoScanNone;

  /// No description provided for @patrolRoundAutoScanComplete.
  ///
  /// In en, this message translates to:
  /// **'All checkpoints on this route have been scanned.'**
  String get patrolRoundAutoScanComplete;

  /// No description provided for @patrolRoundNfcNotFound.
  ///
  /// In en, this message translates to:
  /// **'No checkpoint on this route matches that NFC tag.'**
  String get patrolRoundNfcNotFound;

  /// No description provided for @patrolRoundNfcAlreadyScanned.
  ///
  /// In en, this message translates to:
  /// **'This checkpoint was already scanned.'**
  String get patrolRoundNfcAlreadyScanned;

  /// No description provided for @patrolRoundAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned to'**
  String get patrolRoundAssigned;

  /// No description provided for @patrolRoundSiteId.
  ///
  /// In en, this message translates to:
  /// **'Site'**
  String get patrolRoundSiteId;

  /// No description provided for @patrolRoundScheduleTotalCheckPoints.
  ///
  /// In en, this message translates to:
  /// **'Checkpoints on schedule'**
  String get patrolRoundScheduleTotalCheckPoints;

  /// No description provided for @patrolRoundCountSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} points on route'**
  String patrolRoundCountSummary(int count);

  /// No description provided for @patrolRoundWithGpsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} with coordinates'**
  String patrolRoundWithGpsSummary(int count);

  /// No description provided for @patrolRoundWithQrSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} with QR'**
  String patrolRoundWithQrSummary(int count);

  /// No description provided for @patrolRoundStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get patrolRoundStatusPending;

  /// No description provided for @patrolRoundStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get patrolRoundStatusInProgress;

  /// No description provided for @patrolRoundStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get patrolRoundStatusCompleted;

  /// No description provided for @patrolRoundStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get patrolRoundStatusCancelled;

  /// No description provided for @patrolRoundStatusOther.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get patrolRoundStatusOther;

  /// No description provided for @patrolRoundScheduleActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get patrolRoundScheduleActive;

  /// No description provided for @patrolRoundScheduleInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get patrolRoundScheduleInactive;

  /// No description provided for @patrolRoundChipGps.
  ///
  /// In en, this message translates to:
  /// **'GPS'**
  String get patrolRoundChipGps;

  /// No description provided for @patrolRoundChipNoGps.
  ///
  /// In en, this message translates to:
  /// **'No GPS'**
  String get patrolRoundChipNoGps;

  /// No description provided for @patrolRoundChipQr.
  ///
  /// In en, this message translates to:
  /// **'QR'**
  String get patrolRoundChipQr;

  /// No description provided for @patrolRoundChipNfc.
  ///
  /// In en, this message translates to:
  /// **'NFC'**
  String get patrolRoundChipNfc;

  /// No description provided for @patrolRoundChipBluetooth.
  ///
  /// In en, this message translates to:
  /// **'BT'**
  String get patrolRoundChipBluetooth;

  /// No description provided for @patrolRoundChipScanned.
  ///
  /// In en, this message translates to:
  /// **'Scanned'**
  String get patrolRoundChipScanned;

  /// No description provided for @patrolRoundChipNotScanned.
  ///
  /// In en, this message translates to:
  /// **'Not scanned'**
  String get patrolRoundChipNotScanned;

  /// No description provided for @patrolRoundQrPhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Take photos?'**
  String get patrolRoundQrPhotoTitle;

  /// No description provided for @patrolRoundQrPhotoMessage.
  ///
  /// In en, this message translates to:
  /// **'You can attach one or more photos to this checkpoint scan.'**
  String get patrolRoundQrPhotoMessage;

  /// No description provided for @patrolRoundQrPhotoTake.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get patrolRoundQrPhotoTake;

  /// No description provided for @patrolRoundQrPhotoAddMore.
  ///
  /// In en, this message translates to:
  /// **'Add another photo'**
  String get patrolRoundQrPhotoAddMore;

  /// No description provided for @patrolRoundQrPhotoDone.
  ///
  /// In en, this message translates to:
  /// **'Continue ({count})'**
  String patrolRoundQrPhotoDone(int count);

  /// No description provided for @patrolRoundQrPhotoRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get patrolRoundQrPhotoRemove;

  /// No description provided for @patrolRoundQrPhotoSkip.
  ///
  /// In en, this message translates to:
  /// **'Continue without photo'**
  String get patrolRoundQrPhotoSkip;

  /// No description provided for @patrolRoundCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get patrolRoundCancel;

  /// No description provided for @patrolRoundQrOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'You are about {distance} m from the checkpoint (allowed {radius} m). Move closer to the saved location.'**
  String patrolRoundQrOutOfRange(String distance, String radius);

  /// No description provided for @patrolRoundQrAltitudeOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Altitude does not match the saved checkpoint (difference {distance} m, allowed {radius} m).'**
  String patrolRoundQrAltitudeOutOfRange(String distance, String radius);

  /// No description provided for @patrolRoundQrNoCheckpointGps.
  ///
  /// In en, this message translates to:
  /// **'This checkpoint has no saved coordinates. Set GPS on the point first.'**
  String get patrolRoundQrNoCheckpointGps;

  /// No description provided for @patrolRoundQrGpsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not read GPS. Enable location services and grant permission.'**
  String get patrolRoundQrGpsUnavailable;

  /// No description provided for @patrolRoundQrScanning.
  ///
  /// In en, this message translates to:
  /// **'Saving scan…'**
  String get patrolRoundQrScanning;

  /// No description provided for @patrolRoundQrScanSuccess.
  ///
  /// In en, this message translates to:
  /// **'Checkpoint scanned.'**
  String get patrolRoundQrScanSuccess;

  /// No description provided for @patrolRoundQrScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save patrol log.'**
  String get patrolRoundQrScanFailed;

  /// No description provided for @patrolRoundQrWaitingPosition.
  ///
  /// In en, this message translates to:
  /// **'Move closer to the checkpoint. GPS is updating…'**
  String get patrolRoundQrWaitingPosition;

  /// No description provided for @patrolRoundQrDistanceStatus.
  ///
  /// In en, this message translates to:
  /// **'About {distance} m away (allowed {radius} m)'**
  String patrolRoundQrDistanceStatus(String distance, String radius);

  /// No description provided for @patrolRoundQrPositionOkSaving.
  ///
  /// In en, this message translates to:
  /// **'Position OK — saving scan…'**
  String get patrolRoundQrPositionOkSaving;

  /// No description provided for @patrolRoundQrWaitingBaro.
  ///
  /// In en, this message translates to:
  /// **'Reading barometric altitude…'**
  String get patrolRoundQrWaitingBaro;

  /// No description provided for @patrolRoundQrCheckpointCoords.
  ///
  /// In en, this message translates to:
  /// **'Checkpoint: {lat}, {lng}'**
  String patrolRoundQrCheckpointCoords(String lat, String lng);

  /// No description provided for @patrolRoundQrCheckpointCoordsWithAlt.
  ///
  /// In en, this message translates to:
  /// **'Checkpoint: {lat}, {lng} · alt {alt} m ({altKind})'**
  String patrolRoundQrCheckpointCoordsWithAlt(
    String lat,
    String lng,
    String alt,
    String altKind,
  );

  /// No description provided for @patrolRoundQrDeviceCoords.
  ///
  /// In en, this message translates to:
  /// **'You: {lat}, {lng}'**
  String patrolRoundQrDeviceCoords(String lat, String lng);

  /// No description provided for @patrolRoundQrDeviceCoordsWithAlt.
  ///
  /// In en, this message translates to:
  /// **'You: {lat}, {lng} · alt {alt} m ({altKind})'**
  String patrolRoundQrDeviceCoordsWithAlt(
    String lat,
    String lng,
    String alt,
    String altKind,
  );

  /// No description provided for @patrolRoundQrAltKindBaro.
  ///
  /// In en, this message translates to:
  /// **'baro'**
  String get patrolRoundQrAltKindBaro;

  /// No description provided for @patrolRoundQrAltKindGps.
  ///
  /// In en, this message translates to:
  /// **'GPS'**
  String get patrolRoundQrAltKindGps;

  /// No description provided for @patrolRoundQrAltPending.
  ///
  /// In en, this message translates to:
  /// **'reading…'**
  String get patrolRoundQrAltPending;

  /// No description provided for @patrolRoundQrAltNone.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get patrolRoundQrAltNone;

  /// No description provided for @patrolRoundQrDeltaNorth.
  ///
  /// In en, this message translates to:
  /// **'North–south: {delta} m · move {direction}'**
  String patrolRoundQrDeltaNorth(String delta, String direction);

  /// No description provided for @patrolRoundQrDeltaEast.
  ///
  /// In en, this message translates to:
  /// **'East–west: {delta} m · move {direction}'**
  String patrolRoundQrDeltaEast(String delta, String direction);

  /// No description provided for @patrolRoundQrDeltaHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Distance to checkpoint: {delta} m (max {radius} m)'**
  String patrolRoundQrDeltaHorizontal(String delta, String radius);

  /// No description provided for @patrolRoundQrGpsAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Horizontal GPS accuracy ±{accuracy} m'**
  String patrolRoundQrGpsAccuracy(String accuracy);

  /// No description provided for @patrolRoundQrGpsAltitudeAccuracy.
  ///
  /// In en, this message translates to:
  /// **'GPS altitude accuracy ±{accuracy} m'**
  String patrolRoundQrGpsAltitudeAccuracy(String accuracy);

  /// No description provided for @patrolRoundQrDeltaAltitude.
  ///
  /// In en, this message translates to:
  /// **'Δ altitude: {delta} m (max {radius} m)'**
  String patrolRoundQrDeltaAltitude(String delta, String radius);

  /// No description provided for @patrolRoundQrMoveNorth.
  ///
  /// In en, this message translates to:
  /// **'north'**
  String get patrolRoundQrMoveNorth;

  /// No description provided for @patrolRoundQrMoveSouth.
  ///
  /// In en, this message translates to:
  /// **'south'**
  String get patrolRoundQrMoveSouth;

  /// No description provided for @patrolRoundQrMoveEast.
  ///
  /// In en, this message translates to:
  /// **'east'**
  String get patrolRoundQrMoveEast;

  /// No description provided for @patrolRoundQrMoveWest.
  ///
  /// In en, this message translates to:
  /// **'west'**
  String get patrolRoundQrMoveWest;

  /// No description provided for @patrolRoundQrMoveUp.
  ///
  /// In en, this message translates to:
  /// **'up'**
  String get patrolRoundQrMoveUp;

  /// No description provided for @patrolRoundQrMoveDown.
  ///
  /// In en, this message translates to:
  /// **'down'**
  String get patrolRoundQrMoveDown;

  /// No description provided for @patrolRoundQrMoveOnTarget.
  ///
  /// In en, this message translates to:
  /// **'on target'**
  String get patrolRoundQrMoveOnTarget;

  /// No description provided for @patrolRoundSubtitleActive.
  ///
  /// In en, this message translates to:
  /// **'{scheduleName} · {statusLabel}'**
  String patrolRoundSubtitleActive(String scheduleName, String statusLabel);

  /// No description provided for @patrolPointTitle.
  ///
  /// In en, this message translates to:
  /// **'Point location'**
  String get patrolPointTitle;

  /// No description provided for @patrolPointSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Field positioning'**
  String get patrolPointSubtitle;

  /// No description provided for @patrolPointSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Patrol content'**
  String get patrolPointSectionTitle;

  /// No description provided for @patrolPointPlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'This screen will show the map and patrol points. API and GPS flows will plug in here.'**
  String get patrolPointPlaceholderBody;

  /// No description provided for @patrolPointPointsHeading.
  ///
  /// In en, this message translates to:
  /// **'Site check points'**
  String get patrolPointPointsHeading;

  /// No description provided for @patrolPointReload.
  ///
  /// In en, this message translates to:
  /// **'Reload list'**
  String get patrolPointReload;

  /// No description provided for @patrolPointListLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading list…'**
  String get patrolPointListLoading;

  /// No description provided for @patrolPointEmpty.
  ///
  /// In en, this message translates to:
  /// **'No check points for this site.'**
  String get patrolPointEmpty;

  /// No description provided for @patrolPointLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load check points.'**
  String get patrolPointLoadFailed;

  /// No description provided for @patrolPointUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Session expired or forbidden.'**
  String get patrolPointUnauthorized;

  /// No description provided for @patrolPointDeviceLocationHeading.
  ///
  /// In en, this message translates to:
  /// **'Device position (GPS)'**
  String get patrolPointDeviceLocationHeading;

  /// No description provided for @patrolPointGpsLoading.
  ///
  /// In en, this message translates to:
  /// **'Getting location…'**
  String get patrolPointGpsLoading;

  /// No description provided for @patrolPointGpsTapRefresh.
  ///
  /// In en, this message translates to:
  /// **'No coordinates yet — tap the icon to retry'**
  String get patrolPointGpsTapRefresh;

  /// No description provided for @patrolPointGpsServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are off.'**
  String get patrolPointGpsServiceOff;

  /// No description provided for @patrolPointGpsDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied.'**
  String get patrolPointGpsDenied;

  /// No description provided for @patrolPointGpsError.
  ///
  /// In en, this message translates to:
  /// **'Could not read position.'**
  String get patrolPointGpsError;

  /// No description provided for @patrolPointCountSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} points total'**
  String patrolPointCountSummary(int count);

  /// No description provided for @patrolPointMissingCoordsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} points without coordinates on server'**
  String patrolPointMissingCoordsSummary(int count);

  /// No description provided for @patrolPointServerNoCoords.
  ///
  /// In en, this message translates to:
  /// **'No coordinates'**
  String get patrolPointServerNoCoords;

  /// No description provided for @patrolPointServerCoords.
  ///
  /// In en, this message translates to:
  /// **'Current position: {lat}, {lng}'**
  String patrolPointServerCoords(String lat, String lng);

  /// No description provided for @patrolPointServerCoordsWithAlt.
  ///
  /// In en, this message translates to:
  /// **'Current position: {lat}, {lng} · altitude {alt} m'**
  String patrolPointServerCoordsWithAlt(String lat, String lng, String alt);

  /// No description provided for @patrolPointInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get patrolPointInactive;

  /// No description provided for @patrolPointUpdateCoordsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send current GPS to this point'**
  String get patrolPointUpdateCoordsTooltip;

  /// No description provided for @patrolPointUpdateNeedGps.
  ///
  /// In en, this message translates to:
  /// **'Could not get a GPS fix — enable location services and grant permission.'**
  String get patrolPointUpdateNeedGps;

  /// No description provided for @patrolPointUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Coordinates updated.'**
  String get patrolPointUpdateSuccess;

  /// No description provided for @patrolPointUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update coordinates.'**
  String get patrolPointUpdateFailed;

  /// No description provided for @patrolPointSiteAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get patrolPointSiteAddressLabel;

  /// No description provided for @patrolPointUpdateNfcTooltip.
  ///
  /// In en, this message translates to:
  /// **'Assign NFC tag ID to this point'**
  String get patrolPointUpdateNfcTooltip;

  /// No description provided for @patrolPointUpdateBluetoothTooltip.
  ///
  /// In en, this message translates to:
  /// **'Assign Bluetooth ID to this point'**
  String get patrolPointUpdateBluetoothTooltip;

  /// No description provided for @patrolPointDialogSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get patrolPointDialogSave;

  /// No description provided for @patrolPointNfcDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'NFC tag ID'**
  String get patrolPointNfcDialogTitle;

  /// No description provided for @patrolPointNfcDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Scan a tag or enter the NFC ID'**
  String get patrolPointNfcDialogHint;

  /// No description provided for @patrolPointNfcScanButton.
  ///
  /// In en, this message translates to:
  /// **'Scan NFC tag'**
  String get patrolPointNfcScanButton;

  /// No description provided for @patrolPointNfcScanning.
  ///
  /// In en, this message translates to:
  /// **'Hold the tag near your device…'**
  String get patrolPointNfcScanning;

  /// No description provided for @patrolPointNfcUnavailable.
  ///
  /// In en, this message translates to:
  /// **'NFC is not available on this device.'**
  String get patrolPointNfcUnavailable;

  /// No description provided for @patrolPointNfcDisabled.
  ///
  /// In en, this message translates to:
  /// **'Turn on NFC in your device settings.'**
  String get patrolPointNfcDisabled;

  /// No description provided for @patrolPointNfcScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the NFC tag.'**
  String get patrolPointNfcScanFailed;

  /// No description provided for @patrolPointNfcScanTimeout.
  ///
  /// In en, this message translates to:
  /// **'No tag detected. Try again.'**
  String get patrolPointNfcScanTimeout;

  /// No description provided for @patrolPointBluetoothDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth ID'**
  String get patrolPointBluetoothDialogTitle;

  /// No description provided for @patrolPointBluetoothDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Scan a beacon or enter MAC / UUID'**
  String get patrolPointBluetoothDialogHint;

  /// No description provided for @patrolPointBluetoothScanButton.
  ///
  /// In en, this message translates to:
  /// **'Scan nearby beacon'**
  String get patrolPointBluetoothScanButton;

  /// No description provided for @patrolPointBluetoothScanning.
  ///
  /// In en, this message translates to:
  /// **'Searching for Bluetooth beacons…'**
  String get patrolPointBluetoothScanning;

  /// No description provided for @patrolPointBluetoothUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is not available on this device.'**
  String get patrolPointBluetoothUnavailable;

  /// No description provided for @patrolPointBluetoothDisabled.
  ///
  /// In en, this message translates to:
  /// **'Turn on Bluetooth in your device settings.'**
  String get patrolPointBluetoothDisabled;

  /// No description provided for @patrolPointBluetoothPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth permission was not granted.'**
  String get patrolPointBluetoothPermissionDenied;

  /// No description provided for @patrolPointBluetoothScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not scan for beacons.'**
  String get patrolPointBluetoothScanFailed;

  /// No description provided for @patrolPointBluetoothScanTimeout.
  ///
  /// In en, this message translates to:
  /// **'No beacon detected. Try again.'**
  String get patrolPointBluetoothScanTimeout;

  /// No description provided for @patrolPointBluetoothScanSummary.
  ///
  /// In en, this message translates to:
  /// **'Signal: {rssi} dBm · Distance: ~{distance} m'**
  String patrolPointBluetoothScanSummary(int rssi, String distance);

  /// No description provided for @patrolPointBluetoothScanMeta.
  ///
  /// In en, this message translates to:
  /// **'MAC: {address} · Major: {major} · Minor: {minor}'**
  String patrolPointBluetoothScanMeta(
    String address,
    String major,
    String minor,
  );

  /// No description provided for @patrolPointBluetoothScanName.
  ///
  /// In en, this message translates to:
  /// **'Name: {name}'**
  String patrolPointBluetoothScanName(String name);

  /// No description provided for @patrolPointIdentifierEmpty.
  ///
  /// In en, this message translates to:
  /// **'ID cannot be empty.'**
  String get patrolPointIdentifierEmpty;

  /// No description provided for @patrolPointNfcValue.
  ///
  /// In en, this message translates to:
  /// **'NFC: {value}'**
  String patrolPointNfcValue(String value);

  /// No description provided for @patrolPointBluetoothValue.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth: {value}'**
  String patrolPointBluetoothValue(String value);

  /// No description provided for @patrolPointFieldUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Updated.'**
  String get patrolPointFieldUpdateSuccess;

  /// No description provided for @patrolPointFieldUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update.'**
  String get patrolPointFieldUpdateFailed;

  /// No description provided for @patrolPointCheckpointMetaChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get patrolPointCheckpointMetaChange;

  /// No description provided for @featureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Feature coming soon'**
  String get featureComingSoon;

  /// No description provided for @apiBaseMissing.
  ///
  /// In en, this message translates to:
  /// **'API not configured: set API_BASE_URL or AppConfig.devFallbackBaseUrl'**
  String get apiBaseMissing;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Check credentials or server.'**
  String get loginFailed;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check API URL and connectivity.'**
  String get networkError;

  /// No description provided for @forgotRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent. Check your email.'**
  String get forgotRequestSent;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
