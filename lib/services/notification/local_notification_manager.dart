import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class LocalNotificationManager {
  static final LocalNotificationManager instance = LocalNotificationManager._();
  LocalNotificationManager._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();
  final Map<String, DateTime> _recentNotificationKeys = {};

  bool _isInitialized = false;
  static const String _channelId = 'marketplace_alerts_v3';

  Future<void> initialize() async {
    if (_isInitialized) return;
    print("!!! NOTIFICATION MANAGER: Initializing...");

    // Fixed: Using @mipmap/ic_launcher to prevent invalid_icon error
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          print("!!! NOTIFICATION CLICKED: ${details.payload}");
        },
      );

      if (Platform.isAndroid) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(const AndroidNotificationChannel(
              _channelId,
              'Marketplace Notifications',
              description: 'Alerts for messages and orders.',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
              showBadge: true,
            ));
      }

      _isInitialized = true;
      print("!!! NOTIFICATION MANAGER: Ready.");
    } catch (e) {
      print("!!! NOTIFICATION MANAGER ERROR: $e");
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (_isDuplicate(title: title, body: body, payload: payload)) {
        return;
      }

      print("!!! NOTIFICATION TRIGGER: Showing banner: [$title]");

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        _channelId,
        'Marketplace Notifications',
        channelDescription: 'Alerts for messages and orders.',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.message,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformChannelSpecifics,
        payload: payload,
      );
    } catch (e) {
      print("!!! NOTIFICATION SEND FAILED: $e");
    }
  }

  bool _isDuplicate({
    required String title,
    required String body,
    String? payload,
  }) {
    final now = DateTime.now();
    final key = '$title|$body|${payload ?? ''}';

    _recentNotificationKeys.removeWhere(
      (_, timestamp) => now.difference(timestamp).inSeconds > 5,
    );

    final previous = _recentNotificationKeys[key];
    if (previous != null && now.difference(previous).inSeconds <= 5) {
      print("!!! NOTIFICATION SKIPPED: Duplicate banner suppressed.");
      return true;
    }

    _recentNotificationKeys[key] = now;
    return false;
  }
}
