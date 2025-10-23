import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/message.dart';
import '../../../core/providers/api_provider.dart';
import '../../conversations/providers/conversation_provider.dart';

// Tool Call State
class ToolCallState {
  final String id;
  final String title;
  final String kind;
  final String status; // "pending", "completed"

  ToolCallState({
    required this.id,
    required this.title,
    required this.kind,
    required this.status,
  });

  ToolCallState copyWith({
    String? id,
    String? title,
    String? kind,
    String? status,
  }) {
    return ToolCallState(
      id: id ?? this.id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      status: status ?? this.status,
    );
  }
}

// Message State - includes both stored messages and streaming message
class MessageState {
  final List<Message> messages;
  final String? streamingContent;  // Content being streamed in real-time
  final bool isWaitingForResponse;  // True when we've sent a message but no chunks yet
  final List<ToolCallState> activeToolCalls; // Tool calls in progress

  MessageState({
    required this.messages,
    this.streamingContent,
    this.isWaitingForResponse = false,
    this.activeToolCalls = const [],
  });

  MessageState copyWith({
    List<Message>? messages,
    String? streamingContent,
    bool? isWaitingForResponse,
    List<ToolCallState>? activeToolCalls,
    bool clearStreaming = false,
    bool clearToolCalls = false,
  }) {
    return MessageState(
      messages: messages ?? this.messages,
      streamingContent: clearStreaming ? null : (streamingContent ?? this.streamingContent),
      isWaitingForResponse: isWaitingForResponse ?? this.isWaitingForResponse,
      activeToolCalls: clearToolCalls ? [] : (activeToolCalls ?? this.activeToolCalls),
    );
  }
}

// Message State Notifier - manages real-time message updates
class MessageNotifier extends StateNotifier<AsyncValue<MessageState>> {
  final Ref ref;
  Timer? _pollTimer;
  String? _currentConversationId;
  StreamSubscription? _wsSubscription;

  MessageNotifier(this.ref) : super(const AsyncValue.loading()) {
    _startPolling();
    _listenToWebSocket();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_currentConversationId != null) {
        _fetchMessages();
      }
    });
  }

  void _listenToWebSocket() {
    final wsClient = ref.read(webSocketClientProvider);
    _wsSubscription = wsClient.messages.listen((message) {
      print('📩 WebSocket message received: ${message['type']}');

      final type = message['type'] as String?;
      final payload = message['payload'] as Map<String, dynamic>?;
      final conversationId = payload?['conversation_id'] as String?;

      print('   Conversation ID: $conversationId, Current: $_currentConversationId');

      // Only process messages for the current conversation
      if (conversationId != _currentConversationId) {
        print('   ⏭️  Skipping message for different conversation');
        return;
      }

      if (type == 'message_chunk') {
        final chunk = payload?['chunk'] as String?;
        print('   💬 Message chunk: ${chunk?.substring(0, chunk!.length > 50 ? 50 : chunk.length)}...');
        if (chunk != null) {
          addStreamingChunk(chunk);
        }
      } else if (type == 'tool_call') {
        final toolCallId = payload?['tool_call_id'] as String?;
        final title = payload?['title'] as String?;
        final kind = payload?['kind'] as String?;
        final status = payload?['status'] as String?;

        print('   🔧 Tool call: $title ($kind) - $status');

        if (toolCallId != null && title != null && kind != null && status != null) {
          addToolCall(toolCallId, title, kind, status);
        }
      } else if (type == 'tool_call_update') {
        final toolCallId = payload?['tool_call_id'] as String?;
        final status = payload?['status'] as String?;

        print('   ✅ Tool call update: $toolCallId -> $status');

        if (toolCallId != null && status != null) {
          updateToolCall(toolCallId, status);
        }
      }
    });
  }

  Future<void> setConversation(String? conversationId) async {
    _currentConversationId = conversationId;
    if (conversationId == null) {
      state = AsyncValue.data(MessageState(messages: []));
      return;
    }
    await _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    if (_currentConversationId == null) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      final messages = await apiClient.getMessages(_currentConversationId!);

      state.whenData((currentState) {
        // If we were waiting for response or streaming, and now we have a new message, clear those states
        final hadStreamingOrWaiting = currentState.isWaitingForResponse || currentState.streamingContent != null;
        final hasNewMessage = messages.length > currentState.messages.length;

        state = AsyncValue.data(MessageState(
          messages: messages,
          streamingContent: (hadStreamingOrWaiting && hasNewMessage) ? null : currentState.streamingContent,
          isWaitingForResponse: (hadStreamingOrWaiting && hasNewMessage) ? false : currentState.isWaitingForResponse,
        ));
      });

      // If state wasn't data before, just set it
      if (state is! AsyncData) {
        state = AsyncValue.data(MessageState(messages: messages));
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void setWaitingForResponse() {
    state.whenData((currentState) {
      state = AsyncValue.data(currentState.copyWith(
        isWaitingForResponse: true,
        clearStreaming: true,
      ));
    });
  }

  void addStreamingChunk(String chunk) {
    state.whenData((currentState) {
      final newContent = (currentState.streamingContent ?? '') + chunk;
      state = AsyncValue.data(currentState.copyWith(
        streamingContent: newContent,
        isWaitingForResponse: false,
      ));
    });
  }

  void clearStreaming() {
    state.whenData((currentState) {
      state = AsyncValue.data(currentState.copyWith(
        clearStreaming: true,
        isWaitingForResponse: false,
        clearToolCalls: true,
      ));
    });
  }

  void addToolCall(String id, String title, String kind, String status) {
    state.whenData((currentState) {
      final toolCalls = List<ToolCallState>.from(currentState.activeToolCalls);
      toolCalls.add(ToolCallState(
        id: id,
        title: title,
        kind: kind,
        status: status,
      ));
      state = AsyncValue.data(currentState.copyWith(
        activeToolCalls: toolCalls,
        isWaitingForResponse: false,
      ));
    });
  }

  void updateToolCall(String id, String status) {
    state.whenData((currentState) {
      final toolCalls = currentState.activeToolCalls.map((tc) {
        if (tc.id == id) {
          return tc.copyWith(status: status);
        }
        return tc;
      }).toList();

      // If all tool calls are completed, clear them
      final allCompleted = toolCalls.every((tc) => tc.status == 'completed');

      state = AsyncValue.data(currentState.copyWith(
        activeToolCalls: toolCalls,
        clearToolCalls: allCompleted,
      ));
    });
  }

  Future<void> refresh() async {
    await _fetchMessages();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _wsSubscription?.cancel();
    super.dispose();
  }
}

// WebSocket Client Provider
final webSocketClientProvider = Provider((ref) {
  final wsClient = ref.read(apiClientProvider).wsClient;
  return wsClient;
});

// Message State Provider
final messageStateProvider = StateNotifierProvider<MessageNotifier, AsyncValue<MessageState>>((ref) {
  return MessageNotifier(ref);
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
    // Set waiting state
    ref.read(messageStateProvider.notifier).setWaitingForResponse();

    final apiClient = ref.read(apiClientProvider);
    final message = await apiClient.sendMessage(
      conversationId: conversationId,
      content: content,
    );

    // Refresh the message list
    await ref.read(messageStateProvider.notifier).refresh();

    return message;
  }
}
