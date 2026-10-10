import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'session.dart';

/// Push notification setup: permission, topic subscription, and showing pushes
/// while the app is open.
class AlertService extends ChangeNotifier {
  AlertService._();
  static final instance = AlertService._();

  /// Topic the ESP32 sends to (FCM_TOPIC in the sketch)
  static const topic = 'gas_alert';
  static const _prefsKey = 'alerts_enabled';

  /// Loud, high-priority channel (same id as in AndroidManifest.xml and the sketch)
  static const channel = AndroidNotificationChannel(
    'gas_alert',
    'Gas alerts',
    description: 'Alerts when the gas detector finds a leak',
    importance: Importance.max,
  );

  final _notifications = FlutterLocalNotificationsPlugin();

  bool? permissionAllowed;
  bool alertsEnabled = true;
  String? token;
  String? error;

  Future<void> init() async {
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_gld'),
      ),
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // App is open: Android does not show the push by itself, so show it here
    FirebaseMessaging.onMessage.listen(_showNotification);

    final prefs = await SharedPreferences.getInstance();
    alertsEnabled = prefs.getBool(_prefsKey) ?? true;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      permissionAllowed =
          settings.authorizationStatus == AuthorizationStatus.authorized;
      notifyListeners();

      token = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM token: $token'); // copy from the terminal for console tests
      notifyListeners();

      if (alertsEnabled && Session.instance.user != null) {
        await FirebaseMessaging.instance.subscribeToTopic(topic);
      }
      error = null;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  /// Logged-in users get gas alerts (if they haven't switched them off)
  Future<void> onSignedIn() async {
    if (!alertsEnabled) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  /// A signed-out phone stops getting gas alerts
  Future<void> onSignedOut() async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> setAlertsEnabled(bool on) async {
    alertsEnabled = on;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, on);
    try {
      if (on) {
        await FirebaseMessaging.instance.subscribeToTopic(topic);
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      }
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  void _showNotification(RemoteMessage message) {
    final n = message.notification;
    if (n == null || !alertsEnabled) return;
    _notifications.show(
      id: message.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          color: const Color(0xFF0F766E),
        ),
      ),
    );
  }
}
