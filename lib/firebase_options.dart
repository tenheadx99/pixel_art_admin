import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Web app "Pixel Art Admin" in the shared Firebase project om108-5c015
/// (values from `firebase apps:sdkconfig WEB`). Admin panel is web-only.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCrflpo6H01wJOnM6vWxTc0Xn0BuHrSgdM',
    appId: '1:433057017992:web:ce34ec9c253822c155af3d',
    messagingSenderId: '433057017992',
    projectId: 'om108-5c015',
    authDomain: 'om108-5c015.firebaseapp.com',
    storageBucket: 'om108-5c015.firebasestorage.app',
    measurementId: 'G-M1V4LYBK75',
  );

  static FirebaseOptions get currentPlatform => web;
}
