// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAJZTunXD48eqZT7X7FP-_mSwzECDdAR0I',
    appId: '1:682644550074:android:8f2b9f6d88632bdba3ed83',
    messagingSenderId: '682644550074',
    projectId: 'myshankara-49e84',
    storageBucket: 'myshankara-49e84.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB69XldV_medxltwxa-iaJbOplw-fuHOPg',
    appId: '1:682644550074:ios:aab2cafa0973e213a3ed83',
    messagingSenderId: '682644550074',
    projectId: 'myshankara-49e84',
    storageBucket: 'myshankara-49e84.firebasestorage.app',
    iosBundleId: 'com.zeroomni.myshankara',
    iosClientId:
    '682644550074-uigdnh86er593gqdb0pjsr53sq30ea44.apps.googleusercontent.com',
  );
}