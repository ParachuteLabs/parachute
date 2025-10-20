import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_constants.dart';

class WebSocketClient {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  String? _currentSessionId;
  bool _isConnected = false;

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  bool get isConnected => _isConnected;
  String? get currentSessionId => _currentSessionId;

  Future<void> connect() async {
    if (_isConnected) return;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(ApiConstants.websocketUrl),
      );

      _isConnected = true;

      _channel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data as String) as Map<String, dynamic>;
            _messageController.add(message);
          } catch (e) {
            print('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _isConnected = false;
        },
        onDone: () {
          print('WebSocket connection closed');
          _isConnected = false;
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      _isConnected = false;
      rethrow;
    }
  }

  void subscribe(String sessionId) {
    if (!_isConnected) {
      throw Exception('WebSocket not connected');
    }

    _currentSessionId = sessionId;
    _sendMessage({
      'type': 'subscribe',
      'payload': {
        'session_id': sessionId,
      },
    });
  }

  void unsubscribe() {
    if (!_isConnected || _currentSessionId == null) return;

    _sendMessage({
      'type': 'unsubscribe',
      'payload': {},
    });
    _currentSessionId = null;
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_channel == null || !_isConnected) {
      throw Exception('WebSocket not connected');
    }
    _channel!.sink.add(jsonEncode(message));
  }

  Future<void> disconnect() async {
    if (_currentSessionId != null) {
      unsubscribe();
    }
    await _channel?.sink.close();
    _isConnected = false;
    _currentSessionId = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
