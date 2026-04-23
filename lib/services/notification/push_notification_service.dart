import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_notification_manager.dart';

class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._();
  PushNotificationService._();
  
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  
  static const _storageKey = 'local_push_enabled';
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _currentUserId;

  Future<void> initialize() async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("!!! FCM: Received message while app is open");
      final notification = message.notification;
      final data = message.data;
      final title = notification?.title ?? data['title']?.toString();
      final body = notification?.body ?? data['body']?.toString();

      if (title != null && body != null) {
        LocalNotificationManager.instance.showNotification(
          id: _notificationIdForMessage(message),
          title: title,
          body: body,
          payload: data['conversationId']?.toString(),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("!!! FCM: Notification opened for ${message.data['conversationId']}");
    });
  }

  Future<bool> isEnabled() async {
    final val = await _storage.read(key: _storageKey);
    return val == 'true';
  }

  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> enableNotifications(String userId) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      await _storage.write(key: _storageKey, value: 'false');
      throw Exception('Notification permission was not granted.');
    }

    _currentUserId = userId;
    await _storage.write(key: _storageKey, value: 'true');
    await _persistToken(userId, enabled: true);
    _startTokenRefreshListener();
  }

  Future<void> disableNotifications(String userId) async {
    await _storage.write(key: _storageKey, value: 'false');
    _currentUserId = userId;
    try {
      await Supabase.instance.client
          .from('users')
          .update({
            'push_enabled': false,
            'fcm_token': null,
          })
          .eq('id', userId);
    } catch (e) {
      print("!!! PUSH ERROR: Failed to disable notifications: $e");
    }
  }

  Future<void> registerSignedInUser(String? userId) async {
    _currentUserId = userId;
    final existingSubscription = _tokenRefreshSubscription;
    _tokenRefreshSubscription = null;
    if (existingSubscription != null) {
      await existingSubscription.cancel();
    }

    if (userId == null) {
      return;
    }

    _startTokenRefreshListener();

    if (await isEnabled()) {
      await _persistToken(userId, enabled: true);
    }
  }

  Future<void> unregisterSignedInUser() async {
    _currentUserId = null;
    final existingSubscription = _tokenRefreshSubscription;
    _tokenRefreshSubscription = null;
    if (existingSubscription != null) {
      await existingSubscription.cancel();
    }
  }

  void _startTokenRefreshListener() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      final userId = _currentUserId;
      if (userId == null) {
        return;
      }

      final enabled = await isEnabled();
      if (!enabled) {
        return;
      }

      await _updateUserPushState(
        userId: userId,
        pushEnabled: true,
        token: token,
      );
      print("!!! PUSH: Refreshed token saved for $userId");
    });
  }

  Future<void> _persistToken(String userId, {required bool enabled}) async {
    final token = await _messaging.getToken();
    await _updateUserPushState(
      userId: userId,
      pushEnabled: enabled,
      token: enabled ? token : null,
    );
    print("!!! PUSH: Token saved to Supabase for $userId");
  }

  Future<void> _updateUserPushState({
    required String userId,
    required bool pushEnabled,
    required String? token,
  }) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({
            'push_enabled': pushEnabled,
            'fcm_token': token,
          })
          .eq('id', userId);
    } catch (e) {
      print("!!! PUSH ERROR: Failed to save token to DB: $e");
      rethrow;
    }
  }

  int _notificationIdForMessage(RemoteMessage message) {
    final id = message.messageId?.hashCode;
    if (id != null) {
      return id.abs();
    }
    return DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
  }
}
