import 'dart:async';
import 'package:flutter/material.dart';
import 'entity_state.dart';
import '../models/app_notification_model.dart';
import '../models/user_model.dart';
import '../services/notification/notification_service.dart';
import '../services/notification/local_notification_manager.dart';
import '../services/notification/push_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppNotificationState extends EntityState<AppNotificationModel> {
  final NotificationService _notificationService = NotificationService();
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  
  final Set<String> _seenNotificationIds = {};
  UserModel? _currentUser;
  String? _subscribedUserId;

  void updateCurrentUser(UserModel? user) {
    if (_currentUser?.id == user?.id && _currentUser?.pushEnabled == user?.pushEnabled) return;
    
    _currentUser = user;
    if (user != null) {
      if (_subscribedUserId != user.id) {
        print("!!! NOTIFICATION STATE: New User Detected - Starting Subscription");
        _subscribeToNotifications(user.id);
      }
    } else {
      print("!!! NOTIFICATION STATE: No User - Stopping Subscription");
      _subscription?.cancel();
      _subscription = null;
      _subscribedUserId = null;
      _seenNotificationIds.clear();
      
      // Use microtask to avoid 'setState during build' error
      scheduleMicrotask(() {
        clear();
      });
    }
  }

  Future<void> fetchNotifications(UserModel user) async {
    updateCurrentUser(user);
  }

  void _subscribeToNotifications(String userId) {
    _subscription?.cancel();
    _subscribedUserId = userId;
    
    _subscription = Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at')
        .listen((List<Map<String, dynamic>> data) {
          print('!!! REAL-TIME: Received ${data.length} notifications from Supabase');
          final newItems = data.map((n) => AppNotificationModel.fromMap(n)).toList();
          newItems.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
          
          _handleNewNotifications(newItems);
          
          scheduleMicrotask(() {
            setItems(newItems);
          });
        });
    print('!!! NOTIFICATION STATE: Listener is ACTIVE for user: $userId');
  }

  Future<void> _handleNewNotifications(List<AppNotificationModel> currentList) async {
    if (_currentUser == null) return;
    
    // Check local preference
    final pushEnabled = await PushNotificationService.instance.isEnabled();
    if (!pushEnabled) {
      print('!!! PUSH BLOCKED: User local setting "pushEnabled" is FALSE');
      return;
    }

    for (var note in currentList) {
      if (!note.isRead && !_seenNotificationIds.contains(note.id)) {
        
        final now = DateTime.now().toUtc();
        final noteTime = note.createdAt?.toUtc() ?? now;
        final difference = now.difference(noteTime).inMinutes.abs();
        
        print('!!! NOTIFICATION CHECK: Age is $difference mins for "${note.title}"');

        // Show banner if it happened within the last 15 minutes
        if (difference < 15) {
          LocalNotificationManager.instance.showNotification(
            id: note.id.hashCode.abs(),
            title: note.title,
            body: note.message,
          );
        }
        
        _seenNotificationIds.add(note.id);
      }
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final note = getById(notificationId);
    if (note == null || note.isRead) return;
    final updatedNote = note.copyWith(isRead: true);
    upsertItem(updatedNote);
    try {
      await _notificationService.markAsRead(notificationId);
    } catch (e) {
      upsertItem(note);
    }
  }

  Future<void> markAllAsRead(String userId) async {
    final oldItems = List<AppNotificationModel>.from(items);
    final updatedItems = items.map((n) => n.copyWith(isRead: true)).toList();
    setItems(updatedItems);
    try {
      await _notificationService.markAllAsRead(userId);
    } catch (e) {
      setItems(oldItems);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    final note = getById(notificationId);
    if (note == null) return;
    removeById(notificationId);
    try {
      await _notificationService.deleteNotification(notificationId);
    } catch (e) {
      addItem(note);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
