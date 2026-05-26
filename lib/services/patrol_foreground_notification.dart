import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Patrol tracking notification (Android foreground service + iOS notification center).
abstract final class PatrolForegroundNotification {
  PatrolForegroundNotification._();

  static const String _iosThreadId = 'sps_patrol_track';
  static const String _logoAsset = 'assets/images/ic_notification_logo.png';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _ready = false;
  static String? _channelId;
  static String? _channelName;
  static String? _alertChannelId;
  static String? _alertChannelName;
  static String? _iosAttachmentPath;

  /// Two short pulses for checkpoint-scan feedback (Android channel vibration).
  static final Int64List checkpointScanVibrationPattern =
      Int64List.fromList(<int>[0, 120, 80, 120]);

  static Future<void> ensureInitialized({
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) async {
    if (_ready && _channelId == channelId) return;
    _channelId = channelId;
    _channelName = channelName;

    if (Platform.isAndroid) {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('ic_bg_service_small'),
      );
      await _plugin.initialize(initSettings);

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
          description: 'Vibration when a checkpoint is scanned',
          importance: Importance.high,
          enableVibration: true,
          vibrationPattern: checkpointScanVibrationPattern,
          playSound: false,
        ),
      );
    } else if (Platform.isIOS) {
      const initSettings = InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(initSettings);

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: false, sound: false);
      await _ensureIosAttachment();
    }

    _ready = true;
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
          ongoing: true,
          importance: pulse ? Importance.high : Importance.low,
          priority: pulse ? Priority.high : Priority.low,
          showWhen: false,
          enableVibration: pulse,
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

  static Future<void> cancel(int notificationId) async {
    await _plugin.cancel(notificationId);
  }
}
