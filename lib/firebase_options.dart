// ignore_for_file: lines_longer_than_80_chars
// Android: generated from android/app/google-services.json.
// iOS: run `dart pub global run flutterfire_cli:flutterfire configure --platforms=ios`
//      or set --dart-define=FIREBASE_IOS_APP_ID=1:788041630665:ios:YOUR_APP_ID
//
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  /// iOS Firebase App ID from FlutterFire or `--dart-define=FIREBASE_IOS_APP_ID=...`.
  static const String iosAppId = String.fromEnvironment(
    'FIREBASE_IOS_APP_ID',
    defaultValue: '',
  );

  static bool get isIosConfigured =>
      iosAppId.isNotEmpty && !iosAppId.contains('REPLACE');

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase is not configured for web — run FlutterFire CLI.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        if (isIosConfigured) return ios;
        throw UnsupportedError(
          'Firebase iOS is not configured. Add ios/Runner/GoogleService-Info.plist '
          '(flutterfire configure) or pass --dart-define=FIREBASE_IOS_APP_ID=...',
        );
      default:
        throw UnsupportedError(
          'Firebase is not supported on $defaultTargetPlatform.',
        );
    }
  }

  /// Initializes Firebase on iOS when only [GoogleService-Info.plist] is present.
  static Future<FirebaseOptions?> resolveForInit() async {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return isIosConfigured ? ios : null;
      default:
        return null;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDHwMdFnNWfu-ODKUNxtRvAAFoGC6rmcGs',
    appId: '1:788041630665:android:a0fb990067738a0442de18',
    messagingSenderId: '788041630665',
    projectId: 'sps-patrol',
    storageBucket: 'sps-patrol.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDHwMdFnNWfu-ODKUNxtRvAAFoGC6rmcGs',
    appId: iosAppId,
    messagingSenderId: '788041630665',
    projectId: 'sps-patrol',
    storageBucket: 'sps-patrol.firebasestorage.app',
    iosBundleId: 'com.sps.patrol',
  );
}
