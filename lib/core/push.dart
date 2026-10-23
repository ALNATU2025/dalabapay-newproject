// lib/core/push.dart
// Phone push notifications (Firebase Cloud Messaging). After login the
// phone's push token is sent to the server (POST /api/me/devices), which
// then pushes funding, transfers, admin messages and — for staff — admin
// alerts. Notifications that arrive while the app is open are shown with
// [onForeground].
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api/api.dart';
import 'firebase_setup.dart';

class PushNotifications {
  PushNotifications._();

  static String? _token;
  static bool _listening = false;

  /// Called with (title, body) for a push received while the app is open.
  static void Function(String title, String body)? onForeground;

  static bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static String get _platform => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Asks for permission (Android 13+ / iOS) and registers this phone.
  /// Never throws: push is a convenience.
  static Future<void> register() async {
    if (!_supported) return;
    try {
      await FirebaseSetup.ensure();
      final m = FirebaseMessaging.instance;
      final perm = await m.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await m.getToken();
      if (token != null && token.isNotEmpty) await _send(token);
      if (!_listening) {
        _listening = true;
        m.onTokenRefresh.listen((t) => unawaited(_send(t)));
        FirebaseMessaging.onMessage.listen((msg) {
          final n = msg.notification;
          final title = n?.title ?? msg.data['title']?.toString() ?? '';
          final body = n?.body ?? msg.data['body']?.toString() ?? '';
          if (title.isNotEmpty || body.isNotEmpty) onForeground?.call(title, body);
        });
      }
    } catch (e) {
      debugPrint('Push notifications unavailable: $e');
    }
  }

  static Future<void> _send(String token) async {
    _token = token;
    if (!api.hasToken) return;
    try {
      await api.post('/api/me/devices', {'token': token, 'platform': _platform});
    } catch (e) {
      debugPrint('Push token not saved: $e');
    }
  }

  /// Stops pushes to this phone (on logout, before the session ends).
  static Future<void> unregister() async {
    final t = _token;
    if (t == null || !api.hasToken) return;
    try {
      await api.post('/api/me/devices/remove', {'token': t});
    } catch (_) {}
  }
}
