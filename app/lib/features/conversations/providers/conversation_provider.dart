import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/conversation.dart';
import '../../../core/providers/api_provider.dart';
import '../../spaces/providers/space_provider.dart';

// Conversation List Provider (depends on selected space)
final conversationListProvider = FutureProvider<List<Conversation>>((ref) async {
  final selectedSpace = ref.watch(selectedSpaceProvider);

  if (selectedSpace == null) {
    return [];
  }

  final apiClient = ref.watch(apiClientProvider);
  return apiClient.getConversations(selectedSpace.id);
});

// Selected Conversation Provider
final selectedConversationProvider = StateProvider<Conversation?>((ref) => null);

// Conversation Actions Provider
final conversationActionsProvider = Provider((ref) => ConversationActions(ref));

class ConversationActions {
  final Ref ref;

  ConversationActions(this.ref);

  Future<Conversation> createConversation({
    required String spaceId,
    required String title,
  }) async {
    final apiClient = ref.read(apiClientProvider);
    final conversation = await apiClient.createConversation(
      spaceId: spaceId,
      title: title,
    );

    // Refresh the conversation list
    ref.invalidate(conversationListProvider);

    return conversation;
  }

  void selectConversation(Conversation conversation) {
    ref.read(selectedConversationProvider.notifier).state = conversation;
  }

  void clearSelection() {
    ref.read(selectedConversationProvider.notifier).state = null;
  }
}
