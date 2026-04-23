import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';

class NotificationService {
  NotificationService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  static const List<String> _legacyFollowTitles = [
    'New follower',
    'New followers',
  ];

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
    String? relatedConversationId,
    bool sendPush = true,
  }) async {
    try {
      // Ensure type is valid for the DB constraint
      final validTypes = ['order', 'message', 'system', 'item_sold', 'item_bought', 'follow'];
      final String? finalType = validTypes.contains(type) ? type : 'system';

      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'notification_type': finalType,
        'related_order_id': relatedOrderId,
        'related_product_id': relatedProductId,
        'related_conversation_id': relatedConversationId,
        'is_read': false,
      });

      if (sendPush) {
        await _dispatchRemotePush(
          userId: userId,
          title: title,
          message: message,
          type: finalType ?? 'system',
          relatedOrderId: relatedOrderId,
          relatedProductId: relatedProductId,
          relatedConversationId: relatedConversationId,
        );
      }
    } catch (e) {
      print('Silent failure creating notification: $e');
    }
  }

  Future<void> notifySellerFollowed({
    required String sellerId,
    required String followerName,
  }) async {
    try {
      final existing = await _findExistingUnreadFollowNotification(sellerId);

      final previousCount = existing == null
          ? 0
          : _parseFollowNotificationCount(
              existing['message']?.toString() ?? '',
            );
      final totalFollowersInGroup = previousCount + 1;
      final title = totalFollowersInGroup > 1
          ? 'New followers'
          : 'New follower';
      final message = _buildFollowMessage(
        followerName: followerName,
        totalFollowersInGroup: totalFollowersInGroup,
      );
      var notificationType = 'follow';

      if (existing == null) {
        try {
          await _supabase.from('notifications').insert({
            'user_id': sellerId,
            'title': title,
            'message': message,
            'notification_type': notificationType,
            'is_read': false,
          });
        } on PostgrestException catch (e) {
          if (!_isFollowTypeConstraintFailure(e)) {
            rethrow;
          }

          notificationType = 'system';
          await _supabase.from('notifications').insert({
            'user_id': sellerId,
            'title': title,
            'message': message,
            'notification_type': notificationType,
            'is_read': false,
          });
        }
      } else {
        notificationType =
            existing['notification_type']?.toString() == 'follow'
            ? 'follow'
            : 'system';

        await _supabase
            .from('notifications')
            .update({
              'title': title,
              'message': message,
              'notification_type': notificationType,
              'is_read': false,
            })
            .eq('id', existing['id']);
      }

      await _dispatchRemotePush(
        userId: sellerId,
        title: title,
        message: message,
        type: notificationType,
      );
    } catch (e) {
      print('Silent failure creating follow notification: $e');
    }
  }

  Future<Map<String, dynamic>?> _findExistingUnreadFollowNotification(
    String sellerId,
  ) async {
    final followRows = await _supabase
        .from('notifications')
        .select('id, message, notification_type')
        .eq('user_id', sellerId)
        .eq('notification_type', 'follow')
        .eq('is_read', false)
        .order('created_at', ascending: false)
        .limit(1);

    if (followRows is List && followRows.isNotEmpty) {
      return Map<String, dynamic>.from(followRows.first as Map);
    }

    final legacyRows = await _supabase
        .from('notifications')
        .select('id, title, message, notification_type')
        .eq('user_id', sellerId)
        .eq('notification_type', 'system')
        .eq('is_read', false)
        .inFilter('title', _legacyFollowTitles)
        .order('created_at', ascending: false)
        .limit(1);

    if (legacyRows is List && legacyRows.isNotEmpty) {
      return Map<String, dynamic>.from(legacyRows.first as Map);
    }

    return null;
  }

  bool _isFollowTypeConstraintFailure(PostgrestException error) {
    final detailsText = error.details?.toString() ?? '';
    return error.code == '23514' &&
        (error.message.contains('notifications_notification_type_check') ||
            detailsText.contains('follow'));
  }

  int _parseFollowNotificationCount(String message) {
    if (message.isEmpty) {
      return 0;
    }

    final match = RegExp(r'and (\d+) other(s)? followed you\.$').firstMatch(
      message,
    );
    if (match != null) {
      final othersCount = int.tryParse(match.group(1) ?? '') ?? 0;
      return othersCount + 1;
    }

    if (message.endsWith('followed you.')) {
      return 1;
    }

    return 1;
  }

  String _buildFollowMessage({
    required String followerName,
    required int totalFollowersInGroup,
  }) {
    if (totalFollowersInGroup <= 1) {
      return '$followerName followed you.';
    }

    final othersCount = totalFollowersInGroup - 1;
    final othersLabel = othersCount == 1 ? 'other' : 'others';
    return '$followerName and $othersCount $othersLabel followed you.';
  }

  Future<void> _dispatchRemotePush({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? relatedOrderId,
    String? relatedProductId,
    String? relatedConversationId,
  }) async {
    try {
      await _supabase.functions.invoke(
        'send-chat-message-push',
        body: {
          'recipientId': userId,
          'title': title,
          'body': message,
          'type': type,
          'orderId': relatedOrderId,
          'productId': relatedProductId,
          'conversationId': relatedConversationId,
        },
      );
    } catch (e) {
      print('Silent failure sending push notification: $e');
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
