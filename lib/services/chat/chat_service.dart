import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../../shared/utils/image_helper.dart';
import '../local/connectivity_service.dart';
import '../local/local_database_service.dart';
import '../notification/notification_service.dart';

class ChatService {
  static const String _productSharePrefix = '[product_share]';

  ChatService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client,
        _notificationService = NotificationService(client: client ?? Supabase.instance.client);

  final SupabaseClient _supabase;
  final NotificationService _notificationService;
  final LocalDatabaseService _localDatabase = LocalDatabaseService.instance;
  final ConnectivityService _connectivityService = ConnectivityService.instance;
  final Uuid _uuid = const Uuid();

  Future<List<ChatConversationBundle>> fetchUserConversations({
    required String userId,
  }) async {
    final cachedBundles = await _loadCachedConversationBundles(userId: userId);
    if (!await _connectivityService.isOnline()) {
      return cachedBundles;
    }

    try {
      await syncPendingMessages();

      if (kDebugMode) {
        print("--- CHAT FETCH DEBUG ---");
        print("Searching for conversations where buyer_id=$userId OR seller_id=$userId");
      }

      // We use a broader query first to avoid join-related filtering issues.
      // If a product or user is missing, a complex select might return nothing for that row.
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

      await _cacheBundles(userId, hydratedBundles);
      _sortBundles(hydratedBundles);
      return hydratedBundles;
    } on PostgrestException catch (e) {
      if (kDebugMode) print("PostgrestException: ${e.message}");
      return cachedBundles;
    } catch (e) {
      if (kDebugMode) print("Generic error in fetchUserConversations: $e");
      return cachedBundles;
    }
  }

