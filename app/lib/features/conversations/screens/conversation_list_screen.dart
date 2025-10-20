import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/conversation_provider.dart';
import '../../spaces/providers/space_provider.dart';
import '../widgets/create_conversation_dialog.dart';

class ConversationListScreen extends ConsumerWidget {
  const ConversationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSpace = ref.watch(selectedSpaceProvider);
    final conversationListAsync = ref.watch(conversationListProvider);
    final selectedConversation = ref.watch(selectedConversationProvider);
    final conversationActions = ref.watch(conversationActionsProvider);

    if (selectedSpace == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conversations')),
        body: const Center(child: Text('No space selected')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedSpace.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateConversationDialog(context, ref, selectedSpace.id),
            tooltip: 'New Conversation',
          ),
        ],
      ),
      body: conversationListAsync.when(
        data: (conversations) {
          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No conversations yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start a new conversation',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateConversationDialog(
                      context,
                      ref,
                      selectedSpace.id,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('New Conversation'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final isSelected = selectedConversation?.id == conversation.id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: isSelected ? 4 : 1,
                color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                child: ListTile(
                  leading: Icon(
                    Icons.chat_bubble,
                    color: isSelected ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: Text(
                    conversation.title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    'Updated: ${_formatDate(conversation.updatedAt)}',
                  ),
                  onTap: () {
                    conversationActions.selectConversation(conversation);
                    Navigator.pushNamed(context, '/chat');
                  },
                ),
              );
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
                onPressed: () => ref.invalidate(conversationListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateConversationDialog(BuildContext context, WidgetRef ref, String spaceId) {
    showDialog(
      context: context,
      builder: (context) => CreateConversationDialog(spaceId: spaceId),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}
