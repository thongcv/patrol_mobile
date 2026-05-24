// ignore_for_file: lines_longer_than_80_chars
// File generated from android/app/google-services.json (project sps-patrol).
//
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase is not configured for web — run FlutterFire CLI.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Only Android is supported in this build — add iOS via flutterfire configure.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDHwMdFnNWfu-ODKUNxtRvAAFoGC6rmcGs',
    appId: '1:788041630665:android:a0fb990067738a0442de18',
    messagingSenderId: '788041630665',
    projectId: 'sps-patrol',
    storageBucket: 'sps-patrol.firebasestorage.app',
  );

}