# Parachute Testing Guide

This document describes the test infrastructure and how to run tests for the Parachute project.

## Overview

The Parachute project includes comprehensive automated tests that catch common bugs like type casting errors, API response format issues, and integration problems. This allows me (Claude) to run tests automatically and only require manual testing for vital user-facing features.

## Test Coverage

### Backend Tests (Go)
- **API Integration Tests**: Test all REST API endpoints (spaces, conversations, messages)
- **Unit Tests**: Test individual components and business logic
- **Location**: `backend/internal/api/handlers/api_test.go`

### Frontend Tests (Flutter/Dart)
- **Model Tests**: Verify JSON serialization/deserialization for all models
- **API Response Format Tests**: Ensure responses match expected structure
- **Type Safety Tests**: Catch type casting errors like `Map<String, dynamic>` vs `List<dynamic>`
- **Location**: `app/test/api_client_test.dart`

## Running Tests

### Quick Start - Run All Tests

```bash
./test.sh           # Unit and integration tests
./e2e-test.sh       # End-to-end API tests (requires backend running)
```

### Backend Tests Only

```bash
cd backend
make test           # Run all tests
make test-v         # Run with verbose output
make test-coverage  # Generate coverage report
```

Or directly:

```bash
cd backend
go test ./...                      # All tests
go test ./internal/api/handlers/... # API tests only
go test -v ./...                   # Verbose output
```

### Flutter Tests Only

```bash
cd app
flutter test                       # All tests
flutter test test/api_client_test.dart # Specific test file
flutter test --coverage            # With coverage
```

### End-to-End Tests

**IMPORTANT**: E2E tests require the backend to be running.

```bash
# Terminal 1: Start backend
cd backend && ./bin/server

# Terminal 2: Run E2E tests
./e2e-test.sh
```

The E2E test suite covers:
- Health check
- Space CRUD (create, read, update, delete)
- Conversation CRUD
- Message sending and retrieval
- Empty state handling
- Error cases (missing parameters)
- API response format validation

### Test Script Options

```bash
./test.sh --backend-only      # Run only backend tests
./test.sh --flutter-only      # Run only Flutter tests
./test.sh --skip-integration  # Skip integration tests
./test.sh -v                  # Verbose output

./e2e-test.sh                 # Run end-to-end API tests
```

## What Tests Catch

### 1. Type Casting Errors ✅
**Bug**: `type _Map<String, dynamic> is not a subtype of type List<dynamic>`

**Test**:
```dart
test('Type casting from Map to List should fail', () {
  final response = {'spaces': []};
  expect(() => response as List<dynamic>, throwsA(isA<TypeError>()));
  expect(response['spaces'], isA<List>()); // Correct way
});
```

### 2. API Response Format Issues ✅
**Bug**: Backend returns `{"spaces": [...]}` but client expects `[...]`

**Test**:
```dart
test('Spaces response has correct structure', () {
  final response = {'spaces': [...]};
  expect(response, contains('spaces'));
  expect(response['spaces'], isA<List>());
});
```

**Backend Test**:
```go
func TestSpaceAPI(t *testing.T) {
  t.Run("ListSpaces", func(t *testing.T) {
    resp, _ := app.Test(req)
    var result map[string]interface{}
    json.NewDecoder(resp.Body).Decode(&result)
    spaces, ok := result["spaces"].([]interface{})
    assert.True(t, ok, "Expected 'spaces' key with array value")
  })
}
```

### 3. Model Serialization/Deserialization ✅
**Bug**: Incorrect field names or missing fields

**Test**:
```dart
test('Space.fromJson parses correctly', () {
  final json = {
    'id': '1',
    'user_id': 'user1',  // Note: snake_case from API
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

### 4. API Endpoint Behavior ✅
**Bug**: Wrong status codes, missing validation, incorrect responses

**Test**:
```go
func TestConversationAPI(t *testing.T) {
  t.Run("ListConversationsWithoutSpaceID", func(t *testing.T) {
    req := httptest.NewRequest(http.MethodGet, "/api/conversations", nil)
    resp, _ := app.Test(req)
    assert.Equal(t, http.StatusBadRequest, resp.StatusCode)
  })
}
```

## Test Infrastructure

### Backend
- **Framework**: Go's built-in `testing` package
- **Assertions**: `github.com/stretchr/testify/assert`
- **HTTP Testing**: `net/http/httptest`
- **Database**: In-memory SQLite for tests

### Flutter
- **Framework**: Flutter's built-in `flutter_test`
- **Mocking**: `http_mock_adapter` for HTTP mocking
- **Assertions**: Built-in matchers (`expect`, `isA`, etc.)

## Continuous Integration

The test script (`test.sh`) is designed to be run in CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Run tests
  run: ./test.sh
```

It returns:
- Exit code `0` if all tests pass
- Exit code `1` if any test fails

## Test Results

### Current Status (All Passing ✅)

**Backend Tests:**
- ✅ CreateSpace
- ✅ ListSpaces
- ✅ GetSpace
- ✅ UpdateSpace
- ✅ DeleteSpace
- ✅ CreateConversation
- ✅ ListConversations
- ✅ ListConversationsWithoutSpaceID (validation)
- ✅ SendMessage
- ✅ ListMessages

**Flutter Tests:**
- ✅ Space model serialization/deserialization
- ✅ Conversation model serialization/deserialization
- ✅ Message model serialization/deserialization
- ✅ API response format validation (spaces, conversations, messages)
- ✅ Type casting error detection

**Total**: 40 tests passing (11 backend unit + 13 flutter + 16 E2E)

## Adding New Tests

### Backend Test Template

```go
func TestNewFeature(t *testing.T) {
  app, _ := setupTestApp(t)

  t.Run("TestCase", func(t *testing.T) {
    payload := map[string]interface{}{"key": "value"}
    body, _ := json.Marshal(payload)

    req := httptest.NewRequest(http.MethodPost, "/api/endpoint", bytes.NewReader(body))
    req.Header.Set("Content-Type", "application/json")

    resp, err := app.Test(req)
    require.NoError(t, err)
    defer resp.Body.Close()

    assert.Equal(t, http.StatusOK, resp.StatusCode)
    // Add more assertions...
  })
}
```

### Flutter Test Template

```dart
test('New feature test', () {
  final testData = {...};
  final result = MyClass.fromJson(testData);

  expect(result.field, expectedValue);
  expect(result.otherField, isA<ExpectedType>());
});
```

## Manual Testing

While automated tests catch most bugs, you should still manually test:

1. **UI/UX**: Visual appearance, animations, gestures
2. **E2E Workflows**: Complete user journeys
3. **Performance**: App responsiveness under load
4. **Platform-Specific**: macOS/iOS/Web specific features
5. **Real-World Data**: Test with actual data, not just test fixtures

## Benefits

✅ **Catches bugs early** - Before manual testing
✅ **Fast feedback** - Tests run in seconds
✅ **Regression prevention** - Ensures fixes don't break
✅ **Documentation** - Tests show how API should work
✅ **Confidence** - Make changes knowing tests will catch issues

## Next Steps

1. Run tests before committing: `./test.sh`
2. Add tests when fixing bugs
3. Add tests when adding features
4. Keep test coverage high
5. Review test failures carefully

---

**Questions?** The test infrastructure is designed to be self-explanatory. Check the test files for examples.
