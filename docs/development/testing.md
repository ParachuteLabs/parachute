# Parachute Testing Guide

**Last Updated:** 2025-10-23

This is the single source of truth for all testing in the Parachute project, covering automated tests, manual testing procedures, and testing strategy.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Test Overview](#test-overview)
3. [Running Tests](#running-tests)
4. [What Tests Catch](#what-tests-catch)
5. [Manual Testing](#manual-testing)
6. [Testing Strategy](#testing-strategy)
7. [Adding New Tests](#adding-new-tests)
8. [Quality Gates](#quality-gates)

---

## Quick Start

```bash
# Run all automated tests
./test.sh

# Run end-to-end tests (requires backend running)
./e2e-test.sh
```

**Current Status:** ✅ All 40 tests passing
- 11 backend integration tests
- 13 Flutter unit tests
- 16 E2E API tests

---

## Test Overview

### Test Coverage Summary

The Parachute project includes comprehensive automated tests that catch common bugs like type casting errors, API response format issues, and integration problems. This allows rapid iteration with confidence.

### Backend Tests (Go)
- **API Integration Tests**: All REST endpoints (spaces, conversations, messages)
- **WebSocket Tests**: Connection management, broadcasting, subscription
- **Location**: `backend/internal/api/handlers/*_test.go`

### Frontend Tests (Flutter/Dart)
- **Model Tests**: JSON serialization/deserialization
- **API Response Format Tests**: Type safety and structure validation
- **Widget Tests**: Basic app loading
- **Location**: `app/test/`

### E2E Tests
- **API Flow Tests**: Complete workflows from space creation to message streaming
- **Location**: `e2e-test.sh`

---

## Running Tests

### All Tests

```bash
./test.sh           # Unit and integration tests
./test.sh -v        # Verbose output
```

Options:
- `--backend-only` - Run only Go tests
- `--flutter-only` - Run only Flutter tests
- `-v` - Verbose output

### Backend Tests

```bash
cd backend
make test           # Run all tests
make test-v         # Verbose output
make test-coverage  # Generate coverage report
```

Or use Go directly:
```bash
go test ./...                           # All tests
go test ./internal/api/handlers/...     # API tests only
go test -v -race ./...                  # With race detection
go test -coverprofile=coverage.out ./... # With coverage
```

### Flutter Tests

```bash
cd app
flutter test                            # All tests
flutter test test/api_client_test.dart  # Specific file
flutter test --coverage                 # With coverage
```

### End-to-End Tests

**IMPORTANT:** E2E tests require the backend to be running.

```bash
# Terminal 1: Start backend
cd backend && ./bin/server

# Terminal 2: Run E2E tests
./e2e-test.sh
```

E2E test coverage:
- Health check
- Space CRUD operations
- Conversation CRUD operations
- Message sending and retrieval
- WebSocket streaming (manual verification)
- Error handling (validation, missing params)

---

## What Tests Catch

### 1. Type Casting Errors ✅

**Common Bug:**
```dart
// ❌ CRASHES at runtime
final List<dynamic> data = response.data as List<dynamic>;
```

**Test That Catches It:**
```dart
test('Type casting from Map to List should fail', () {
  final response = {'spaces': []};
  expect(() => response as List<dynamic>, throwsA(isA<TypeError>()));
  expect(response['spaces'], isA<List>()); // ✅ Correct
});
```

### 2. API Response Format Issues ✅

**Common Bug:** Backend returns `{"spaces": [...]}` but client expects `[...]`

**Backend Test:**
```go
func TestSpaceAPI(t *testing.T) {
  resp, _ := app.Test(req)
  var result map[string]interface{}
  json.NewDecoder(resp.Body).Decode(&result)
  spaces, ok := result["spaces"].([]interface{})
  assert.True(t, ok, "Expected 'spaces' key with array value")
}
```

### 3. Model Serialization ✅

**Test:**
```dart
test('Space.fromJson parses correctly', () {
  final json = {
    'id': '1',
    'user_id': 'user1',  // snake_case from API
    'name': 'Test Space',
    'path': '/test/path',
    'created_at': '2025-01-01T00:00:00Z',
    'updated_at': '2025-01-01T00:00:00Z',
  };
  final space = Space.fromJson(json);
  expect(space.id, '1');
  expect(space.userId, 'user1');  // Converts to camelCase
});
```

### 4. API Validation ✅

**Test:**
```go
func TestConversationAPI(t *testing.T) {
  t.Run("ListConversationsWithoutSpaceID", func(t *testing.T) {
    req := httptest.NewRequest(http.MethodGet, "/api/conversations", nil)
    resp, _ := app.Test(req)
    assert.Equal(t, http.StatusBadRequest, resp.StatusCode)
  })
}
```

---

## Manual Testing

While automated tests catch most bugs, manual testing is required for:

### 1. Streaming Chat Experience

**Test Checklist:**
- [ ] Message sent → "..." appears immediately (< 100ms)
- [ ] First text chunk appears within 2 seconds
- [ ] Text streams smoothly without jank
- [ ] Tool calls appear as they're initiated
- [ ] Tool call icons match tool types (cloud, document, terminal, etc.)
- [ ] Tool call status updates: spinner → checkmark
- [ ] Multiple tool calls display correctly
- [ ] Auto-scroll follows new content smoothly
- [ ] Can manually scroll up while streaming continues
- [ ] Auto-scroll resumes when scrolling back to bottom
- [ ] Final message persists after streaming completes
- [ ] Message formatting (markdown) renders correctly

### 2. UX Comparison with Industry Standards

Compare against Claude Desktop and ChatGPT:

**Response Speed:**
- [ ] Perceived latency matches Claude Desktop
- [ ] "..." feedback is immediate (< 100ms)
- [ ] First chunk arrives in ~2 seconds
- [ ] Chunk arrival rate feels natural

**Visual Feedback:**
- [ ] Loading states are clear
- [ ] Tool calls are visible but not distracting
- [ ] Animations are smooth (60fps target)
- [ ] No layout shifts during streaming
- [ ] Text rendering is clean and readable

**Error Handling:**
- [ ] Network errors show user-friendly messages
- [ ] Failed messages can be retried
- [ ] Partial streaming handled gracefully
- [ ] WebSocket disconnects recover automatically

### 3. Multi-Conversation Testing

- [ ] Create multiple conversations in same space
- [ ] Switch between conversations while streaming
- [ ] Verify correct content in each conversation
- [ ] No cross-contamination between conversations
- [ ] WebSocket stays connected across navigation
- [ ] No memory leaks with many conversations

### 4. Platform-Specific Testing

**macOS:**
- [ ] App launches without errors
- [ ] Native window controls work
- [ ] Keyboard shortcuts function
- [ ] Menu bar integration

**iOS (future):**
- [ ] Touch gestures (scroll, tap, swipe)
- [ ] Keyboard handling
- [ ] Background/foreground transitions

**Web (future):**
- [ ] Browser compatibility
- [ ] Responsive layout
- [ ] CORS handling

### 5. Performance Testing

**Stress Tests:**
- [ ] Send 10 messages rapidly
- [ ] Open conversation with 100+ messages
- [ ] Stream very long response (5000+ words)
- [ ] Multiple tool calls in single response (10+)
- [ ] Switch conversations rapidly (10 times in 10 seconds)

**Resource Usage:**
- [ ] Monitor memory usage during long session
- [ ] Check for memory leaks
- [ ] CPU usage during streaming
- [ ] Network bandwidth consumption

---

## Testing Strategy

### Test Pyramid

```
            /\
           /E2E\        ← Manual + Automated E2E (16 tests)
          /____\
         /      \
        /  Integ.\      ← Integration Tests (11 tests)
       /________\
      /          \
     / Unit Tests \     ← Unit Tests (13 tests)
    /______________\
```

### Coverage Targets

- **Backend**: > 70% code coverage
- **Flutter**: > 60% code coverage (UI code harder to test)
- **Critical Paths**: 100% coverage (auth, messaging, WebSocket)

### Testing Principles

1. **Fast Feedback**: Tests should run in < 30 seconds
2. **Isolation**: Each test independent, can run in any order
3. **Repeatability**: Same input → same output, always
4. **Clarity**: Test names clearly describe what they test
5. **Maintainability**: Easy to update when requirements change

---

## Adding New Tests

### Backend Test Template

```go
// backend/internal/api/handlers/feature_handler_test.go
func TestNewFeature(t *testing.T) {
  app, _ := setupTestApp(t)

  t.Run("DescriptiveTestCaseName", func(t *testing.T) {
    // Arrange
    payload := map[string]interface{}{"key": "value"}
    body, _ := json.Marshal(payload)
    req := httptest.NewRequest(http.MethodPost, "/api/endpoint", bytes.NewReader(body))
    req.Header.Set("Content-Type", "application/json")

    // Act
    resp, err := app.Test(req)
    require.NoError(t, err)
    defer resp.Body.Close()

    // Assert
    assert.Equal(t, http.StatusOK, resp.StatusCode)

    var result map[string]interface{}
    json.NewDecoder(resp.Body).Decode(&result)
    assert.Equal(t, "expected_value", result["field"])
  })
}
```

### Flutter Test Template

```dart
// app/test/feature_test.dart
test('Feature description', () {
  // Arrange
  final testData = {
    'field': 'value',
  };

  // Act
  final result = MyClass.fromJson(testData);

  // Assert
  expect(result.field, 'value');
  expect(result.otherField, isA<ExpectedType>());
});
```

### Table-Driven Tests (Go)

For testing multiple scenarios:

```go
func TestValidation(t *testing.T) {
  tests := []struct {
    name    string
    input   string
    wantErr bool
  }{
    {"valid input", "test@example.com", false},
    {"invalid format", "not-an-email", true},
    {"empty string", "", true},
  }

  for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) {
      err := validate(tt.input)
      if (err != nil) != tt.wantErr {
        t.Errorf("validate() error = %v, wantErr %v", err, tt.wantErr)
      }
    })
  }
}
```

---

## Quality Gates

### Before Committing

- [ ] Run `./test.sh` - all tests pass
- [ ] No new lint warnings
- [ ] Code formatted (`gofmt`, `dart format`)

### Before Merging PR

- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Code coverage maintained or improved
- [ ] Manual testing checklist completed for new features
- [ ] Performance benchmarks within acceptable range
- [ ] Documentation updated

### Before Release

- [ ] All automated tests pass
- [ ] Full manual testing checklist completed
- [ ] Performance testing completed
- [ ] Cross-platform testing (macOS minimum)
- [ ] Security review completed
- [ ] E2E test pass rate > 95%

---

## Test Infrastructure

### Backend Tools
- **Framework**: Go's built-in `testing` package
- **Assertions**: `github.com/stretchr/testify/assert`
- **HTTP Testing**: `net/http/httptest`
- **Database**: In-memory SQLite for tests
- **WebSocket**: `gorilla/websocket` test utilities

### Flutter Tools
- **Framework**: Flutter's `flutter_test`
- **Mocking**: `http_mock_adapter` for HTTP
- **Assertions**: Built-in matchers
- **Widget Testing**: `flutter_test` widget testers

### CI/CD Integration

The test scripts are designed for CI/CD:

```bash
./test.sh           # Exit code 0 = pass, 1 = fail
./test.sh -v        # Verbose output for debugging
```

---

## Known Limitations

### Not Currently Tested
- [ ] WebSocket reconnection logic
- [ ] ACP process crash recovery
- [ ] Concurrent message sending to same conversation
- [ ] Database migration rollback
- [ ] File upload/download functionality (not implemented)
- [ ] MCP server integration (not implemented)

### Future Testing Improvements
- [ ] Add WebSocket integration tests
- [ ] Add Flutter integration tests (stubbed in `app/integration_test/`)
- [ ] Add performance benchmarks
- [ ] Add load testing (100+ concurrent users)
- [ ] Add visual regression tests (golden files)
- [ ] Add accessibility testing

---

## Debugging Failed Tests

### Backend Test Failures

1. **Check test output**: `cd backend && go test -v ./...`
2. **Run single test**: `go test -v -run TestName`
3. **Add debug logging**: Use `t.Logf()` in tests
4. **Check database state**: Tests use in-memory DB, so state is isolated

### Flutter Test Failures

1. **Verbose output**: `flutter test -v`
2. **Single test**: `flutter test test/file_test.dart --name "test name"`
3. **Debug mode**: Run tests in IDE with breakpoints
4. **Check widget tree**: Use `debugDumpApp()` in widget tests

### E2E Test Failures

1. **Check backend logs**: Backend should be running with verbose logging
2. **Verify WebSocket connection**: Check browser DevTools Network tab
3. **Check conversation state**: Use API directly to inspect state
4. **Review test script output**: `./e2e-test.sh` prints detailed curl output

---

## Benefits of Test Coverage

✅ **Catches bugs early** - Before manual testing
✅ **Fast feedback** - Tests run in seconds
✅ **Regression prevention** - Ensures fixes don't break existing features
✅ **Documentation** - Tests show how APIs should work
✅ **Confidence** - Make changes knowing tests will catch issues
✅ **Refactoring safety** - Change internals without breaking contracts

---

## Resources

- **Backend Tests**: `backend/internal/api/handlers/*_test.go`
- **Flutter Tests**: `app/test/`
- **E2E Script**: `./e2e-test.sh`
- **Test Runner**: `./test.sh`
- **CI/CD**: (To be configured)

---

**Questions or issues with tests?** Check existing test files for examples, or see the main README.md for project context.
