import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../shared/utils/image_helper.dart';

class ChatService {
  static const String _productSharePrefix = '[product_share]';

  ChatService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<ChatConversationBundle>> fetchUserConversations({
    required String userId,
  }) async {
    try {
      final conversationsData = await _supabase
          .from('chat_conversations')
          .select(
            '*, '
            'product:products(*), '
            'buyer:users!chat_conversations_buyer_id_fkey(*), '
            'seller:users!chat_conversations_seller_id_fkey(*)',
          )
          .or('buyer_id.eq.$userId,seller_id.eq.$userId')
          .order('last_message_at', ascending: false);

      final bundles = (conversationsData as List)
          .map(
            (item) => ChatConversationBundle.fromConversationMap(
              Map<String, dynamic>.from(item as Map),
              currentUserId: userId,
            ),
          )
          .toList();

      if (bundles.isEmpty) {
        return const [];
      }

      final conversationIds = bundles.map((bundle) => bundle.conversation.id).toList();
      final messagesData = await _supabase
          .from('chat_messages')
          .select()
          .inFilter('conversation_id', conversationIds)
          .order('created_at');

      final messagesByConversation = <String, List<ChatMessageModel>>{};
      for (final rawMessage in (messagesData as List)) {
        final message = ChatMessageModel.fromMap(
          Map<String, dynamic>.from(rawMessage as Map),
        );
        messagesByConversation.putIfAbsent(message.conversationId, () => []).add(message);
      }

      final hydratedBundles = bundles
          .map(
            (bundle) => bundle.copyWith(
              messages: _sortMessages(
                messagesByConversation[bundle.conversation.id] ?? const [],
              ),
            ),
          )
          .toList();

      _sortBundles(hydratedBundles);
      return hydratedBundles;
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Unable to load messages right now.');
    }
  }

