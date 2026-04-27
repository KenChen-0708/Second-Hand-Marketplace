import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../shared/utils/snackbar_helper.dart';
import '../../state/state.dart';

class AiSupportChatPage extends StatefulWidget {
  const AiSupportChatPage({super.key});

  @override
  State<AiSupportChatPage> createState() => _AiSupportChatPageState();
}

class _AiSupportChatPageState extends State<AiSupportChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AiSupportState>().initialize(
        user: context.read<UserState>().currentUser,
      );
      _scrollToBottom(animated: false);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _textController.text).trim();
    if (text.isEmpty) {
      return;
    }

    await context.read<AiSupportState>().sendMessage(
      text: text,
      user: context.read<UserState>().currentUser,
    );

    if (!mounted) {
      return;
    }

    if (preset == null) {
      _textController.clear();
      setState(() {});
    }

    if (context.read<AiSupportState>().error case final error?) {
      SnackbarHelper.showError(context, error);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) {
      return;
    }

    final offset = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    _scrollController.jumpTo(offset);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final supportState = context.watch<AiSupportState>();
    final messages = supportState.items;
    SupportChatMessageModel? lastAssistantMessage;
    for (final message in messages.reversed) {
      if (message.isAssistant) {
        lastAssistantMessage = message;
        break;
      }
    }

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Support',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              supportState.isSending ? 'Thinking...' : 'Marketplace help assistant',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Start over',
            onPressed: () async {
              await context.read<AiSupportState>().restart(
                user: context.read<UserState>().currentUser,
              );
              if (!mounted) {
                return;
              }
              _textController.clear();
              setState(() {});
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _scrollToBottom(animated: false),
              );
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.16),
              ),
            ),
            child: Text(
              'This assistant can answer common support questions and guide users to the right part of the app. For account-specific issues, include relevant details like whether you were buying or selling.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              itemCount: messages.length + (supportState.isSending ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= messages.length) {
                  return const _TypingBubble();
                }

                final message = messages[index];
                return _SupportBubble(message: message);
              },
            ),
          ),
          if (lastAssistantMessage case final assistantMessage?
              when assistantMessage.suggestedReplies.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final suggestion = assistantMessage.suggestedReplies[index];
                  return ActionChip(
                    label: Text(suggestion),
                    onPressed:
                        supportState.isSending ? null : () => _sendMessage(suggestion),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: assistantMessage.suggestedReplies.length,
              ),
            ),
          _SupportInputBar(
            controller: _textController,
            canSend: _textController.text.trim().isNotEmpty && !supportState.isSending,
            onChanged: () => setState(() {}),
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _SupportBubble extends StatelessWidget {
  const _SupportBubble({required this.message});

  final SupportChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: isUser ? 52 : 0,
        right: isUser ? 0 : 52,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: Color(0xFF10B981),
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF10B981)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 6),
                      bottomRight: Radius.circular(isUser ? 6 : 18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.4,
                          color: isUser ? Colors.white : colorScheme.onSurface,
                        ),
                      ),
                      if (message.isFallback && !isUser) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Offline guidance',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isUser
                                ? Colors.white.withValues(alpha: 0.85)
                                : colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4, right: 52),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Color(0xFF10B981),
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (index) => Padding(
                  padding: EdgeInsets.only(right: index == 2 ? 0 : 6),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportInputBar extends StatelessWidget {
  const _SupportInputBar({
    required this.controller,
    required this.canSend,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onChanged;
  final Future<void> Function([String? preset]) onSend;

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
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onChanged: (_) => onChanged(),
                  onSubmitted: (_) {
                    if (canSend) {
                      onSend();
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: 'Ask for help...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: canSend ? () => onSend() : null,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
