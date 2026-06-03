import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../background/patrol_background_constants.dart';
import '../background/patrol_background_isolate_flags.dart';
import '../background/patrol_notification_actions.dart';
import '../utils/patrol_background_plugin_registrant.dart';

/// Patrol tracking notification (Android foreground service + iOS notification center).
abstract final class PatrolForegroundNotification {
  PatrolForegroundNotification._();

  static const String _iosThreadId = 'sps_patrol_track';
  static const String _iosCheckpointThreadId = 'sps_patrol_checkpoint_scan';
  static const String _logoAsset = 'assets/images/ic_notification_logo.png';
  /// Checkpoint heads-up ids: [checkpointAlertNotificationIdBase, +100).
  static const int checkpointAlertNotificationIdBase = 881300;
  /// Dedicated block — must not overlap checkpoint ids (was 881301, collided).
  static const int nextRoundConfirmNotificationId = 882500;
  static const String _iosNextRoundCategoryId = 'sps_patrol_next_round';
  static const String _nextRoundChannelSuffix = 'v1';
  static const int _checkpointAlertIdSlots = 100;
  static const int _maxCheckpointAlertsKept = 30;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _ready = false;
  static String? _channelId;
  static String? _channelName;
  static String? _alertChannelId;
  static String? _alertChannelName;
  static String? _nextRoundHeadsUpChannelId;
  static String? _nextRoundHeadsUpChannelName;
  static String? _iosAttachmentPath;
  static var _checkpointAlertSeq = 0;
  static int? _activeNextRoundConfirmNotificationId;
  static final List<int> _activeCheckpointAlertIds = <int>[];
  static var _launchNotificationActionDrained = false;
  /// Cached after channel setup; refreshed before next-round posts on Android.
  static bool _androidBypassDndEnabled = false;

  /// Two short pulses for checkpoint-scan feedback (Android channel vibration).
  static final Int64List checkpointScanVibrationPattern =
      Int64List.fromList(<int>[0, 120, 80, 120]);

