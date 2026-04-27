import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceService with WidgetsBindingObserver {
  static const Duration _heartbeatInterval = Duration(seconds: 15);

  PresenceService._();

  static final PresenceService instance = PresenceService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  String? _currentUserId;
  bool _isInitialized = false;
  bool _lastOnlineValue = false;
  Timer? _heartbeatTimer;

  void initialize() {
    if (_isInitialized) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
  }

  Future<void> setCurrentUser(String? userId) async {
    if (_currentUserId == userId) {
      return;
    }

    final previousUserId = _currentUserId;
    _currentUserId = userId;

    if (previousUserId != null && previousUserId.isNotEmpty) {
      _stopHeartbeat();
      await _writePresence(previousUserId, isOnline: false);
    }

    if (userId != null && userId.isNotEmpty) {
      await _writePresence(userId, isOnline: true);
      _startHeartbeat();
    }
  }

  Future<void> markOnline() async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      return;
    }
    await _writePresence(userId, isOnline: true);
    _startHeartbeat();
  }

  Future<void> markOffline() async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      return;
    }
    _stopHeartbeat();
    await _writePresence(userId, isOnline: false);
  }

  Future<void> _writePresence(
    String userId, {
    required bool isOnline,
  }) async {
    _lastOnlineValue = isOnline;
    try {
      await _supabase
          .from('users')
          .update({
            'is_online': isOnline,
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);
    } catch (_) {
      // Presence updates should not block the app.
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      final userId = _currentUserId;
      if (userId == null || userId.isEmpty) {
        return;
      }
      unawaited(_writePresence(userId, isOnline: true));
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(markOnline());
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(markOffline());
        break;
    }
  }

  Future<void> disposeService() async {
    _stopHeartbeat();
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
    }
    if (_currentUserId != null && _currentUserId!.isNotEmpty && _lastOnlineValue) {
      await _writePresence(_currentUserId!, isOnline: false);
    }
    _currentUserId = null;
  }
}
