# Testing Strategy: Parachute Flutter-Go Bridge

## Overview

This document outlines the comprehensive testing strategy for ensuring the Flutter frontend and Go backend work seamlessly together, providing a smooth streaming chat experience comparable to Claude Desktop and ChatGPT.

## Testing Pyramid

```
                    /\
                   /  \
                  / E2E\
                 /______\
                /        \
               /Integration\
              /____________\
             /              \
            /  Unit Tests    \
           /________________\
```

## 1. Unit Tests

### Backend (Go)
- **WebSocket Handler Tests** (`backend/internal/api/handlers/websocket_handler_test.go`)
  - Message serialization/deserialization
  - Connection management (subscribe/unsubscribe)
  - Broadcast to multiple connections
  - Error handling for dead connections

- **Message Handler Tests** (`backend/internal/api/handlers/message_handler_test.go`)
  - Session creation and reuse
  - Message chunk accumulation
  - Tool call state tracking
  - Notification filtering by session ID

- **ACP Client Tests** (`backend/internal/acp/client_test.go`)
  - Notification broadcasting to multiple sessions
  - Session registration/unregistration
  - Request routing by session ID

### Frontend (Flutter)
- **Message Provider Tests** (`app/test/message_provider_test.dart`)
  - State transitions (waiting → streaming → completed)
  - Tool call state management
  - WebSocket message parsing
  - Conversation ID filtering

- **WebSocket Client Tests** (`app/test/websocket_client_test.dart`)
  - Connection lifecycle
  - Message deserialization
  - Reconnection logic
  - Error handling

## 2. Integration Tests

### WebSocket Bridge Tests
**Location**: `backend/tests/integration/websocket_bridge_test.go`

Test the full WebSocket communication flow:

```go
func TestWebSocketMessageFlow(t *testing.T) {
    // 1. Start test server
    // 2. Connect WebSocket client
    // 3. Trigger message chunk broadcast
    // 4. Verify client receives message
    // 5. Verify message format
}

func TestToolCallBroadcast(t *testing.T) {
    // 1. Start test server
    // 2. Connect WebSocket client
    // 3. Simulate tool_call notification
    // 4. Verify client receives tool call
    // 5. Simulate tool_call_update notification
    // 6. Verify status update received
}

func TestMultipleClients(t *testing.T) {
    // 1. Connect multiple WebSocket clients
    // 2. Broadcast message chunk
    // 3. Verify all clients receive message
    // 4. Verify conversation ID filtering works
}

func TestConnectionResilience(t *testing.T) {
    // 1. Connect client
    // 2. Disconnect client abruptly
    // 3. Verify server handles gracefully
    // 4. Verify dead connection removed
}
```

### API Integration Tests
**Location**: `backend/tests/integration/api_test.go`

```go
func TestSendMessageToStreamingResponse(t *testing.T) {
    // 1. Create space and conversation
    // 2. Send message via API
    // 3. Verify user message created
    // 4. Connect WebSocket
    // 5. Verify streaming chunks received
    // 6. Verify assistant message saved after completion
}

func TestConcurrentConversations(t *testing.T) {
    // 1. Create 3 conversations
    // 2. Send messages to all simultaneously
    // 3. Verify each gets correct streaming updates
    // 4. Verify no cross-contamination
}
```

## 3. End-to-End Tests

### Manual Testing Checklist
**Location**: `MANUAL-TESTING.md`

#### Streaming Experience
- [ ] Message sent → "..." appears immediately (< 100ms)
- [ ] First text chunk appears within 2 seconds
- [ ] Text streams smoothly (no jank or stuttering)
- [ ] Tool calls appear as they're initiated
- [ ] Tool call status updates from pending → completed
- [ ] Multiple tool calls display correctly
- [ ] Auto-scroll follows new content
- [ ] Final message persists after streaming completes

#### UX Comparison with Industry Standards
Compare against Claude Desktop and ChatGPT:

**Response Speed**
- [ ] Perceived latency matches Claude Desktop (immediate "..." feedback)
- [ ] Chunk arrival rate feels natural (not too slow, not overwhelming)

**Visual Feedback**
- [ ] Loading states are clear and unambiguous
- [ ] Tool calls are visible but not distracting
- [ ] Animations are smooth (60fps)
- [ ] No layout shifts during streaming

**Error Handling**
- [ ] Network errors show user-friendly messages
- [ ] Failed messages can be retried
- [ ] Partial streaming handled gracefully

#### Multi-Conversation Testing
- [ ] Switch between conversations while streaming
- [ ] Verify correct content in each conversation
- [ ] No memory leaks with many conversations
- [ ] WebSocket stays connected across navigation

### Automated E2E Tests
**Location**: `tests/e2e/`

Using Flutter integration tests with a mock Go backend:

