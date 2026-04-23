import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/chat/chat_service.dart';
import '../../shared/utils/image_helper.dart';
import '../../state/state.dart';
import 'chat_models.dart';

class ChatInboxPage extends StatefulWidget {
  const ChatInboxPage({super.key});

  @override
  State<ChatInboxPage> createState() => _ChatInboxPageState();
}

class _ChatInboxPageState extends State<ChatInboxPage> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final chatState = context.read<ChatConversationState>();
      await chatState.fetchUserConversations();
      
      if (mounted && chatState.error != null) {
        setState(() => _error = chatState.error);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<ChatConversationBundle> _filtered(List<ChatConversationBundle> bundles) {
    if (_query.isEmpty) {
      return bundles;
    }

    final query = _query.toLowerCase();
    return bundles.where((bundle) {
      return bundle.otherUser.name.toLowerCase().contains(query) ||
          bundle.product.title.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chatConversationState = context.watch<ChatConversationState>();
    final userState = context.watch<UserState>();
    
    final currentUser = userState.currentUser;
    final userId = currentUser?.id ?? '';
    final conversations = _filtered(chatConversationState.bundles);

    if (currentUser == null && userState.isAuthenticated) {
       return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Messages',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: colorScheme.onSurface,
          ),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadConversations,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search by name or product...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadConversations,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? _buildErrorState()
                    : conversations.isEmpty
                    ? _buildEmptyState(colorScheme, currentUser)
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: conversations.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 80,
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                        itemBuilder: (context, index) => _ConversationTile(
                          bundle: conversations[index],
                          currentUserId: userId,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loadConversations,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, UserModel? currentUser) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 64,
                  color: colorScheme.onSurface.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No conversations found',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.bundle,
    required this.currentUserId,
  });

  final ChatConversationBundle bundle;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lastMessage = bundle.lastMessage;
    final unreadCount = bundle.unreadCountFor(currentUserId);
    final hasUnread = unreadCount > 0;
    
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/chat/${bundle.conversation.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            _buildAvatar(colorScheme, bundle.product.imageUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNameRow(colorScheme, hasUnread, lastMessage),
                  const SizedBox(height: 3),
                  _buildProductTitle(colorScheme),
                  const SizedBox(height: 3),
                  _buildPreviewRow(colorScheme, hasUnread, lastMessage, unreadCount),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ColorScheme colorScheme, String? productImageUrl) {
    final presenceColor = bundle.otherUser.isOnline
        ? const Color(0xFF10B981)
        : colorScheme.outline;

    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bundle.otherUser.isOnline
                  ? const Color(0xFF10B981).withValues(alpha: 0.10)
                  : colorScheme.surfaceContainerHighest,
              border: Border.all(
                color: presenceColor,
                width: 2,
              ),
            ),
            child: ImageHelper.avatar(
              bundle.otherUser.avatarUrl,
              name: bundle.otherUser.name,
              radius: 28,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: presenceColor,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.surface, width: 2),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 24,
              height: 24,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colorScheme.surface, width: 1.5),
              ),
              child: ImageHelper.productImage(
                productImageUrl,
                width: 24,
                height: 24,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameRow(ColorScheme colorScheme, bool hasUnread, ChatMessageModel? lastMessage) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bundle.otherUser.name.isEmpty ? "Unknown User" : bundle.otherUser.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _buildPresenceText(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: bundle.otherUser.isOnline
                      ? const Color(0xFF10B981)
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (lastMessage != null) ...[
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              relativeTime(lastMessage.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: hasUnread
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductTitle(ColorScheme colorScheme) {
    return Text(
      bundle.product.title,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        color: colorScheme.primary.withValues(alpha: 0.8),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildPreviewRow(ColorScheme colorScheme, bool hasUnread, ChatMessageModel? lastMessage, int unreadCount) {
    return Row(
      children: [
        Expanded(
          child: Text(
            ChatService.previewText(lastMessage),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: hasUnread
                  ? colorScheme.onSurface.withValues(alpha: 0.85)
                  : colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
        if (hasUnread) ...[
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$unreadCount',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _buildPresenceText() {
    if (bundle.otherUser.isOnline) {
      return 'Online now';
    }

    final lastSeen = bundle.otherUser.lastSeenAt;
    if (lastSeen == null) {
      return 'Offline';
    }

    final difference = DateTime.now().difference(lastSeen.toLocal());
    if (difference.inMinutes < 1) {
      return 'Last seen just now';
    }
    if (difference.inMinutes < 60) {
      return 'Last seen ${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return 'Last seen ${difference.inHours}h ago';
    }
    if (difference.inDays < 7) {
      return 'Last seen ${difference.inDays}d ago';
    }

    return 'Last seen ${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
  }
}
