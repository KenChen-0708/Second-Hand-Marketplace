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

  Future<List<ChatMessageModel>> fetchMessages(String conversationId) async {
    final userId = await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      throw Exception('Please log in to view messages.');
    }

    setLoading(true);
    setError(null);

    try {
      final bundle = await _chatService.fetchConversationById(
        conversationId: conversationId,
        currentUserId: userId,
      );
      setItems(bundle.messages);
      return bundle.messages;
    } catch (e) {
      setError(e.toString().replaceFirst('Exception: ', ''));
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<ChatMessageModel> sendMessage({
    required String conversationId,
    required String messageText,
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
      );
      addItem(message);
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
      setItems(
        items
            .map(
              (message) => message.senderId == userId
                  ? message
                  : message.copyWith(isRead: true),
            )
            .toList(),
      );
    } catch (e) {
      setError(e.toString().replaceFirst('Exception: ', ''));
    }
  }
}
