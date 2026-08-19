/// Push notification wiring — Firebase Cloud Messaging on the client side.
/// Mirrors the "best-effort, never block the app" approach used for the
/// approval email: if Firebase isn't configured yet (see firebase_options.dart),
/// every method here just quietly no-ops instead of crashing anything.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';
import 'firebase_options.dart';
import 'widgets.dart';

abstract final class Push {
  static bool _ready = false;

  /// Call once at app startup, after Session.load(). Safe to call even
  /// without a real Firebase project configured yet.
  static Future<void> init() async {
    onBeforeLogout = unregister;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      _ready = true;
    } catch (_) {
      return; // Firebase not configured yet — push stays off, nothing else breaks.
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage m) {
      final ctx = navigatorKey.currentContext;
      final n = m.notification;
      if (ctx != null && n != null) {
        // ignore: use_build_context_synchronously
        showSnack(ctx, '${n.title ?? ''}${n.title != null && n.body != null ? ' — ' : ''}${n.body ?? ''}');
      }
    });

    if (Session.current != null) {
      await registerForCurrentUser();
    }
  }

  /// Requests notification permission (if not already decided) and
  /// registers this device's FCM token against the signed-in user.
  static Future<void> registerForCurrentUser() async {
    if (!_ready) return;
    final s = Session.current;
    if (s == null) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await rpc('atfal_register_push_token', {
        'p_token': s.token,
        'p_device_token': token,
        'p_platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
    } catch (_) {
      // Best-effort — a user with notifications off, or a misconfigured
      // Firebase project, should never block using the app.
    }
  }

  /// Call before logging out so this device stops receiving another
  /// account's notifications after a different user signs in on it.
  static Future<void> unregister() async {
    if (!_ready) return;
    try {
      final s = Session.current;
      final token = await FirebaseMessaging.instance.getToken();
      if (s == null || token == null) return;
      await rpc('atfal_unregister_push_token', {'p_token': s.token, 'p_device_token': token});
    } catch (_) {
      // best-effort — a stale/duplicate token cleanup failure isn't fatal
    }
  }
}
