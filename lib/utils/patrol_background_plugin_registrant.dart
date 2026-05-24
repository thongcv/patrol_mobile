// Transitive Android implementations — registered for the background isolate only.
// ignore: depend_on_referenced_packages
import 'package:geolocator_android/geolocator_android.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_android/shared_preferences_android.dart';

/// Minimal plugin set for the [FlutterBackgroundService] background isolate.
///
/// Do not call [DartPluginRegistrant.ensureInitialized] here — the background
/// engine must not register [FlutterBackgroundServiceAndroid] again.
bool _patrolBackgroundPluginsRegistered = false;

@pragma('vm:entry-point')
void ensurePatrolBackgroundPlugins() {
  if (_patrolBackgroundPluginsRegistered) return;
  _patrolBackgroundPluginsRegistered = true;
  GeolocatorAndroid.registerWith();
  SharedPreferencesAndroid.registerWith();
}
