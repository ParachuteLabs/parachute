import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/space.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import './websocket_client.dart';

class ApiClient {
  final Dio _dio;
  final WebSocketClient wsClient;

  ApiClient({String? baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
          },
        )),
        wsClient = WebSocketClient() {
    // Connect WebSocket on initialization
    wsClient.connect().catchError((error) {
      print('Failed to connect WebSocket: $error');
    });
  }

  // Spaces

  Future<List<Space>> getSpaces() async {
    try {
      final response = await _dio.get('/api/spaces');
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      final List<dynamic> spaces = data['spaces'] as List<dynamic>;
      return spaces.map((json) => Space.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Space> getSpace(String id) async {
    try {
      final response = await _dio.get('/api/spaces/$id');
      return Space.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Space> createSpace({
    required String name,
    required String path,
  }) async {
    try {
      final response = await _dio.post(
        '/api/spaces',
        data: {
          'name': name,
          'path': path,
        },
      );
      return Space.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Space> updateSpace({
    required String id,
    String? name,
    String? path,
  }) async {
    try {
      final response = await _dio.put(
        '/api/spaces/$id',
        data: {
          if (name != null) 'name': name,
          if (path != null) 'path': path,
        },
      );
      return Space.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteSpace(String id) async {
    try {
      await _dio.delete('/api/spaces/$id');
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Conversations

  Future<List<Conversation>> getConversations(String spaceId) async {
    try {
      final response = await _dio.get(
        '/api/conversations',
        queryParameters: {'space_id': spaceId},
      );
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      final List<dynamic> conversations = data['conversations'] as List<dynamic>;
      return conversations
          .map((json) => Conversation.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Conversation> createConversation({
    required String spaceId,
    required String title,
  }) async {
    try {
      final response = await _dio.post(
        '/api/conversations',
        data: {
          'space_id': spaceId,
          'title': title,
        },
      );
      return Conversation.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Messages

  Future<List<Message>> getMessages(String conversationId) async {
    try {
      final response = await _dio.get(
        '/api/messages',
        queryParameters: {'conversation_id': conversationId},
      );
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      final List<dynamic> messages = data['messages'] as List<dynamic>;
      return messages
          .map((json) => Message.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Message> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    try {
      final response = await _dio.post(
        '/api/messages',
        data: {
          'conversation_id': conversationId,
          'content': content,
        },
      );
      return Message.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Error handling

  Exception _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return Exception('Connection timeout. Please check your internet connection.');
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final message = error.response?.data['error'] ?? 'Unknown error';
          return Exception('Server error ($statusCode): $message');
        case DioExceptionType.cancel:
          return Exception('Request cancelled');
        default:
          return Exception('Network error: ${error.message}');
      }
    }
    return Exception('Unexpected error: $error');
  }
}
