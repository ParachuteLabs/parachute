# Testing Infrastructure

This directory contains comprehensive testing for the Parachute Flutter-Go bridge.

## Quick Start

### Run All Tests

```bash
# Backend unit tests
cd backend && go test ./... -v

# Backend WebSocket integration tests
./test-websocket.sh

# Flutter unit tests
cd app && flutter test

# Flutter integration tests
cd app && flutter test integration_test/
```

### Manual Testing

Follow the checklist in `MANUAL-TESTING.md` to validate the UX matches industry standards (Claude Desktop, ChatGPT).

## Test Types

### 1. Unit Tests

**Backend** (`backend/internal/.../..._test.go`):
- WebSocket handler message serialization
- Message state management
- ACP notification routing

**Frontend** (`app/test/`):
- Message provider state transitions
- WebSocket client connection logic
- UI widget rendering

### 2. Integration Tests

**WebSocket Bridge** (`backend/tests/integration/websocket_test.go`):
- Message chunk broadcasting
- Tool call notification flow
- Multi-client scenarios
- Connection resilience

Run with: `./test-websocket.sh`

### 3. End-to-End Tests

**Flutter Integration** (`app/integration_test/streaming_test.dart`):
- Complete streaming flow from send to display
- Tool call visualization
- Error handling
- Multi-conversation handling

Run with: `cd app && flutter test integration_test/`

### 4. Manual Testing

**Checklist** (`MANUAL-TESTING.md`):
- Streaming experience validation
- Tool call display verification
- Performance benchmarking
- UX comparison to Claude Desktop/ChatGPT

## Testing Strategy

See `TESTING-STRATEGY.md` for the complete testing approach, including:
- Test pyramid structure
- Quality gates
- Performance benchmarks
- CI/CD integration

## Current Status

### ✅ Implemented
- Testing strategy document
- WebSocket integration test harness
- Manual testing checklist
- Flutter integration test template

### 🚧 In Progress
- Fixing WebSocket message delivery issues
- Implementing mock WebSocket for Flutter tests
- Setting up CI/CD pipeline

### 📋 Planned
- Load testing with 100+ concurrent clients
- Performance profiling tools
- Automated screenshot comparison
- Accessibility testing automation

## Known Issues

1. **WebSocket broadcasts not reaching Flutter consistently**
   - Backend logs show broadcasts sent
   - Frontend not receiving all messages
   - Investigating conversation ID matching

2. **Tool call indicators not displaying**
   - Messages broadcast correctly
   - UI components implemented
   - Debugging state management

## Success Criteria

The Flutter-Go bridge is production-ready when:

- [ ] All unit tests pass (>70% coverage)
- [ ] All integration tests pass
- [ ] Manual testing checklist 100% complete
- [ ] Streaming experience matches Claude Desktop
- [ ] Performance benchmarks met:
  - [ ] WebSocket latency < 10ms
  - [ ] UI frame rate = 60fps during streaming
  - [ ] Memory usage < 200MB

## Contributing

When adding features that involve Flutter-Go communication:

1. Write unit tests first
2. Add integration tests for the bridge
3. Update manual testing checklist
4. Run full test suite before committing
5. Document any new test helpers or utilities

## Debugging Tips

### WebSocket Issues

Enable debug logging:

**Backend**:
```go
log.Printf("📡 Broadcasting chunk to %d connection(s)", connCount)
```

**Frontend**:
```dart
print('📩 WebSocket message received: ${message['type']}');
```

Check logs for:
- Connection count (should be > 0)
- Message type matches expected
- Conversation IDs match
- Payload structure is correct

### Streaming Performance

Monitor with:
- Backend: `pprof` for CPU/memory profiling
- Frontend: Flutter DevTools performance overlay
- Network: Browser DevTools WebSocket inspector

### Test Data

Use fixtures in `tests/fixtures/` for consistent test data:
- `acp_notifications.json` - Sample ACP events
- `conversations.json` - Test conversations
- `messages.json` - Sample chat messages

## Resources

- [WebSocket Testing Best Practices](https://www.testim.io/blog/websocket-testing/)
- [Flutter Integration Testing Guide](https://docs.flutter.dev/testing/integration-tests)
- [Go Testing Patterns](https://go.dev/doc/tutorial/add-a-test)
- [Riverpod Testing](https://riverpod.dev/docs/cookbooks/testing)