  Future<ChatConversationBundle> fetchConversationById({
    required String conversationId,
    required String currentUserId,
  }) async {
    final cachedBundle = await _loadCachedConversationBundle(
      conversationId: conversationId,
      currentUserId: currentUserId,
    );

    if (!await _connectivityService.isOnline()) {
      if (cachedBundle != null) {
        return cachedBundle;
      }
      throw Exception('Unable to load this conversation while offline.');
    }

    try {
      await syncPendingMessages();

      final conversationData = await _supabase
          .from('chat_conversations')
          .select(
        '*, '
            'product:products(*, variations:product_variants(*, attributes:product_variant_attributes(*))), '
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

      final bundle = ChatConversationBundle.fromConversationMap(
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
      await _cacheBundles(currentUserId, [bundle]);
      return bundle;
    } on PostgrestException catch (e) {
      if (cachedBundle != null) {
        return cachedBundle;
      }
      throw Exception(e.message);
    } catch (e) {
      if (cachedBundle != null) {
        return cachedBundle;
      }
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
    if (!await _connectivityService.isOnline()) {
      final localMessage = ChatMessageModel(
        id: 'local_${_uuid.v4()}',
        conversationId: conversationId,
        senderId: senderId,
        messageText: messageText,
        isImage: isImage,
        imageUrl: imageUrl,
        isRead: true,
        createdAt: DateTime.now(),
      );
      await _localDatabase.upsertChatMessage(localMessage, syncStatus: 'pending');
      return localMessage;
    }

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

      // Get conversation to find recipient
      final conv = await _supabase
          .from('chat_conversations')
          .select(
            'buyer_id, '
            'seller_id, '
            'product_id, '
            'product:products(title), '
            'buyer:users!chat_conversations_buyer_id_fkey(id, name), '
            'seller:users!chat_conversations_seller_id_fkey(id, name)',
          )
          .eq('id', conversationId)
          .single();

      final recipientId = conv['buyer_id'] == senderId ? conv['seller_id'] : conv['buyer_id'];
      final buyer = Map<String, dynamic>.from((conv['buyer'] as Map?) ?? const {});
      final seller = Map<String, dynamic>.from((conv['seller'] as Map?) ?? const {});
      final senderName = conv['buyer_id'] == senderId
          ? (buyer['name']?.toString() ?? 'Buyer')
          : (seller['name']?.toString() ?? 'Seller');
      final preview = ChatService.previewText(message);

      await _supabase
          .from('chat_conversations')
          .update({'last_message_at': lastMessageAt})
          .eq('id', conversationId);

      // TRIGGER NOTIFICATION FOR RECIPIENT
      await _notificationService.createNotification(
        userId: recipientId,
        title: 'New message from $senderName',
        message: preview,
        type: 'message',
        relatedProductId: conv['product_id']?.toString(),
        relatedConversationId: conversationId,
      );

      await _localDatabase.upsertChatMessage(message, syncStatus: 'synced');
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
      if (await _connectivityService.isOnline()) {
        await _supabase
            .from('chat_messages')
            .update({'is_read': true})
            .eq('conversation_id', conversationId)
            .neq('sender_id', currentUserId)
            .eq('is_read', false);
      }

      final cachedMessages = await _localDatabase.getCachedMessages(conversationId);
      for (final message in cachedMessages.where((message) => message.senderId != currentUserId)) {
        await _localDatabase.upsertChatMessage(
          message.copyWith(isRead: true),
          syncStatus: 'synced',
        );
      }
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Unable to update message status.');
    }
  }

  Future<void> syncPendingMessages() async {
    if (!await _connectivityService.isOnline()) {
      return;
    }

    final pendingRows = await _localDatabase.getPendingChatMessageRows();
    for (final row in pendingRows) {
      final localMessage = ChatMessageModel.fromJson(row['data'] as String);
      final remoteMessage = await sendMessage(
        conversationId: localMessage.conversationId,
        senderId: localMessage.senderId,
        messageText: localMessage.messageText,
        isImage: localMessage.isImage,
        imageUrl: localMessage.imageUrl,
      );
      await _localDatabase.markMessageSynced(
        localMessageId: localMessage.id,
        remoteMessage: remoteMessage,
      );
    }
  }

  Future<void> _cacheBundles(
      String currentUserId,
      List<ChatConversationBundle> bundles,
      ) async {
    await _localDatabase.replaceConversationBundles(
      currentUserId,
      bundles
          .map(
            (bundle) => {
          'conversation_id': bundle.conversation.id,
          'product_id': bundle.product.id,
          'other_user_id': bundle.otherUser.id,
          'other_user_name': bundle.otherUser.name,
          'conversation_data': jsonEncode(bundle.conversation.toMap()),
          'product_data': bundle.product.toJson(),
          'other_user_data': bundle.otherUser.toJson(),
          'last_message_at': bundle.conversation.lastMessageAt?.toIso8601String(),
        },
      )
          .toList(),
    );

    for (final bundle in bundles) {
      await _localDatabase.replaceConversationMessages(
        bundle.conversation.id,
        bundle.messages,
      );
    }
  }

  Future<List<ChatConversationBundle>> _loadCachedConversationBundles({
    required String userId,
  }) async {
    final rows = await _localDatabase.getCachedConversationRows(userId);
    final bundles = <ChatConversationBundle>[];
    for (final row in rows) {
      final bundle = await _bundleFromCacheRow(
        row,
        currentUserId: userId,
      );
      if (bundle != null) {
        bundles.add(bundle);
      }
    }
    _sortBundles(bundles);
    return bundles;
  }

  Future<ChatConversationBundle?> _loadCachedConversationBundle({
    required String conversationId,
    required String currentUserId,
  }) async {
    final row = await _localDatabase.getCachedConversationRow(conversationId);
    if (row == null) {
      return null;
    }
    return _bundleFromCacheRow(row, currentUserId: currentUserId);
  }

  Future<ChatConversationBundle?> _bundleFromCacheRow(
      Map<String, dynamic> row, {
        required String currentUserId,
      }) async {
    try {
      final conversation = ChatConversationModel.fromMap(
        Map<String, dynamic>.from(
          (jsonDecode(row['conversation_data'] as String) as Map),
        ),
      );
      final product = ProductModel.fromJson(row['product_data'] as String);
      final otherUser = UserModel.fromJson(row['other_user_data'] as String);
      final messages = await _localDatabase.getCachedMessages(conversation.id);
      return ChatConversationBundle(
        conversation: conversation,
        product: product,
        otherUser: otherUser,
        messages: _sortMessages(messages),
      );
    } catch (_) {
      return null;
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

    // Resolve product with safety defaults if data is missing
    final Map<String, dynamic> rawProductMap = Map<String, dynamic>.from(
      (map['product'] as Map?) ?? <String, dynamic>{'id': map['product_id'] ?? '', 'title': 'Deleted Product', 'price': 0.0},
    );
    final productMap = _resolveProductMap(rawProductMap);

    // Resolve users with safety defaults
    final buyerMap = Map<String, dynamic>.from(
      (map['buyer'] as Map?) ?? <String, dynamic>{'id': conversation.buyerId, 'name': 'Deleted User'},
    );
    final sellerMap = Map<String, dynamic>.from(
      (map['seller'] as Map?) ?? <String, dynamic>{'id': conversation.sellerId, 'name': 'Deleted User'},
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
