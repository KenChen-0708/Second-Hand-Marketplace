import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';

class NotificationService {
  NotificationService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Fetch notifications for the current user
  Future<List<AppNotificationModel>> fetchNotifications(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((n) => AppNotificationModel.fromMap(Map<String, dynamic>.from(n)))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to fetch notifications: $e');
    }
  }

  /// Mark a specific notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Helper to create a notification (usually called by other services)
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    String? type,
    String? relatedOrderId,
    String? relatedProductId,
  }) async {
    try {
      // Ensure type is valid for the DB constraint
      final validTypes = ['order', 'message', 'system', 'item_sold', 'item_bought'];
      final String? finalType = validTypes.contains(type) ? type : 'system';

      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'notification_type': finalType,
        'related_order_id': relatedOrderId,
        'related_product_id': relatedProductId,
        'is_read': false,
      });
    } catch (e) {
      print('Silent failure creating notification: $e');
    }
  }

  /// Broadcast a notification to all users (Admin)
  Future<void> broadcastToAllUsers({
    required String adminId,
    required String title,
    required String message,
  }) async {
    try {
      // 1. Fetch all user IDs
      final usersResponse = await _supabase.from('users').select('id');
      final List<dynamic> users = usersResponse as List;

      if (users.isEmpty) return;

      // 2. Prepare bulk insert with 'system' type to satisfy DB constraint
      final notifications = users.map((user) => {
        'user_id': user['id'],
        'title': title,
        'message': message,
        'notification_type': 'system', 
        'is_read': false,
      }).toList();

      // 3. Insert in batches of 100 to avoid request size limits
      for (var i = 0; i < notifications.length; i += 100) {
        final end = (i + 100 < notifications.length) ? i + 100 : notifications.length;
        final batch = notifications.sublist(i, end);
        await _supabase.from('notifications').insert(batch);
      }

      // 4. Log the admin action
      await _supabase.from('admin_logs').insert({
        'admin_id': adminId,
        'action': 'broadcast_notification',
        'details': {'title': title, 'user_count': users.length},
      });

    } catch (e) {
      throw Exception('Failed to broadcast notification: $e');
    }
  }

  /// Fetch all system logs for notifications (Admin)
  Future<List<Map<String, dynamic>>> fetchAdminNotificationLogs() async {
    try {
      final response = await _supabase
          .from('admin_logs')
          .select()
          .eq('action', 'broadcast_notification')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      throw Exception('Failed to fetch admin logs: $e');
    }
  }
}
