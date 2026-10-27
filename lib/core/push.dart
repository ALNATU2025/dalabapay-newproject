// lib/core/push.dart
// Phone push notifications (Firebase Cloud Messaging). After login the
// phone's push token is sent to the server (POST /api/me/devices), which
// then pushes funding, transfers, admin messages and — for staff — admin
// alerts. Notifications that arrive while the app is open are shown with
// [onForeground].
//
// Admin alerts with buttons ("Foday has sent ₦50,000" → Confirm / Cancel)
// arrive as data-only messages; the app draws them itself (also when it is
// in the background) with flutter_local_notifications. Tapping a button
// opens the app and does the action; tapping the notification opens the
// top-up.
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api/api.dart';
import 'firebase_setup.dart';

/// What a tapped notification asks the app to open.
class PushAction {
  final String route;
  final String id;
  final String? action; // confirm | cancel | null (just open)
  const PushAction(this.route, this.id, this.action);
}

const _channel = AndroidNotificationChannel(
  'admin_actions',
  'Admin actions',
  description: 'Top-ups and other things an admin needs to confirm',
  importance: Importance.max,
);

final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
bool _localReady = false;

Future<void> _initLocal({void Function(NotificationResponse)? onTap}) async {
  if (_localReady) return;
  await _local.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
    onDidReceiveNotificationResponse: onTap,
  );
  await _local
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);
  _localReady = true;
}

/// Draws a data-only message that carries buttons. Returns false when the
/// message has none (the system shows normal notifications itself).
Future<bool> _showActionable(RemoteMessage msg) async {
  final d = msg.data;
  final actions = (d['actions']?.toString() ?? '').split(',').where((a) => a.isNotEmpty).toList();
  if (actions.isEmpty || msg.notification != null) return false;
  final id = d['transactionId']?.toString() ?? '';
  final payload = '${d['action'] ?? ''}|$id';
  await _local.show(
    id.hashCode & 0x7fffffff,
    d['title']?.toString() ?? 'Dalabapay',
    d['body']?.toString() ?? '',
    NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(d['body']?.toString() ?? ''),
        actions: [
          for (final a in actions)
            AndroidNotificationAction(
              a,
              a == 'confirm' ? 'Confirm' : a == 'cancel' ? 'Cancel' : a,
              showsUserInterface: true,
              cancelNotification: true,
            ),
        ],
      ),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
    ),
    payload: payload,
  );
  return true;
}

/// Runs in the background (own isolate) for data-only messages.
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage msg) async {
  try {
    await FirebaseSetup.ensure();
    await _initLocal();
    await _showActionable(msg);
  } catch (e) {
    debugPrint('Background push not shown: $e');
  }
}

class PushNotifications {
  PushNotifications._();

  static String? _token;
  static bool _listening = false;

  /// Called with (title, body) for a push received while the app is open.
  static void Function(String title, String body)? onForeground;

  /// Called when a notification (or one of its buttons) is tapped.
  static void Function(PushAction action)? onOpen;

  /// A tap that launched the app, waiting for [onOpen] / login.
  static PushAction? pending;

  static bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static String get _platform => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  static PushAction? _parse(String? payload, String? actionId) {
    if (payload == null || !payload.contains('|')) return null;
    final parts = payload.split('|');
    if (parts[0] != 'funding_confirm' || parts[1].isEmpty) return null;
    final a = actionId == 'confirm' || actionId == 'cancel' ? actionId : null;
    return PushAction('/admin/bank-topups', parts[1], a);
  }

  static void _deliver(PushAction? a) {
    if (a == null) return;
    final cb = onOpen;
    if (cb == null) {
      pending = a;
    } else {
      cb(a);
    }
  }

  /// At app start: local notifications, and a tap that opened the app.
  static Future<void> init() async {
    if (!_supported) return;
    try {
      await _initLocal(onTap: (r) => _deliver(_parse(r.payload, r.actionId)));
      final launch = await _local.getNotificationAppLaunchDetails();
      final r = launch?.notificationResponse;
      if (launch?.didNotificationLaunchApp == true && r != null) _deliver(_parse(r.payload, r.actionId));
    } catch (e) {
      debugPrint('Local notifications unavailable: $e');
    }
  }

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
        FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
        m.onTokenRefresh.listen((t) => unawaited(_send(t)));
        FirebaseMessaging.onMessage.listen((msg) async {
          final n = msg.notification;
          final title = n?.title ?? msg.data['title']?.toString() ?? '';
          final body = n?.body ?? msg.data['body']?.toString() ?? '';
          // Buttons: show it as a notification too, so Confirm is one tap.
          await _initLocal(onTap: (r) => _deliver(_parse(r.payload, r.actionId)));
          await _showActionable(msg);
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