  static Future<void> ensureInitialized({
    required String channelId,
    required String channelName,
    required String channelDescription,
    String nextRoundConfirmLabel = 'Confirm',
    String nextRoundCancelLabel = 'Cancel',
  }) async {
    if (_ready &&
        _channelId == channelId &&
        _nextRoundHeadsUpChannelId != null) {
      return;
    }
    _channelId = channelId;
    _channelName = channelName;

    if (Platform.isAndroid) {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('ic_bg_service_small'),
      );
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse:
            PatrolNotificationActions.handleResponse,
        onDidReceiveBackgroundNotificationResponse:
            patrolNotificationBackgroundTap,
      );

      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.low,
        ),
      );

      _alertChannelId = '${channelId}_scan_alert';
      _alertChannelName = '$channelName — scan';
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          _alertChannelId!,
          _alertChannelName!,
          description: 'Heads-up alert when a checkpoint is scanned',
          importance: Importance.max,
          enableVibration: true,
          vibrationPattern: checkpointScanVibrationPattern,
          playSound: true,
          showBadge: true,
        ),
      );

      await ensureAndroidNotificationsEnabled();

      // Policy access must be granted before bypassDnd on the channel (plugin + OS).
      _androidBypassDndEnabled = await androidNotificationPolicyAccessGranted();
      await ensureAndroidHeadsUpPermissions(requestNotificationPolicyIfNeeded: false);

      await _setupAndroidNextRoundChannel(
        android: android,
        channelId: channelId,
        channelName: channelName,
        bypassDnd: _androidBypassDndEnabled,
        recreateCurrent: false,
      );
    } else if (Platform.isIOS) {
      final initSettings = InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              _iosNextRoundCategoryId,
              actions: <DarwinNotificationAction>[
                DarwinNotificationAction.plain(
                  PatrolNotificationActions.autoScanConfirmActionId,
                  nextRoundConfirmLabel,
                ),
                DarwinNotificationAction.plain(
                  PatrolNotificationActions.autoScanCancelActionId,
                  nextRoundCancelLabel,
                  options: {DarwinNotificationActionOption.destructive},
                ),
              ],
            ),
          ],
        ),
      );
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse:
            PatrolNotificationActions.handleResponse,
        onDidReceiveBackgroundNotificationResponse:
            patrolNotificationBackgroundTap,
      );

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: false, sound: false);
      await _ensureIosAttachment();
    }

    _ready = true;
  }

  /// Android 13+ — without this, local notifications never appear when the app is closed.
  static Future<bool> ensureAndroidNotificationsEnabled({
    bool requestIfNeeded = true,
  }) async {
    if (!Platform.isAndroid) return true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    var enabled = await android.areNotificationsEnabled() ?? false;
    if (!enabled && requestIfNeeded) {
      enabled = await android.requestNotificationsPermission() ?? false;
    }
    return enabled;
  }

  static AndroidFlutterLocalNotificationsPlugin? _androidPlugin() {
    if (!Platform.isAndroid) return null;
    return _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
  }

  /// Whether the app may set bypass-DND on notification channels (Android 6+).
  static Future<bool> androidNotificationPolicyAccessGranted() async {
    final android = _androidPlugin();
    if (android == null) return false;
    try {
      return await android.hasNotificationPolicyAccess() ?? false;
    } on Object {
      return false;
    }
  }

  /// Opens system DND-access settings when needed. Call before channels with [bypassDnd].
  static Future<bool> ensureAndroidNotificationPolicyAccess({
    bool requestIfNeeded = true,
  }) async {
    if (!Platform.isAndroid) return true;
    if (await androidNotificationPolicyAccessGranted()) return true;
    if (!requestIfNeeded) return false;
    final android = _androidPlugin();
    if (android == null) return false;
    try {
      return await android.requestNotificationPolicyAccess() ?? false;
    } on Object {
      return false;
    }
  }

  /// Full-screen / heads-up on lock screen (Android 11+); DND bypass via policy access.
  static Future<void> ensureAndroidHeadsUpPermissions({
    bool requestNotificationPolicyIfNeeded = true,
    String? nextRoundChannelName,
  }) async {
    if (!Platform.isAndroid) return;
    final android = _androidPlugin();
    if (android == null) return;
    try {
      await android.requestFullScreenIntentPermission();
    } on Object {
      //
    }
    final policyOk = await ensureAndroidNotificationPolicyAccess(
      requestIfNeeded: requestNotificationPolicyIfNeeded,
    );
    _androidBypassDndEnabled = policyOk;
    if (policyOk && nextRoundChannelName != null) {
      await prepareAndroidNextRoundPopupChannel(
        channelName: nextRoundChannelName,
      );
    }
  }

  /// Recreates next-round channel v1 with [bypassDnd] when DND policy access is granted.
  static Future<bool> prepareAndroidNextRoundPopupChannel({
    required String channelName,
    String channelId = PatrolBackgroundConstants.notificationChannelId,
  }) async {
    if (!Platform.isAndroid) return true;
    if (!await androidNotificationPolicyAccessGranted()) {
      _androidBypassDndEnabled = false;
      return false;
    }
    final android = _androidPlugin();
    if (android == null) return false;
    await _setupAndroidNextRoundChannel(
      android: android,
      channelId: channelId,
      channelName: channelName,
      bypassDnd: true,
      recreateCurrent: true,
    );
    _androidBypassDndEnabled = true;
    return true;
  }

  static String _nextRoundChannelId(String channelId) =>
      '${channelId}_next_round_popup_$_nextRoundChannelSuffix';

  /// Heads-up next-round channel (must match [MainActivity] channel id).
  static Future<void> _setupAndroidNextRoundChannel({
    required AndroidFlutterLocalNotificationsPlugin? android,
    required String channelId,
    required String channelName,
    required bool bypassDnd,
    required bool recreateCurrent,
  }) async {
    if (android == null) return;
    _channelId = channelId;
    _channelName = channelName;
    _nextRoundHeadsUpChannelId = _nextRoundChannelId(channelId);
    _nextRoundHeadsUpChannelName = '$channelName — next round alert';

    if (recreateCurrent) {
      try {
        await android.deleteNotificationChannel(_nextRoundChannelId(channelId));
      } on Object {
        //
      }
    }

    await android.createNotificationChannel(
      AndroidNotificationChannel(
        _nextRoundHeadsUpChannelId!,
        _nextRoundHeadsUpChannelName!,
        description: 'Popup on screen for the next patrol round',
        importance: Importance.max,
        bypassDnd: bypassDnd,
        enableVibration: true,
        enableLights: true,
        vibrationPattern: checkpointScanVibrationPattern,
        playSound: true,
        showBadge: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
  }

  static Future<void> _ensureIosAttachment() async {
    if (_iosAttachmentPath != null) return;
    try {
      final bytes = await rootBundle.load(_logoAsset);
      final file = File(
        '${Directory.systemTemp.path}/patrol_ic_notification_logo.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      _iosAttachmentPath = file.path;
    } catch (_) {
      _iosAttachmentPath = null;
    }
  }

  static Future<void> show({
    required int notificationId,
    required String title,
    required String body,
    bool checkpointPulse = false,
  }) async {
    if (!_ready || _channelId == null || _channelName == null) return;

    final NotificationDetails details;
    if (Platform.isAndroid) {
      final pulse = checkpointPulse && _alertChannelId != null;
      details = NotificationDetails(
        android: AndroidNotificationDetails(
          pulse ? _alertChannelId! : _channelId!,
          pulse ? _alertChannelName! : _channelName!,
          icon: 'ic_bg_service_small',
          ongoing: !pulse,
          importance: pulse ? Importance.high : Importance.low,
          priority: pulse ? Priority.high : Priority.low,
          showWhen: false,
          enableVibration: pulse,
          playSound: pulse,
          vibrationPattern: pulse ? checkpointScanVibrationPattern : null,
          onlyAlertOnce: false,
        ),
      );
    } else if (Platform.isIOS) {
      await _ensureIosAttachment();
      final path = _iosAttachmentPath;
      details = NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentBanner: checkpointPulse,
          presentList: true,
          // Short default tone when a checkpoint is scanned in background (no custom pattern on iOS).
          presentSound: checkpointPulse,
          presentBadge: false,
          threadIdentifier: _iosThreadId,
          categoryIdentifier:
              checkpointPulse ? 'sps_patrol_checkpoint_scan' : null,
          interruptionLevel: checkpointPulse
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.passive,
          attachments: path == null
              ? null
              : [DarwinNotificationAttachment(path)],
        ),
      );
    } else {
      return;
    }

    await _plugin.show(notificationId, title, body, details);
  }

  /// Heads-up + status bar alert (Shopee-style): swipe to dismiss, newest on top.
  static Future<void> showCheckpointScanAlert({
    required String title,
    required String body,
  }) async {
    if (!_ready || _alertChannelId == null || _alertChannelName == null) {
      return;
    }

    final postedAt = DateTime.now();
    final notificationId = _nextCheckpointAlertId();
    _trackCheckpointAlertId(notificationId);

    if (Platform.isAndroid) {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _alertChannelId!,
          _alertChannelName!,
          channelDescription: 'Heads-up alert when a checkpoint is scanned',
          icon: 'ic_bg_service_small',
          importance: Importance.max,
          priority: Priority.max,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.status,
          ticker: body,
          ongoing: false,
          autoCancel: true,
          onlyAlertOnce: false,
          showWhen: true,
          when: postedAt.millisecondsSinceEpoch,
          enableVibration: true,
          playSound: true,
          vibrationPattern: checkpointScanVibrationPattern,
          styleInformation: BigTextStyleInformation(body),
        ),
      );
      await _plugin.show(notificationId, title, body, details);
      await _pruneOldCheckpointAlerts();
      return;
    }

    if (Platform.isIOS) {
      await _ensureIosAttachment();
      final path = _iosAttachmentPath;
      final sortKey = (9999999999999 - postedAt.millisecondsSinceEpoch)
          .toString()
          .padLeft(13, '0');
      final details = NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentBanner: true,
          presentList: true,
          presentSound: true,
          presentBadge: false,
          threadIdentifier: _iosCheckpointThreadId,
          categoryIdentifier: 'sps_patrol_checkpoint_scan',
          interruptionLevel: InterruptionLevel.timeSensitive,
          attachments: path == null
              ? null
              : [DarwinNotificationAttachment(path)],
        ),
      );
      await _plugin.show(
        notificationId,
        title,
        body,
        details,
        payload: sortKey,
      );
      await _pruneOldCheckpointAlerts();
    }
  }

  static int _nextCheckpointAlertId() {
    _checkpointAlertSeq =
        (_checkpointAlertSeq + 1) % _checkpointAlertIdSlots;
    return checkpointAlertNotificationIdBase + _checkpointAlertSeq;
  }

  static void _trackCheckpointAlertId(int notificationId) {
    _activeCheckpointAlertIds.add(notificationId);
  }

  static Future<void> _pruneOldCheckpointAlerts() async {
    while (_activeCheckpointAlertIds.length > _maxCheckpointAlertsKept) {
      final oldest = _activeCheckpointAlertIds.removeAt(0);
      await _plugin.cancel(oldest);
    }
  }

  /// Heads-up confirm: Xác nhận → auto-scan; Hủy → dismiss.
  static Future<void> showNextRoundAutoScanConfirm({
    required String title,
    required String body,
    required String confirmLabel,
    required String cancelLabel,
  }) async {
    if (PatrolBackgroundIsolateFlags.active) {
      ensurePatrolBackgroundPlugins();
    }

    if (!_ready ||
        _nextRoundHeadsUpChannelId == null ||
        _nextRoundHeadsUpChannelName == null) {
      return;
    }

    final postedAt = DateTime.now();
    final payload = PatrolNotificationActions.nextRoundPayload;
    final confirmAction = PatrolNotificationActions.autoScanConfirmActionId;
    final cancelAction = PatrolNotificationActions.autoScanCancelActionId;
    const notificationId = nextRoundConfirmNotificationId;

    if (Platform.isAndroid) {
      _androidBypassDndEnabled =
          await androidNotificationPolicyAccessGranted();
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _nextRoundHeadsUpChannelId!,
          _nextRoundHeadsUpChannelName!,
          channelDescription:
              'Confirm or cancel auto-scan for the next patrol round',
          icon: 'ic_bg_service_small',
          importance: Importance.max,
          priority: Priority.max,
          channelBypassDnd: _androidBypassDndEnabled,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.call,
          ticker: body,
          ongoing: true,
          autoCancel: false,
          fullScreenIntent: true,
          onlyAlertOnce: false,
          showWhen: true,
          when: postedAt.millisecondsSinceEpoch,
          enableVibration: true,
          enableLights: true,
          playSound: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          vibrationPattern: checkpointScanVibrationPattern,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
          ),
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              confirmAction,
              confirmLabel,
              showsUserInterface: false,
              cancelNotification: true,
              contextual: false,
            ),
            AndroidNotificationAction(
              cancelAction,
              cancelLabel,
              showsUserInterface: false,
              cancelNotification: true,
              contextual: false,
            ),
          ],
        ),
      );
      _activeNextRoundConfirmNotificationId = notificationId;
      try {
        await _plugin.show(
          notificationId,
          title,
          body,
          details,
          payload: payload,
        );
      } on Object {
        //
      }
      return;
    }

    if (Platform.isIOS) {
      await _ensureIosAttachment();
      final path = _iosAttachmentPath;
      final details = NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentBanner: true,
          presentList: true,
          presentSound: true,
          presentBadge: false,
          threadIdentifier: _iosCheckpointThreadId,
          categoryIdentifier: _iosNextRoundCategoryId,
          interruptionLevel: InterruptionLevel.timeSensitive,
          attachments: path == null
              ? null
              : [DarwinNotificationAttachment(path)],
        ),
      );
      _activeNextRoundConfirmNotificationId = notificationId;
      await _plugin.show(
        notificationId,
        title,
        body,
        details,
        payload: payload,
      );
    }
  }

  static Future<void> cancelNextRoundConfirm() async {
    final active =
        _activeNextRoundConfirmNotificationId ?? nextRoundConfirmNotificationId;
    _activeNextRoundConfirmNotificationId = null;
    await cancel(active);
    // Legacy peek id from older builds.
    await cancel(882501);
  }

  static Future<void> cancel(int notificationId) async {
    await _plugin.cancel(notificationId);
  }

  static Future<void> cancelAllCheckpointAlerts() async {
    final ids = List<int>.from(_activeCheckpointAlertIds);
    _activeCheckpointAlertIds.clear();
    for (final id in ids) {
      await _plugin.cancel(id);
    }
  }

  /// When a notification action opens the app, the tap is delivered here (not [handleResponse]).
  static Future<void> drainAppLaunchNotificationAction() async {
    if (!_ready || _launchNotificationActionDrained) return;
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp != true) return;
      final response = launch?.notificationResponse;
      if (response == null) return;
      _launchNotificationActionDrained = true;
      await PatrolNotificationActions.handleResponse(response);
    } on MissingPluginException {
      //
    } on PlatformException {
      //
    }
  }
}
