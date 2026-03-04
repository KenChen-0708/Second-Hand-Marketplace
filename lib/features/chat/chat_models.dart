import '../../models/models.dart';

// ─────────────────────────────────────────────────────
// ChatMessage model
// ─────────────────────────────────────────────────────
class ChatMessage {
  final String id;
  final String senderId; // 'me' = current user
  final String text;
  final DateTime timestamp;
  final bool isImage;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isImage = false,
  });
}

// ─────────────────────────────────────────────────────
// ChatConversation model  (one per product–peer pair)
// ─────────────────────────────────────────────────────
class ChatConversation {
  final String id;
  final User otherUser;
  final Product product;
  final List<ChatMessage> messages;
  bool dealAgreed;

  ChatConversation({
    required this.id,
    required this.otherUser,
    required this.product,
    required this.messages,
    this.dealAgreed = false,
  });

  /// Most-recent message (or null if empty).
  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;

  /// Count of messages from the other user that are "unread".
  int get unreadCount => messages
      .where((m) => m.senderId != 'me' && m.senderId.startsWith('unread_'))
      .length;

  bool get hasUnread => messages.any((m) => m.senderId.startsWith('unread_'));
}

// ─────────────────────────────────────────────────────
// Helper – relative time label
// ─────────────────────────────────────────────────────
String relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

// ─────────────────────────────────────────────────────
// Mock conversations (mutated at runtime via state)
// ─────────────────────────────────────────────────────
final List<ChatConversation> mockConversations = [
  ChatConversation(
    id: 'c1',
    otherUser: mockSeller1,
    product: mockProducts[0], // Calculus textbook
    dealAgreed: false,
    messages: [
      ChatMessage(
        id: 'm1',
        senderId: 'me',
        text: 'Hi! Is this textbook still available?',
        timestamp: DateTime.now().subtract(
          const Duration(hours: 2, minutes: 30),
        ),
      ),
      ChatMessage(
        id: 'm2',
        senderId: mockSeller1.id,
        text: 'Yes it is! Just listed it yesterday.',
        timestamp: DateTime.now().subtract(
          const Duration(hours: 2, minutes: 15),
        ),
      ),
      ChatMessage(
        id: 'm3',
        senderId: 'me',
        text: 'Great! Any chance you could do \$38?',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      ChatMessage(
        id: 'm4',
        // starts with 'unread_' so our hasUnread logic picks it up
        senderId: 'unread_${mockSeller1.id}',
        text: 'I can do \$40, final offer 😊',
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    ],
  ),
  ChatConversation(
    id: 'c2',
    otherUser: mockSeller2,
    product: mockProducts[1], // Sony headphones
    dealAgreed: true,
    messages: [
      ChatMessage(
        id: 'm10',
        senderId: mockSeller2.id,
        text: 'Hey, I saw you were interested in the headphones.',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      ),
      ChatMessage(
        id: 'm11',
        senderId: 'me',
        text: 'Yes! Are they still in good working condition?',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      ),
      ChatMessage(
        id: 'm12',
        senderId: mockSeller2.id,
        text: 'Absolutely, noise cancellation works perfectly.',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
      ChatMessage(
        id: 'm13',
        senderId: 'me',
        text: 'Deal! I\'ll take them for \$180.',
        timestamp: DateTime.now().subtract(const Duration(hours: 20)),
      ),
      ChatMessage(
        id: 'm14',
        senderId: mockSeller2.id,
        text: 'Perfect! Let me know when you\'re ready to meet 🎉',
        timestamp: DateTime.now().subtract(const Duration(hours: 18)),
      ),
    ],
  ),
  ChatConversation(
    id: 'c3',
    otherUser: mockSeller1,
    product: mockProducts[2], // Keyboard
    dealAgreed: false,
    messages: [
      ChatMessage(
        id: 'm20',
        senderId: 'me',
        text: 'What switches does this keyboard use?',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
      ),
      ChatMessage(
        id: 'm21',
        senderId: mockSeller1.id,
        text: 'Cherry MX Brown – great for both typing and gaming!',
        timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 22)),
      ),
    ],
  ),
  ChatConversation(
    id: 'c4',
    otherUser: mockSeller2,
    product: mockProducts[3], // iPad Pro
    dealAgreed: false,
    messages: [
      ChatMessage(
        id: 'm30',
        senderId: 'unread_${mockSeller2.id}',
        text: 'Hey are you still looking for the iPad?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
      ),
    ],
  ),
];
