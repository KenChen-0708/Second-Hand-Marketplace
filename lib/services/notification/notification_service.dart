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
          .eq('user_id', userId)
          .eq('is_read', false);
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
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'notification_type': type,
        'related_order_id': relatedOrderId,
        'related_product_id': relatedProductId,
        'is_read': false,
      });
    } catch (e) {
      // We don't want notification failure to break the main flow
      print('Silent failure creating notification: $e');
    }
  }
}
