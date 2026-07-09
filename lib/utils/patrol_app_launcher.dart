import 'dart:io';

import 'package:flutter/services.dart';

/// Android — bring [MainActivity] to foreground (e.g. FGS session expired).
///
/// iOS: no public API to force the app UI to foreground from background — use
/// [PatrolForegroundNotification.showSessionExpiredRelaunch] and tap-to-open.
abstract final class PatrolAppLauncher {
  PatrolAppLauncher._();

  static const MethodChannel _channel = MethodChannel('patrol/app');

  static Future<void> bringToForeground({bool sessionExpired = false}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('bringToForeground', <String, dynamic>{
        'sessionExpired': sessionExpired,
      });
    } catch (_) {
      //
    }
  }
}
