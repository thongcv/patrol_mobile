// ignore_for_file: lines_longer_than_80_chars
//
// Thay file này bằng output của: dart pub global run flutterfire_cli:flutterfire configure
// (hoặc chỉnh các hằng Android cho khớp project Firebase của bạn.)
//
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Chưa cấu hình Firebase cho web — chạy FlutterFire CLI.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Chỉ hỗ trợ Android trong bản build này — thêm iOS qua flutterfire configure.',
        );
    }
  }

  /// Giá trị mẫu để build; thay bằng project thật từ Firebase Console / FlutterFire.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDUMMY-DUMMY-DUMMY-DUMMY-DUMMY0',
    appId: '1:000000000000:android:aaaaaaaaaaaaaaaaaaaaaaaa',
    messagingSenderId: '000000000000',
    projectId: 'patrol-mobile-placeholder',
    storageBucket: 'patrol-mobile-placeholder.appspot.com',
  );
}
