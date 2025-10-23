import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../providers/message_provider.dart';
import '../../conversations/providers/conversation_provider.dart';
import '../../../core/models/message.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  String? _lastConversationId;
  bool _autoScroll = true; // Track if we should auto-scroll
  int _lastMessageCount = 0; // Track message count for auto-scroll detection

  @override
  void initState() {
    super.initState();
    // Listen to scroll events to detect manual scrolling
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // If user scrolls up manually, disable auto-scroll
    final isAtBottom = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50; // 50px threshold

    if (_autoScroll && !isAtBottom) {
      setState(() => _autoScroll = false);
    } else if (!_autoScroll && isAtBottom) {
      setState(() => _autoScroll = true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedConversation = ref.watch(selectedConversationProvider);
    final messageStateAsync = ref.watch(messageStateProvider);

    // Update conversation if it changed
    if (selectedConversation?.id != _lastConversationId) {
      _lastConversationId = selectedConversation?.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(messageStateProvider.notifier).setConversation(selectedConversation?.id);
      });
    }

    if (selectedConversation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: Text('No conversation selected')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedConversation.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: messageStateAsync.when(
              data: (messageState) {
                final allMessages = messageState.messages;
                final hasStreamingOrWaiting = messageState.streamingContent != null || messageState.isWaitingForResponse;

                if (allMessages.isEmpty && !hasStreamingOrWaiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start the conversation',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Scroll to bottom when new content arrives (only if user hasn't scrolled up)
                final currentMessageCount = allMessages.length + (hasStreamingOrWaiting ? 1 : 0);
                if (_autoScroll && currentMessageCount != _lastMessageCount) {
                  _lastMessageCount = currentMessageCount;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients && _autoScroll) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: allMessages.length + (hasStreamingOrWaiting ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Show streaming or waiting indicator as last item
                    if (index == allMessages.length && hasStreamingOrWaiting) {
                      return _buildStreamingOrWaitingBubble(context, messageState);
                    }
                    return MessageBubble(message: allMessages[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.read(messageStateProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildMessageInput(selectedConversation.id),
        ],
      ),
    );
  }

  Widget _buildStreamingOrWaitingBubble(BuildContext context, MessageState messageState) {
    final streamingContent = messageState.streamingContent;
    final isWaiting = messageState.isWaitingForResponse;
    final toolCalls = messageState.activeToolCalls;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.smart_toy,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Claude',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            if (isWaiting)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '...',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            else ...[
              if (streamingContent != null)
                MarkdownBody(
                  data: streamingContent,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    code: TextStyle(
                      backgroundColor: Colors.black.withValues(alpha: 0.1),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              if (toolCalls.isNotEmpty) ...[
                if (streamingContent != null) const SizedBox(height: 8),
                ...toolCalls.map((toolCall) => _buildToolCallIndicator(context, toolCall)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildToolCallIndicator(BuildContext context, ToolCallState toolCall) {
    IconData icon;
    switch (toolCall.kind) {
      case 'fetch':
        icon = Icons.cloud_download;
        break;
      case 'read':
        icon = Icons.description;
        break;
      case 'write':
      case 'edit':
        icon = Icons.edit;
        break;
      case 'bash':
        icon = Icons.terminal;
        break;
      default:
        icon = Icons.build;
    }

    final isCompleted = toolCall.status == 'completed';

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCompleted)
            Icon(
              Icons.check_circle,
              size: 14,
              color: Colors.green,
            )
          else
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.onSecondaryContainer.withValues(alpha: 0.6),
                ),
              ),
            ),
          const SizedBox(width: 6),
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              toolCall.title.replaceAll('"', ''),
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSecondaryContainer.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(String conversationId) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 4,
            color: Colors.black.withValues(alpha: 0.1),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _isSending ? null : (_) => _sendMessage(conversationId),
                  enabled: !_isSending,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                onPressed: _isSending ? null : () => _sendMessage(conversationId),
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage(String conversationId) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await ref.read(messageActionsProvider).sendMessage(
            conversationId: conversationId,
            content: text,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
        // Restore the message text so user can retry
        _messageController.text = text;
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }
}

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.smart_toy,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Claude',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            MarkdownBody(
              data: message.content,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  color: isUser
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                code: TextStyle(
                  backgroundColor: Colors.black.withValues(alpha: 0.1),
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: (isUser
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSecondaryContainer)
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
