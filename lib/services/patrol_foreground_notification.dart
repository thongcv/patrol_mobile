import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Foreground patrol notification with full-color logo ([largeIcon]).
///
/// Android still requires a white [icon] in the status bar; the colored logo
/// appears in the expanded notification panel.
abstract final class PatrolForegroundNotification {
  PatrolForegroundNotification._();

  static const String logoAsset = 'assets/images/logo-transparent.png';
  static const String smallIcon = 'ic_bg_service_small';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _ready = false;
  static String? _channelId;
  static String? _channelName;

  static Future<void> ensureInitialized({
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) async {
    if (_ready && _channelId == channelId) return;
    _channelId = channelId;
    _channelName = channelName;

    if (!Platform.isAndroid) {
      _ready = true;
      return;
    }

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings(smallIcon),
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

    _ready = true;
  }

  static Future<void> show({
    required int notificationId,
    required String title,
    required String body,
  }) async {
    if (!Platform.isAndroid) return;
    final channelId = _channelId;
    final channelName = _channelName;
    if (!_ready || channelId == null || channelName == null) return;

    AndroidNotificationDetails androidDetails;
    try {
      final logoBytes = await rootBundle.load(logoAsset);
      androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        icon: smallIcon,
        largeIcon: ByteArrayAndroidBitmap(
          logoBytes.buffer.asUint8List(),
        ),
        ongoing: true,
        importance: Importance.low,
        priority: Priority.low,
        showWhen: false,
        colorized: true,
      );
    } catch (_) {
      androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        icon: smallIcon,
        largeIcon: const DrawableResourceAndroidBitmap('ic_notification_logo'),
        ongoing: true,
        importance: Importance.low,
        priority: Priority.low,
        showWhen: false,
        colorized: true,
      );
    }

    await _plugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> cancel(int notificationId) async {
    await _plugin.cancel(notificationId);
  }
}
