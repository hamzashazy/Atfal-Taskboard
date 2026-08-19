/// Supabase client, session persistence and the RPC wrapper —
/// mirrors src/lib/{supabase,session,api}.ts of the web app.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';

// The anon key is safe to ship — all data access is governed by RLS, and
// every write goes through token-validated SQL functions.
const supabaseUrl = 'https://woygwtwrcunvcjrwbril.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndveWd3dHdyY3VudmNqcndicmlsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY5NTAzMjgsImV4cCI6MjEwMjUyNjMyOH0.MQfDxX2gL1LoJEFy7y-gxlYJjBEWCYjyS1rVGiSfsh4';

// Public site URL — only used in the WhatsApp share message for new tasks.
const siteUrl = 'https://atfal-taskboard.vercel.app';

SupabaseClient get sb => Supabase.instance.client;

final navigatorKey = GlobalKey<NavigatorState>();

/// Set by push.dart at startup — lets logout() unregister this device's
/// push token while the session is still valid, without api.dart needing
/// to import push.dart (which itself needs api.dart).
Future<void> Function()? onBeforeLogout;

/// In-memory + persisted session (localStorage equivalent).
class Session {
  static const _key = 'atfal_session';
  static SessionUser? current;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      current = SessionUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      current = null;
    }
  }

  static Future<void> set(SessionUser s) async {
    current = s;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(s.toJson()));
  }

  static Future<void> clear() async {
    current = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Call a database function; throws a clean Exception with the Postgres
/// message. An invalid/expired session bounces the user to the login screen.
Future<dynamic> rpc(String fn, Map<String, dynamic> args) async {
  try {
    return await sb.rpc(fn, params: args);
  } on PostgrestException catch (e) {
    var msg = e.message.isEmpty ? 'Request failed' : e.message;
    msg = msg.replaceFirst(RegExp(r'^AUTH: '), '');
    if (RegExp('session invalid|expired', caseSensitive: false).hasMatch(msg)) {
      await Session.clear();
      navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/login', (route) => false);
    }
    throw Exception(msg);
  }
}

Future<void> logout() async {
  final s = Session.current;
  if (s != null) {
    try {
      await onBeforeLogout?.call();
    } catch (_) {
      // best-effort push token cleanup
    }
    try {
      await rpc('atfal_logout', {'p_token': s.token});
    } catch (_) {
      // session already gone
    }
  }
  await Session.clear();
  navigatorKey.currentState
      ?.pushNamedAndRemoveUntil('/login', (route) => false);
}

/// Strip Dart's "Exception: " prefix for user-facing messages.
String errMsg(Object e) => e.toString().replaceFirst('Exception: ', '');

Future<void> openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> shareToWhatsApp(String text) =>
    openUrl('https://wa.me/?text=${Uri.encodeComponent(text)}');
