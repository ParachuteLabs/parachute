import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/conversation_provider.dart';
import '../../chat/screens/chat_screen.dart';

class CreateConversationDialog extends ConsumerStatefulWidget {
  final String spaceId;

  const CreateConversationDialog({super.key, required this.spaceId});

  @override
  ConsumerState<CreateConversationDialog> createState() =>
      _CreateConversationDialogState();
}

class _CreateConversationDialogState
    extends ConsumerState<CreateConversationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Conversation'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'What would you like to discuss?',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a title';
            }
            return null;
          },
          enabled: !_isLoading,
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createConversation,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createConversation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final conversation = await ref
          .read(conversationActionsProvider)
          .createConversation(
            spaceId: widget.spaceId,
            title: _titleController.text.trim(),
          );

      if (mounted) {
        Navigator.pop(context);
        // Auto-select the new conversation
        ref.read(conversationActionsProvider).selectConversation(conversation);
        // Navigate to chat
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChatScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating conversation: $e')),
        );
      }
    }
  }
}
