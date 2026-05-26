import 'dart:io';

// Transitive platform implementations — registered for the background isolate only.
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_android/geolocator_android.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_apple/geolocator_apple.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_android/shared_preferences_android.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_foundation/shared_preferences_foundation.dart';

/// Minimal plugin set for the [FlutterBackgroundService] background isolate.
///
/// Do not call [DartPluginRegistrant.ensureInitialized] here — the background
/// engine must not register [FlutterBackgroundServiceAndroid] again.
bool _patrolBackgroundPluginsRegistered = false;

@pragma('vm:entry-point')
void ensurePatrolBackgroundPlugins() {
  if (_patrolBackgroundPluginsRegistered) return;
  _patrolBackgroundPluginsRegistered = true;
  if (Platform.isAndroid) {
    GeolocatorAndroid.registerWith();
    SharedPreferencesAndroid.registerWith();
    AndroidFlutterLocalNotificationsPlugin.registerWith();
  } else if (Platform.isIOS) {
    GeolocatorApple.registerWith();
    SharedPreferencesFoundation.registerWith();
    IOSFlutterLocalNotificationsPlugin.registerWith();
  }
}
