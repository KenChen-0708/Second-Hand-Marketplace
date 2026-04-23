import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';

class AiSupportService {
  AiSupportService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const _welcomeSuggestions = <String>[
    'Where is my order?',
    'How do refunds work?',
    'How do I become a seller?',
    'How do I report a problem?',
  ];

  final SupabaseClient _client;
  final Uuid _uuid = const Uuid();

  SupportChatMessageModel buildWelcomeMessage({UserModel? user}) {
    final firstName = _firstName(user?.name);
    final greeting = firstName == null ? 'Hi there' : 'Hi $firstName';

    return SupportChatMessageModel(
      id: _uuid.v4(),
      role: SupportChatRole.assistant,
      text:
          '$greeting, I\'m CampusSell Support. I can help with orders, refunds, listings, payments, delivery handovers, and account issues.',
      createdAt: DateTime.now(),
      suggestedReplies: _welcomeSuggestions,
    );
  }

  Future<SupportChatMessageModel> sendMessage({
    required String message,
    required List<SupportChatMessageModel> history,
    UserModel? user,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw Exception('Please enter a message.');
    }

    try {
      final response = await _client.functions.invoke(
        'ai-customer-support',
        body: {
          'message': trimmed,
          'messages': history
              .skip(history.length > 12 ? history.length - 12 : 0)
              .map(
                (entry) => {
                  'role': entry.role == SupportChatRole.user ? 'user' : 'assistant',
                  'content': entry.text,
                },
              )
              .toList(),
          'user': user == null
              ? null
              : {
                  'id': user.id,
                  'name': user.name,
                  'role': user.role,
                },
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw Exception('Support service returned an invalid response.');
      }

      final replyText = data['reply']?.toString().trim() ?? '';
      if (replyText.isEmpty) {
        throw Exception('Support service returned an empty reply.');
      }

      final suggestions = ((data['suggestions'] as List?) ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .take(4)
          .toList();

      return SupportChatMessageModel(
        id: _uuid.v4(),
        role: SupportChatRole.assistant,
        text: replyText,
        createdAt: DateTime.now(),
        suggestedReplies: suggestions,
        isFallback: data['source']?.toString() == 'fallback',
      );
    } on FunctionException catch (e) {
      debugPrint(
        'AI support function failed: status=${e.status} details=${e.details} reason=${e.reasonPhrase}',
      );
      return _buildFallbackReply(
        trimmed,
        debugReason:
            'Function error ${e.status ?? 'unknown'}: ${e.details ?? e.reasonPhrase ?? 'No details'}',
      );
    } catch (e) {
      debugPrint('AI support invoke failed before fallback: $e');
      return _buildFallbackReply(trimmed);
    }
  }

  SupportChatMessageModel buildUserMessage(String message) {
    return SupportChatMessageModel(
      id: _uuid.v4(),
      role: SupportChatRole.user,
      text: message.trim(),
      createdAt: DateTime.now(),
    );
  }

  SupportChatMessageModel _buildFallbackReply(
    String message, {
    String? debugReason,
  }) {
    return _buildFallbackReplyInternal(message, debugReason: debugReason);
  }

  SupportChatMessageModel _buildFallbackReplyInternal(
    String message, {
    String? debugReason,
  }) {
    final normalized = message.toLowerCase();

    if (_matchesAny(normalized, ['refund', 'return', 'cancel', 'money back'])) {
      return _assistantReply(
        text:
            'Refunds usually depend on the order status and whether there is an active dispute. Open the order details page, review the status, and use the report or dispute flow if the item was not delivered as expected.',
        suggestions: const [
          'How do I report a seller?',
          'What if the item is damaged?',
          'Where can I see my orders?',
        ],
        debugReason: debugReason,
      );
    }

    if (_matchesAny(normalized, ['order', 'delivery', 'handover', 'meet', 'pickup'])) {
      return _assistantReply(
        text:
            'You can track the latest order state from Profile > Order History. If a handover is pending, check the order details for the next action and confirm the meetup or delivery step there.',
        suggestions: const [
          'What does pending handover mean?',
          'How do I contact the seller?',
          'How do disputes work?',
        ],
        debugReason: debugReason,
      );
    }

    if (_matchesAny(normalized, ['seller', 'listing', 'sell', 'product'])) {
      return _assistantReply(
        text:
            'To start selling, open the Sell tab and create a listing with clear photos, price, condition, and stock details. If a listing is missing or unavailable, check its status from Profile > My Listings.',
        suggestions: const [
          'How do I edit a listing?',
          'Why is my item not visible?',
          'How do seller ratings work?',
        ],
        debugReason: debugReason,
      );
    }

    if (_matchesAny(normalized, ['payment', 'pay', 'stripe', 'card'])) {
      return _assistantReply(
        text:
            'Payment issues are often caused by incomplete checkout steps, expired payment methods, or interrupted network requests. Try the checkout flow again, and if the order state looks wrong, open the related order details before retrying.',
        suggestions: const [
          'Was I charged twice?',
          'How do I retry payment?',
          'How do refunds work?',
        ],
        debugReason: debugReason,
      );
    }

    if (_matchesAny(normalized, ['account', 'login', 'password', 'notification'])) {
      return _assistantReply(
        text:
            'For account and app settings, open Profile > Settings. You can manage push notifications, biometrics, theme, profile edits, and password changes there.',
        suggestions: const [
          'I forgot my password',
          'Why am I not getting notifications?',
          'How do I edit my profile?',
        ],
        debugReason: debugReason,
      );
    }

    return _assistantReply(
      text:
          'I can help with orders, refunds, listings, seller issues, payments, and account settings. Tell me what happened and include any useful detail like whether you were buying or selling.',
      suggestions: const [
        'Where is my order?',
        'How do refunds work?',
        'How do I become a seller?',
        'I need help with payments',
      ],
      debugReason: debugReason,
    );
  }

  SupportChatMessageModel _assistantReply({
    required String text,
    List<String> suggestions = const [],
    String? debugReason,
  }) {
    final resolvedText = kDebugMode && debugReason != null
        ? '$text\n\n[Debug: $debugReason]'
        : text;
    return SupportChatMessageModel(
      id: _uuid.v4(),
      role: SupportChatRole.assistant,
      text: resolvedText,
      createdAt: DateTime.now(),
      suggestedReplies: suggestions,
      isFallback: true,
    );
  }

  bool _matchesAny(String text, List<String> terms) {
    return terms.any(text.contains);
  }

  String? _firstName(String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed.split(RegExp(r'\s+')).first;
  }
}
