import 'dart:async';
import 'package:flutter/material.dart';
import 'entity_state.dart';
import '../models/app_notification_model.dart';
import '../services/notification/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppNotificationState extends EntityState<AppNotificationModel> {
  final NotificationService _notificationService = NotificationService();
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  /// Fetch initial notifications and start real-time listener
  Future<void> fetchNotifications(String userId) async {
    setLoading(true);
    setError(null);
    try {
      // Start real-time listening
      _subscribeToNotifications(userId);
    } catch (e) {
      debugPrint('ERROR setting up notifications: $e');
      setError(e.toString());
    } finally {
      setLoading(false);
    }
  }

  void _subscribeToNotifications(String userId) {
    _subscription?.cancel();
    
    _subscription = Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at')
        .listen((List<Map<String, dynamic>> data) {
          final newItems = data.map((n) => AppNotificationModel.fromMap(n)).toList();
          newItems.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
          
          // Use microtask to avoid "setState() called during build"
          scheduleMicrotask(() {
            setItems(newItems);
          });
          debugPrint('Real-time: Received ${data.length} notifications.');
        });
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);
    } catch (e) {
      debugPrint('Error marking read: $e');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await _notificationService.markAllAsRead(userId);
    } catch (e) {
      debugPrint('Error marking all read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationService.deleteNotification(notificationId);
    } catch (e) {
      debugPrint('Error deleting: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
