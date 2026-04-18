import 'dart:async';

import '../models/models.dart';
import '../services/auth/auth_service.dart';
import '../services/chat/chat_service.dart';
import '../services/local/connectivity_service.dart';
import 'entity_state.dart';

class ChatConversationState extends EntityState<ChatConversationModel> {
  ChatConversationState({
    ChatService? chatService,
    AuthService? authService,
  }) : _chatService = chatService ?? ChatService(),
       _authService = authService ?? AuthService() {
    _connectivitySubscription = _connectivityService.onlineChanges.listen((
      isOnline,
    ) {
      if (isOnline) {
        fetchUserConversations();
      }
    });
  }

  final ChatService _chatService;
  final AuthService _authService;
  final ConnectivityService _connectivityService = ConnectivityService.instance;
  late final StreamSubscription<bool> _connectivitySubscription;
  List<ChatConversationBundle> _bundles = [];

  List<ChatConversationBundle> get bundles => List.unmodifiable(_bundles);

  int get unreadCount {
    final currentUserId = _lastUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      return 0;
    }
    return _bundles.fold<int>(
      0,
      (sum, bundle) => sum + bundle.unreadCountFor(currentUserId),
    );
  }

  String? _lastUserId;

  Future<List<ChatConversationBundle>> fetchUserConversations() async {
    final userId = await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      _bundles = [];
      setItems(const []);
      return const [];
    }

    _lastUserId = userId;
    setLoading(true);
    setError(null);

    try {
      final bundles = await _chatService.fetchUserConversations(userId: userId);
      _bundles = bundles;
      setItems(bundles.map((bundle) => bundle.conversation).toList());
      return bundles;
    } catch (e) {
      setError(e.toString().replaceFirst('Exception: ', ''));
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<ChatConversationBundle> fetchConversationById(String conversationId) async {
    final userId = await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      throw Exception('Please log in to view messages.');
    }

    _lastUserId = userId;
    setLoading(true);
    setError(null);

    try {
      final bundle = await _chatService.fetchConversationById(
        conversationId: conversationId,
        currentUserId: userId,
      );
      _mergeBundle(bundle);
      return bundle;
    } catch (e) {
      setError(e.toString().replaceFirst('Exception: ', ''));
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<ChatConversationBundle> getOrCreateConversationForProduct({
    required ProductModel product,
  }) async {
    final userId = await _authService.getCurrentUserId();
    if (userId == null || userId.isEmpty) {
      throw Exception('Please log in to message this seller.');
    }

    _lastUserId = userId;
    setLoading(true);
    setError(null);

    try {
      final bundle = await _chatService.getOrCreateConversation(
        productId: product.id,
        buyerId: userId,
        sellerId: product.sellerId,
        currentUserId: userId,
      );

      var updatedBundle = bundle;
      final lastSharedProduct = ChatService.parseSharedProduct(
        updatedBundle.lastMessage,
      );
      final shouldSendProductShare =
          updatedBundle.lastMessage?.senderId != userId ||
          lastSharedProduct?.product.id != product.id;

      if (shouldSendProductShare) {
        final sharedMessage = await _chatService.sendSharedProductMessage(
          conversationId: updatedBundle.conversation.id,
          senderId: userId,
          product: product,
        );
        updatedBundle = updatedBundle.copyWith(
          product: product,
          messages: [...updatedBundle.messages, sharedMessage],
          conversation: updatedBundle.conversation.copyWith(
            productId: product.id,
            lastMessageAt: sharedMessage.createdAt,
          ),
        );
      } else if (updatedBundle.product.id != product.id) {
        updatedBundle = updatedBundle.copyWith(
          product: product,
          conversation: updatedBundle.conversation.copyWith(productId: product.id),
        );
      }

      _mergeBundle(updatedBundle);
      return updatedBundle;
    } catch (e) {
      setError(e.toString().replaceFirst('Exception: ', ''));
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  void updateBundle(ChatConversationBundle bundle) {
    _mergeBundle(bundle);
  }

  void _mergeBundle(ChatConversationBundle bundle) {
    final index = _bundles.indexWhere(
      (existing) => existing.conversation.id == bundle.conversation.id,
    );
    if (index == -1) {
      _bundles = [..._bundles, bundle];
    } else {
      final updated = [..._bundles];
      updated[index] = bundle;
      _bundles = updated;
    }
    _bundles.sort((a, b) {
      final aTime =
          a.lastMessage?.createdAt ??
          a.conversation.lastMessageAt ??
          a.conversation.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          b.lastMessage?.createdAt ??
          b.conversation.lastMessageAt ??
          b.conversation.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final comparison = bTime.compareTo(aTime);
      if (comparison != 0) {
        return comparison;
      }
      return b.conversation.id.compareTo(a.conversation.id);
    });
    upsertItem(bundle.conversation);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }
}