  Future<ChatConversationBundle> fetchConversationById({
    required String conversationId,
    required String currentUserId,
  }) async {
    try {
      final conversationData = await _supabase
          .from('chat_conversations')
          .select(
            '*, '
            'product:products(*), '
            'buyer:users!chat_conversations_buyer_id_fkey(*), '
            'seller:users!chat_conversations_seller_id_fkey(*)',
          )
          .eq('id', conversationId)
          .single();

      final messagesData = await _supabase
          .from('chat_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at');

      return ChatConversationBundle.fromConversationMap(
        Map<String, dynamic>.from(conversationData),
        currentUserId: currentUserId,
      ).copyWith(
        messages: _sortMessages(
          (messagesData as List)
            .map(
              (item) => ChatMessageModel.fromMap(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
        ),
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Unable to load this conversation.');
    }
  }

  Future<ChatConversationBundle> getOrCreateConversation({
    required String productId,
    required String buyerId,
    required String sellerId,
    required String currentUserId,
  }) async {
    if (buyerId == sellerId) {
      throw Exception('You cannot start a chat with yourself.');
    }

    try {
      final conversationId = await _findOrCreateConversationId(
        productId: productId,
        buyerId: buyerId,
        sellerId: sellerId,
      );

      return fetchConversationById(
        conversationId: conversationId,
        currentUserId: currentUserId,
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Unable to open this chat right now.');
    }
  }

  Future<String> _findOrCreateConversationId({
    required String productId,
    required String buyerId,
    required String sellerId,
  }) async {
    final existing = await _supabase
        .from('chat_conversations')
        .select('id')
        .eq('product_id', productId)
        .eq('buyer_id', buyerId)
        .eq('seller_id', sellerId)
        .maybeSingle();

    if (existing != null) {
      return existing['id'] as String;
    }

    final existingSellerChat = await _supabase
        .from('chat_conversations')
        .select('id, product_id')
        .eq('buyer_id', buyerId)
        .eq('seller_id', sellerId)
        .order('last_message_at', ascending: false)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existingSellerChat != null) {
      final conversationId = existingSellerChat['id'] as String;
      final currentProductId = existingSellerChat['product_id'] as String?;
      if (currentProductId != productId) {
        try {
          await _supabase
              .from('chat_conversations')
              .update({'product_id': productId})
              .eq('id', conversationId);
        } on PostgrestException catch (e) {
          if (e.code == '23505') {
            final exactConversation = await _supabase
                .from('chat_conversations')
                .select('id')
                .eq('product_id', productId)
                .eq('buyer_id', buyerId)
                .eq('seller_id', sellerId)
                .single();
            return exactConversation['id'] as String;
          }
          rethrow;
        }
      }
      return conversationId;
    }

    try {
      final inserted = await _supabase
          .from('chat_conversations')
          .insert({
            'product_id': productId,
            'buyer_id': buyerId,
            'seller_id': sellerId,
          })
          .select('id')
          .single();
      return inserted['id'] as String;
    } on PostgrestException catch (e) {
      if (e.code != '23505') {
        rethrow;
      }

      final retried = await _supabase
          .from('chat_conversations')
          .select('id')
          .eq('product_id', productId)
          .eq('buyer_id', buyerId)
          .eq('seller_id', sellerId)
          .single();
      return retried['id'] as String;
    }
  }

  Future<ChatMessageModel> sendMessage({
    required String conversationId,
    required String senderId,
    required String messageText,
    bool isImage = false,
    String? imageUrl,
  }) async {
    try {
      final inserted = await _supabase
          .from('chat_messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': senderId,
            'message_text': messageText,
            'is_image': isImage,
            'image_url': imageUrl,
            'is_read': false,
          })
          .select()
          .single();

      final message = ChatMessageModel.fromMap(Map<String, dynamic>.from(inserted));
      final lastMessageAt =
          message.createdAt?.toUtc().toIso8601String() ??
          DateTime.now().toUtc().toIso8601String();

      await _supabase
          .from('chat_conversations')
          .update({'last_message_at': lastMessageAt})
          .eq('id', conversationId);

      return message;
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Unable to send message right now.');
    }
  }

  Future<ChatMessageModel> sendSharedProductMessage({
    required String conversationId,
    required String senderId,
    required ProductModel product,
  }) {
    return sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      messageText: encodeSharedProduct(product),
      isImage: true,
      imageUrl: ImageHelper.productOrDefault(product.imageUrl),
    );
  }

  Future<void> markConversationAsRead({
    required String conversationId,
    required String currentUserId,
  }) async {
    try {
      await _supabase
          .from('chat_messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .neq('sender_id', currentUserId)
          .eq('is_read', false);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Unable to update message status.');
    }
  }

  static List<ChatMessageModel> _sortMessages(List<ChatMessageModel> messages) {
    final sorted = [...messages];
    sorted.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final comparison = aTime.compareTo(bTime);
      if (comparison != 0) {
        return comparison;
      }
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  static void _sortBundles(List<ChatConversationBundle> bundles) {
    bundles.sort((a, b) {
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
  }

  static String encodeSharedProduct(ProductModel product) {
    return '$_productSharePrefix${product.toJson()}';
  }

  static SharedProductMessage? parseSharedProduct(ChatMessageModel? message) {
    final raw = message?.messageText ?? '';
    if (!raw.startsWith(_productSharePrefix)) {
      return null;
    }

    try {
      final json = raw.substring(_productSharePrefix.length);
      final product = ProductModel.fromJson(json);
      return SharedProductMessage(product: product);
    } catch (_) {
      return null;
    }
  }

  static String previewText(ChatMessageModel? message) {
    if (message == null) {
      return 'No messages yet';
    }

    final sharedProduct = parseSharedProduct(message);
    if (sharedProduct != null) {
      return 'Shared product: ${sharedProduct.product.title}';
    }

    if (message.isImage) {
      if (message.messageText.trim().isNotEmpty) {
        return message.messageText;
      }
      return 'Sent a photo';
    }

    final text = message.messageText.trim();
    return text.isEmpty ? 'No messages yet' : text;
  }
}

class SharedProductMessage {
  const SharedProductMessage({required this.product});

  final ProductModel product;
}

class ChatConversationBundle {
  const ChatConversationBundle({
    required this.conversation,
    required this.product,
    required this.otherUser,
    required this.messages,
  });

  final ChatConversationModel conversation;
  final ProductModel product;
  final UserModel otherUser;
  final List<ChatMessageModel> messages;

  ChatMessageModel? get lastMessage => messages.isNotEmpty ? messages.last : null;

  int unreadCountFor(String currentUserId) => messages
      .where((message) => message.senderId != currentUserId && !message.isRead)
      .length;

  ChatConversationBundle copyWith({
    ChatConversationModel? conversation,
    ProductModel? product,
    UserModel? otherUser,
    List<ChatMessageModel>? messages,
  }) {
    return ChatConversationBundle(
      conversation: conversation ?? this.conversation,
      product: product ?? this.product,
      otherUser: otherUser ?? this.otherUser,
      messages: messages ?? this.messages,
    );
  }

  factory ChatConversationBundle.fromConversationMap(
    Map<String, dynamic> map, {
    required String currentUserId,
  }) {
    final conversation = ChatConversationModel.fromMap(map);
    final productMap = _resolveProductMap(Map<String, dynamic>.from(
      (map['product'] as Map?) ?? <String, dynamic>{},
    ));
    final buyerMap = Map<String, dynamic>.from(
      (map['buyer'] as Map?) ?? <String, dynamic>{},
    );
    final sellerMap = Map<String, dynamic>.from(
      (map['seller'] as Map?) ?? <String, dynamic>{},
    );

    return ChatConversationBundle(
      conversation: conversation,
      product: ProductModel.fromMap(productMap),
      otherUser: currentUserId == conversation.buyerId
          ? UserModel.fromMap(sellerMap)
          : UserModel.fromMap(buyerMap),
      messages: const [],
    );
  }

  static Map<String, dynamic> _resolveProductMap(Map<String, dynamic> productMap) {
    final resolvedImages = ImageHelper.resolveProductImageUrls(
      productMap['image_urls'],
    );
    final resolvedImageUrl =
        ImageHelper.resolveProductImageUrl(
          productMap['image_url']?.toString(),
          fallbackToDefault: false,
        ) ??
        (resolvedImages.isNotEmpty
            ? resolvedImages.first
            : ImageHelper.defaultProductImageUrl);

    return {
      ...productMap,
      'image_url': resolvedImageUrl,
      'image_urls': resolvedImages,
    };
  }
}
