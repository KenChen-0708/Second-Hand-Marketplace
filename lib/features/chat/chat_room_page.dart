import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/chat/chat_service.dart';
import '../../shared/utils/image_helper.dart';
import '../../shared/utils/snackbar_helper.dart';
import '../../state/state.dart';
import 'chat_models.dart';

class ChatRoomPage extends StatefulWidget {
  const ChatRoomPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  ChatConversationBundle? _bundle;
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConversation());
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bundle = await context
          .read<ChatConversationState>()
          .fetchConversationById(widget.conversationId);
      context.read<ChatMessageState>().setItems(bundle.messages);
      await context.read<ChatMessageState>().markConversationAsRead(
        widget.conversationId,
      );
      if (!mounted) {
        return;
      }
      setState(
        () => _bundle = bundle.copyWith(
          messages: context.read<ChatMessageState>().items,
        ),
      );
      context.read<ChatConversationState>().updateBundle(_bundle!);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    final bundle = _bundle;
    if (text.isEmpty || bundle == null || _isSending) {
      return;
    }

    setState(() => _isSending = true);
    try {
      final message = await context.read<ChatMessageState>().sendMessage(
        conversationId: bundle.conversation.id,
        messageText: text,
      );
      _textController.clear();
      final updatedBundle = bundle.copyWith(
        messages: [...bundle.messages, message],
        conversation: bundle.conversation.copyWith(
          lastMessageAt: message.createdAt,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() => _bundle = updatedBundle);
      context.read<ChatConversationState>().updateBundle(updatedBundle);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) {
        return;
      }
      SnackbarHelper.showTopMessage(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _copyMessageText(String text) async {
    if (text.trim().isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    SnackbarHelper.showSuccess(context, 'Message copied to clipboard.');
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData('text/plain');
    final text = clipboardData?.text?.trim();
    if (!mounted) {
      return;
    }

    if (text == null || text.isEmpty) {
      SnackbarHelper.showInfo(context, 'Clipboard is empty.');
      return;
    }

    _textController.text = text;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
    setState(() {});
  }

  Future<void> _showMessageActions(ChatMessageModel message) async {
    final sharedProduct = ChatService.parseSharedProduct(message);
    final hasCopyableText =
        sharedProduct == null && message.messageText.trim().isNotEmpty;

    if (!hasCopyableText) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy message'),
              onTap: () async {
                Navigator.pop(context);
                await _copyMessageText(message.messageText);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = context.watch<UserState>().currentUser?.id ?? '';

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _bundle == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, size: 72),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'Unable to load this conversation.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loadConversation,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bundle = _bundle!;
    final product = bundle.product;
    final messages = bundle.messages;
    
    // Resolve profile image with initials fallback for the header
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: GestureDetector(
          onTap: () => context.push('/product/${product.id}'),
          child: Row(
            children: [
              ImageHelper.avatar(
                bundle.otherUser.avatarUrl,
                name: bundle.otherUser.name,
                radius: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      bundle.otherUser.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.only(right: 4),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: ImageHelper.productImage(
                            product.imageUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${product.title} · RM ${product.price.toStringAsFixed(0)}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (bundle.conversation.dealAgreed)
            GestureDetector(
              onTap: () => context.push('/checkout'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                child: const Text(
                  'Deal agreed! Tap to initiate handover & payment.',
                  style: TextStyle(
                    color: Color(0xFF065F46),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isMe = message.senderId == currentUserId;
                final previous = index > 0 ? messages[index - 1] : null;
                final showDateDivider =
                    previous == null ||
                    !_isSameDay(previous.createdAt, message.createdAt);

                return Column(
                  children: [
                    if (showDateDivider)
                      _DateDivider(date: message.createdAt ?? DateTime.now()),
                    Builder(
                      builder: (context) {
                        final sharedProduct = ChatService.parseSharedProduct(message);
                        if (sharedProduct != null) {
                          return _SharedProductBubble(
                            product: sharedProduct.product,
                            isMe: isMe,
                            otherUserAvatarPath: bundle.otherUser.avatarUrl,
                            otherUserName: bundle.otherUser.name,
                          );
                        }

                        return _MessageBubble(
                          message: message,
                          isMe: isMe,
                          otherUser: bundle.otherUser,
                          onLongPress: () => _showMessageActions(message),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          _InputBar(
            controller: _textController,
            canSend: _textController.text.trim().isNotEmpty && !_isSending,
            onChanged: () => setState(() {}),
            onPaste: _pasteFromClipboard,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return false;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              formatChatDate(date),
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.otherUser,
    this.onLongPress,
  });

  final ChatMessageModel message;
  final bool isMe;
  final UserModel otherUser;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        top: 2,
        bottom: 2,
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
      ),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            ImageHelper.avatar(
              otherUser.avatarUrl,
              name: otherUser.name,
              radius: 14,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: onLongPress,
                  child: Container(
                    padding: message.isImage && message.imageUrl != null
                        ? const EdgeInsets.all(6)
                        : const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? const Color(0xFF10B981)
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                    ),
                    child: message.isImage && message.imageUrl != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: ImageHelper.networkImage(
                                  message.imageUrl,
                                  width: 220,
                                  height: 220,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if (message.messageText.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    message.messageText,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      height: 1.4,
                                      color: isMe
                                          ? Colors.white
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Text(
                            message.messageText,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.4,
                              color: isMe ? Colors.white : colorScheme.onSurface,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  formatChatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedProductBubble extends StatelessWidget {
  const _SharedProductBubble({
    required this.product,
    required this.isMe,
    required this.otherUserAvatarPath,
    required this.otherUserName,
  });

  final ProductModel product;
  final bool isMe;
  final String? otherUserAvatarPath;
  final String? otherUserName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
      ),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            ImageHelper.avatar(
              otherUserAvatarPath,
              name: otherUserName,
              radius: 14,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: GestureDetector(
              onTap: () => context.push('/product/${product.id}'),
              child: Container(
                width: 250,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1.2,
                      child: ImageHelper.productImage(
                        product.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'RM ${product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product.condition,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Tap to view',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.canSend,
    required this.onChanged,
    required this.onPaste,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onChanged;
  final VoidCallback onPaste;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: onPaste,
              icon: Icon(
                Icons.content_paste_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              tooltip: 'Paste',
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: controller,
                  maxLines: 4,
                  minLines: 1,
                  onChanged: (_) => onChanged(),
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: canSend ? onSend : null,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: canSend
                      ? const Color(0xFF10B981)
                      : colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: canSend ? Colors.white : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
