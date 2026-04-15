import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCqAcbKFJlRW8LqTdFXEvZi37Bw7rUyjek',
    appId: '1:941116410152:android:9a69b56ff1e4c06249a81d',
    messagingSenderId: '941116410152',
    projectId: 'lookmaxing-64eeb',
    storageBucket: 'lookmaxing-64eeb.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: '941116410152',
    projectId: 'lookmaxing-64eeb',
    storageBucket: 'lookmaxing-64eeb.firebasestorage.app',
    iosBundleId: 'com.glowup.lookAdmin',
  );
}
