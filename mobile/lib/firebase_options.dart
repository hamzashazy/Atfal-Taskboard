// Generated from the atfal-taskboard Firebase project's google-services.json
// / GoogleService-Info.plist (see mobile/android/app/ and mobile/ios/Runner/).
// Regenerate with `flutterfire configure` if the Firebase project ever
// changes; these values are safe to commit — they're client identifiers,
// not secrets (the actual secret, the service account key, lives only in
// the send-push Edge Function's environment).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web push is not configured for this app.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyDLKfp_WG19FRWjO1xrMbnQ8ejTdkg6l-Q',
    appId: '1:264719467458:android:3475a613afce849892cc5b',
    messagingSenderId: '264719467458',
    projectId: 'atfal-taskboard',
    storageBucket: 'atfal-taskboard.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyCDgBA1uxA_MG5VyQdrQDDvgDmpqV0DitI',
    appId: '1:264719467458:ios:70116fe7a41b675192cc5b',
    messagingSenderId: '264719467458',
    projectId: 'atfal-taskboard',
    storageBucket: 'atfal-taskboard.firebasestorage.app',
    iosBundleId: 'com.atfaltech.atfalTaskboard',
  );
}
