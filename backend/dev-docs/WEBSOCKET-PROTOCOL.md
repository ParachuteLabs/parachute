# WebSocket Protocol

**Status:** To be implemented in Phase 4

---

## Overview

The WebSocket connection provides real-time bidirectional communication between the Flutter frontend and Go backend for chat streaming.

**Endpoint:** `ws://localhost:8080/ws`

---

## Connection Flow

```
1. Flutter connects to ws://localhost:8080/ws
2. Backend accepts connection
3. Flutter sends authentication (JWT token)
4. Backend validates and stores connection
5. Bidirectional communication begins
```

---

## Message Format

All messages are JSON:

```json
{
  "type": "event_name",
  "payload": { /* event-specific data */ }
}
```

---

## Events: Backend → Flutter

Events sent from the backend to the Flutter client.

### `message_chunk`

Streaming text from Claude AI.

```json
{
  "type": "message_chunk",
  "payload": {
    "conversation_id": "conv_123",
    "session_id": "sess_abc",
    "chunk": "Here is some text..."
  }
}
```

### `tool_call`

Claude is requesting to use a tool.

```json
{
  "type": "tool_call",
  "payload": {
    "conversation_id": "conv_123",
    "tool_call_id": "call_456",
    "tool_name": "read_file",
    "arguments": {
      "path": "/path/to/file.txt"
    },
    "status": "pending"  // pending, approved, denied, completed
  }
}
```

### `permission_request`

Claude needs user permission to perform an action.

```json
{
  "type": "permission_request",
  "payload": {
    "conversation_id": "conv_123",
    "permission_id": "perm_789",
    "tool_name": "edit_file",
    "description": "Edit file.txt at line 42",
    "risk_level": "medium"  // low, medium, high
  }
}
```

### `tool_result`

Result of a tool execution.

```json
{
  "type": "tool_result",
  "payload": {
    "conversation_id": "conv_123",
    "tool_call_id": "call_456",
    "success": true,
    "result": "File contents..."
  }
}
```

### `message_complete`

Claude has finished responding.

```json
{
  "type": "message_complete",
  "payload": {
    "conversation_id": "conv_123",
    "session_id": "sess_abc",
    "message_id": "msg_xyz"
  }
}
```

### `error`

An error occurred.

```json
{
  "type": "error",
  "payload": {
    "conversation_id": "conv_123",
    "code": "acp_error",
    "message": "Failed to process prompt",
    "details": "..."
  }
}
```

---

## Commands: Flutter → Backend

Commands sent from Flutter to the backend.

### `send_message`

User sends a message.

```json
{
  "type": "send_message",
  "payload": {
    "conversation_id": "conv_123",
    "content": "Tell me about Go"
  }
}
```

### `approve_permission`

User approves or denies a permission request.

```json
{
  "type": "approve_permission",
  "payload": {
    "permission_id": "perm_789",
    "approved": true  // true or false
  }
}
```

### `cancel`

User cancels the current operation.

```json
{
  "type": "cancel",
  "payload": {
    "conversation_id": "conv_123"
  }
}
```

---

## Connection Management

### Authentication

After connecting, Flutter must send JWT token:

```json
{
  "type": "auth",
  "payload": {
    "token": "jwt_token_here"
  }
}
```

### Heartbeat/Ping

Keep connection alive:

```json
{
  "type": "ping",
  "payload": {}
}
```

Response:

```json
{
  "type": "pong",
  "payload": {}
}
```

### Reconnection

If connection drops:
1. Flutter detects disconnect
2. Wait 1 second
3. Attempt reconnect with exponential backoff
4. Re-authenticate on successful connection
5. Resume conversation

---

## Implementation Notes

### Backend (Go)

```go
type WebSocketHandler struct {
    connections map[string]*websocket.Conn
    acpClient   *acp.Client
}

func (h *WebSocketHandler) HandleConnection(c *fiber.Ctx) error {
    conn, err := upgrader.Upgrade(c.Response(), c.Request(), nil)
    if err != nil {
        return err
    }
    defer conn.Close()

    // Listen for commands from Flutter
    go h.listenForCommands(conn)

    // Listen for ACP events and broadcast to Flutter
    go h.listenForACPEvents(conn)

    // Keep connection alive
    select {}
}
```

### Frontend (Flutter)

```dart
class WebSocketService {
  WebSocketChannel? _channel;
  final _eventController = StreamController<WSEvent>.broadcast();

  Stream<WSEvent> get events => _eventController.stream;

  void connect() {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:8080/ws'),
    );

    _channel!.stream.listen((data) {
      final event = WSEvent.fromJson(jsonDecode(data));
      _eventController.add(event);
    });
  }

  void sendCommand(WSCommand command) {
    _channel!.sink.add(jsonEncode(command.toJson()));
  }
}
```

---

## Error Handling

### Connection Errors

- Network unavailable: Show offline indicator
- Authentication failed: Redirect to login
- Backend down: Show retry button

### Message Errors

- Invalid JSON: Log and ignore
- Unknown event type: Log warning
- ACP error: Show user-friendly message

---

## Testing

### Manual Testing

```bash
# Using websocat
websocat ws://localhost:8080/ws

# Send message
{"type":"send_message","payload":{"conversation_id":"test","content":"Hello"}}
```

### Automated Testing

- Test event serialization/deserialization
- Test reconnection logic
- Test message ordering
- Test error scenarios

---

## References

- WebSocket RFC: https://datatracker.ietf.org/doc/html/rfc6455
- Fiber WebSocket: https://docs.gofiber.io/api/middleware/websocket
- Flutter web_socket_channel: https://pub.dev/packages/web_socket_channel

---

**Last Updated:** October 20, 2025
**Status:** Protocol defined, ready for Phase 4 implementation
