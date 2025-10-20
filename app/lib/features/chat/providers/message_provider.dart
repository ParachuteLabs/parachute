import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/message.dart';
import '../../../core/providers/api_provider.dart';
import '../../conversations/providers/conversation_provider.dart';

// Message List Provider (depends on selected conversation)
final messageListProvider = FutureProvider<List<Message>>((ref) async {
  final selectedConversation = ref.watch(selectedConversationProvider);

  if (selectedConversation == null) {
    return [];
  }

  final apiClient = ref.watch(apiClientProvider);
  return apiClient.getMessages(selectedConversation.id);
});

// Message Actions Provider
final messageActionsProvider = Provider((ref) => MessageActions(ref));

class MessageActions {
  final Ref ref;

  MessageActions(this.ref);

  Future<Message> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    final apiClient = ref.read(apiClientProvider);
    final message = await apiClient.sendMessage(
      conversationId: conversationId,
      content: content,
    );

    // Refresh the message list
    ref.invalidate(messageListProvider);

    return message;
  }
}
