import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message_model.dart';
import '../services/auth/auth_service.dart';
import '../services/chat/chat_service.dart';
import 'entity_state.dart';

class ChatMessageState extends EntityState<ChatMessageModel> {
  ChatMessageState({
    ChatService? chatService,
    AuthService? authService,
  }) : _chatService = chatService ?? ChatService(),
       _authService = authService ?? AuthService();

  final ChatService _chatService;
  final AuthService _authService;
  StreamSubscription? _messagesSubscription;

  /// Fetch messages and start real-time listener for this conversation
  Future<void> fetchMessages(String conversationId) async {
    final userId = await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      throw Exception('Please log in to view messages.');
    }

    setLoading(true);
    setError(null);

    try {
      // 1. Initial fetch from database (includes local cache sync)
      final bundle = await _chatService.fetchConversationById(
        conversationId: conversationId,
        currentUserId: userId,
      );
      setItems(bundle.messages);
      
      // 2. Start real-time listening
      _subscribeToMessages(conversationId);
      
    } catch (e) {
      setError(e.toString().replaceFirst('Exception: ', ''));
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  void _subscribeToMessages(String conversationId) {
    _messagesSubscription?.cancel();
    
    _messagesSubscription = Supabase.instance.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .listen((List<Map<String, dynamic>> data) {
          final newMessages = data.map((m) => ChatMessageModel.fromMap(m)).toList();
          
          // Sort messages by creation time
          newMessages.sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return aTime.compareTo(bTime);
          });

          // Use scheduleMicrotask to avoid UI glitches if update happens during build
          scheduleMicrotask(() {
            setItems(newMessages);
          });
        });
  }

  Future<ChatMessageModel> sendMessage({
    required String conversationId,
    required String messageText,
    bool isImage = false,
    String? imageUrl,
  }) async {
    final userId = await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      throw Exception('Please log in to send messages.');
    }

    try {
      final message = await _chatService.sendMessage(
        conversationId: conversationId,
        senderId: userId,
        messageText: messageText,
        isImage: isImage,
        imageUrl: imageUrl,
      );
      
      // We don't necessarily need to call addItem here because 
      // the real-time stream will pick up the new message automatically.
      return message;
    } catch (e) {
      setError(e.toString().replaceFirst('Exception: ', ''));
      rethrow;
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    final userId = await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      await _chatService.markConversationAsRead(
        conversationId: conversationId,
        currentUserId: userId,
      );
      // Local state update
      setItems(
        items.map((message) => message.senderId == userId
            ? message
            : message.copyWith(isRead: true)).toList(),
      );
    } catch (e) {
      setError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> syncPendingMessages() => _chatService.syncPendingMessages();

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    super.dispose();
  }
}