```dart
testWidgets('Streaming message flow', (tester) async {
  // 1. Launch app
  // 2. Create conversation
  // 3. Send message
  // 4. Verify loading indicator appears
  // 5. Mock WebSocket receives chunk
  // 6. Verify text appears in UI
  // 7. Mock tool call broadcast
  // 8. Verify tool indicator appears
  // 9. Mock completion
  // 10. Verify final message persists
});

testWidgets('Tool call visualization', (tester) async {
  // 1. Send message requiring tools
  // 2. Verify tool indicators appear
  // 3. Verify icons match tool types
  // 4. Verify status changes (spinner → check)
  // 5. Verify tool calls clear on completion
});

testWidgets('Multiple concurrent chats', (tester) async {
  // 1. Create 2 conversations
  // 2. Send messages to both
  // 3. Verify correct streaming in each
  // 4. Switch between conversations
  // 5. Verify state preserved
});
```

## 4. Performance Testing

### Metrics to Track

**Backend**
- WebSocket broadcast latency (target: < 10ms)
- Message throughput (chunks/second)
- Memory usage with N concurrent clients
- CPU usage during streaming

**Frontend**
- Frame rate during streaming (target: 60fps)
- UI update latency (target: < 16ms)
- Memory usage during long conversations
- WebSocket reconnection time

### Load Testing
**Location**: `tests/load/websocket_load_test.go`

```go
func TestWebSocketLoadWith100Clients(t *testing.T) {
    // 1. Connect 100 WebSocket clients
    // 2. Broadcast 1000 chunks
    // 3. Measure:
    //    - Broadcast latency percentiles (p50, p95, p99)
    //    - Message delivery success rate
    //    - Server resource usage
}
```

## 5. Testing Tools & Infrastructure

### Backend
- **Testing Framework**: Go's `testing` package
- **WebSocket Testing**: `gorilla/websocket` test utilities
- **Mocking**: `github.com/stretchr/testify/mock`
- **Integration**: Real SQLite in-memory DB

### Frontend
- **Unit Tests**: Flutter's `test` package
- **Widget Tests**: `flutter_test`
- **Integration Tests**: `integration_test` package
- **Mocking**: `mockito` for HTTP/WebSocket

### CI/CD Integration
```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
      - run: cd backend && go test ./... -v -race -coverprofile=coverage.out
      - run: go tool cover -html=coverage.out -o coverage.html

  frontend-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: cd app && flutter test --coverage
      - run: cd app && flutter test integration_test/

  e2e-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Start backend
        run: cd backend && go run cmd/server/main.go &
      - name: Run Flutter E2E
        run: cd app && flutter test integration_test/ -d macos
```

## 6. Test Data Management

### Fixtures
**Location**: `tests/fixtures/`

- `acp_notifications.json` - Sample ACP notification payloads
- `conversations.json` - Test conversation data
- `messages.json` - Sample messages with various content types

### Test Helpers
```go
// backend/tests/helpers/helpers.go
func CreateTestServer() *fiber.App { ... }
func ConnectTestWebSocket(serverURL string) (*websocket.Conn, error) { ... }
func CreateTestConversation(spaceID string) *Conversation { ... }
```

```dart
// app/test/helpers/test_helpers.dart
Future<void> pumpAppWithMockBackend(WidgetTester tester) async { ... }
MockWebSocketClient createMockWebSocketClient() { ... }
```

## 7. Quality Gates

Before merging any PR:

- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Code coverage > 70%
- [ ] Manual testing checklist completed
- [ ] Performance benchmarks within acceptable range
- [ ] No WebSocket memory leaks
- [ ] Streaming feels smooth (subjective but critical)

## 8. Monitoring & Debugging

### Development Logging Levels
- `DEBUG`: Detailed WebSocket message flow
- `INFO`: Connection lifecycle events
- `WARN`: Recoverable errors
- `ERROR`: Critical failures

### Production Metrics
- WebSocket connection count
- Message delivery success rate
- Average streaming latency
- Error rate by error type

### Debug Tools
- **WebSocket Inspector**: Browser DevTools for WebSocket traffic
- **Flutter DevTools**: Memory profiler, performance overlay
- **Go pprof**: CPU and memory profiling
- **Logging**: Structured JSON logs for production

## 9. Regression Testing

Maintain a suite of regression tests for known issues:

- [ ] Streaming stops mid-message (Issue #X)
- [ ] Tool calls don't update status (Issue #Y)
- [ ] Conversation ID mismatch (Issue #Z)
- [ ] WebSocket disconnects on navigation (Issue #W)

## 10. Success Criteria

The Flutter-Go bridge is considered production-ready when:

1. **Functional**: All features work as designed
2. **Performant**: Meets all performance benchmarks
3. **Reliable**: < 0.1% error rate in production
4. **Smooth**: User experience matches Claude Desktop
5. **Tested**: > 70% code coverage with meaningful tests
6. **Documented**: All tests documented and maintainable

---

**Next Steps:**
1. Implement WebSocket integration test harness
2. Create manual testing checklist
3. Build automated E2E test suite
4. Set up CI/CD pipeline
5. Conduct performance baseline testing
