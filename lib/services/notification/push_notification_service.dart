import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._();
  PushNotificationService._();
  
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  
  static const _storageKey = 'local_push_enabled';

  Future<void> initialize() async {
    // This is called in main.dart
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("!!! FCM: Received message while app is open");
      // LocalNotificationManager is already handled here if needed
    });
  }

  Future<bool> isEnabled() async {
    final val = await _storage.read(key: _storageKey);
    return val == 'true';
  }

  Future<bool> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  Future<void> enableNotifications(String userId) async {
    final hasPermission = await requestPermission();
    if (hasPermission) {
      await _storage.write(key: _storageKey, value: 'true');
      
      // 1. Get the FCM Token (The phone's unique address)
      String? token = await FirebaseMessaging.instance.getToken();
      
      try {
        // 2. Save token to Supabase users table
        await Supabase.instance.client
            .from('users')
            .update({
              'push_enabled': true,
              'fcm_token': token, 
            })
            .eq('id', userId);
        print("!!! PUSH: Token saved to Supabase for $userId");
      } catch (e) {
        print("!!! PUSH ERROR: Failed to save token to DB: $e");
      }
    }
  }

  Future<void> disableNotifications(String userId) async {
    await _storage.write(key: _storageKey, value: 'false');
    try {
      await Supabase.instance.client
          .from('users')
          .update({
            'push_enabled': false,
            'fcm_token': null,
          })
          .eq('id', userId);
    } catch (e) {}
  }
}
