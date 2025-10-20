# Testing Guide

**Status:** Foundation - Testing strategy defined

---

## Overview

This document describes our testing strategy for the Parachute backend.

**Goals:**
- 70%+ unit test coverage
- Integration tests for critical paths
- Fast test execution
- Easy to write and maintain

---

## Test Structure

```
backend/
├── internal/
│   ├── acp/
│   │   ├── client.go
│   │   └── client_test.go       # Unit tests
│   ├── domain/
│   │   ├── space/
│   │   │   ├── service.go
│   │   │   └── service_test.go  # Unit tests
│   └── storage/
│       └── sqlite/
│           └── space_repo_test.go
└── tests/
    ├── integration/             # Integration tests
    │   └── acp_integration_test.go
    └── fixtures/               # Test data
        └── test_data.json
```

---

## Unit Tests

Test individual functions and methods in isolation.

### Example: Domain Service

```go
// internal/domain/space/service_test.go
package space_test

import (
    "testing"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"
)

// Mock repository
type MockSpaceRepo struct {
    mock.Mock
}

func (m *MockSpaceRepo) Create(space *space.Space) error {
    args := m.Called(space)
    return args.Error(0)
}

// Test
func TestCreateSpace(t *testing.T) {
    // Given
    mockRepo := new(MockSpaceRepo)
    mockRepo.On("Create", mock.Anything).Return(nil)

    service := space.NewService(mockRepo)

    // When
    space, err := service.Create("Test Space", "/path/to/space")

    // Then
    assert.NoError(t, err)
    assert.Equal(t, "Test Space", space.Name)
    assert.Equal(t, "/path/to/space", space.Path)
    mockRepo.AssertExpectations(t)
}

func TestCreateSpace_InvalidPath(t *testing.T) {
    // Given
    mockRepo := new(MockSpaceRepo)
    service := space.NewService(mockRepo)

    // When
    _, err := service.Create("Test", "relative/path")

    // Then
    assert.Error(t, err)
    assert.Contains(t, err.Error(), "absolute path")
}
```

### Running Unit Tests

```bash
# Run all tests
go test ./...

# Run specific package
go test ./internal/domain/space

# Run with verbose output
go test -v ./...

# Run with coverage
go test -cover ./...

# Generate coverage report
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

---

## Integration Tests

Test multiple components working together.

### Example: ACP Integration

```go
// tests/integration/acp_integration_test.go
// +build integration

package integration

import (
    "testing"
    "github.com/stretchr/testify/require"
)

func TestACPFullFlow(t *testing.T) {
    // Skip if no API key
    apiKey := os.Getenv("ANTHROPIC_API_KEY")
    if apiKey == "" {
        t.Skip("ANTHROPIC_API_KEY not set")
    }

    // Setup
    client, err := acp.NewClient(apiKey)
    require.NoError(t, err)
    defer client.Close()

    // Initialize
    err = client.Initialize()
    require.NoError(t, err)

    // Create session
    sessionID, err := client.NewSession("/tmp/test-space", nil)
    require.NoError(t, err)
    require.NotEmpty(t, sessionID)

    // Send prompt
    responses := []string{}
    err = client.SessionPrompt(sessionID, "Say hello", func(chunk string) {
        responses = append(responses, chunk)
    })
    require.NoError(t, err)
    require.NotEmpty(t, responses)
}
```

### Running Integration Tests

```bash
# Run with integration tag
go test -tags=integration ./tests/integration/...

# With environment variable
ANTHROPIC_API_KEY=sk-ant-... go test -tags=integration ./tests/integration/...
```

---

## Table-Driven Tests

For testing multiple scenarios:

```go
func TestValidatePath(t *testing.T) {
    tests := []struct {
        name    string
        path    string
        wantErr bool
    }{
        {
            name:    "valid absolute path",
            path:    "/Users/me/space",
            wantErr: false,
        },
        {
            name:    "relative path",
            path:    "relative/path",
            wantErr: true,
        },
        {
            name:    "empty path",
            path:    "",
            wantErr: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := ValidatePath(tt.path)
            if tt.wantErr {
                assert.Error(t, err)
            } else {
                assert.NoError(t, err)
            }
        })
    }
}
```

---

## Database Tests

Use in-memory SQLite for fast tests:

```go
func setupTestDB(t *testing.T) *sql.DB {
    db, err := sql.Open("sqlite", ":memory:")
    require.NoError(t, err)

    // Run migrations
    err = storage.RunMigrations(db)
    require.NoError(t, err)

    return db
}

func TestSpaceRepository(t *testing.T) {
    // Setup
    db := setupTestDB(t)
    defer db.Close()

    repo := sqlite.NewSpaceRepository(db)

    // Test Create
    space := &domain.Space{
        ID:   "space_123",
        Name: "Test Space",
        Path: "/test/path",
    }

    err := repo.Create(space)
    assert.NoError(t, err)

    // Test GetByID
    retrieved, err := repo.GetByID("space_123")
    assert.NoError(t, err)
    assert.Equal(t, space.Name, retrieved.Name)
}
```

---

## Mocking

Use `github.com/stretchr/testify/mock` for mocks:

```bash
go get github.com/stretchr/testify/mock
```

**Example:**

```go
type MockACPClient struct {
    mock.Mock
}

func (m *MockACPClient) SessionPrompt(sessionID, prompt string) error {
    args := m.Called(sessionID, prompt)
    return args.Error(0)
}

// In test:
mockACP := new(MockACPClient)
mockACP.On("SessionPrompt", "sess_123", "Hello").Return(nil)
```

---

## Test Fixtures

Store test data in `tests/fixtures/`:

```go
func loadFixture(filename string) ([]byte, error) {
    return os.ReadFile(filepath.Join("tests", "fixtures", filename))
}

func TestParseResponse(t *testing.T) {
    data, err := loadFixture("acp_response.json")
    require.NoError(t, err)

    response, err := parseACPResponse(data)
    assert.NoError(t, err)
    assert.Equal(t, "Hello!", response.Content)
}
```

---

## Benchmarks

Measure performance:

```go
func BenchmarkMessageProcessing(b *testing.B) {
    service := setupService()

    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        service.ProcessMessage("test message")
    }
}
```

Run:
```bash
go test -bench=. ./...
```

---

## Coverage Goals

**Minimum Coverage:**
- Domain logic: 80%+
- API handlers: 70%+
- Storage layer: 80%+
- Overall: 70%+

**Check Coverage:**
```bash
go test -coverprofile=coverage.out ./...
go tool cover -func=coverage.out | grep total
```

---

## CI/CD Integration

GitHub Actions example:

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
        with:
          go-version: '1.25'

      - name: Run tests
        run: go test -v -coverprofile=coverage.out ./...

      - name: Check coverage
        run: |
          coverage=$(go tool cover -func=coverage.out | grep total | awk '{print $3}' | sed 's/%//')
          if (( $(echo "$coverage < 70" | bc -l) )); then
            echo "Coverage $coverage% is below 70%"
            exit 1
          fi
```

---

## Best Practices

1. **Test naming:** `TestFunctionName_Scenario`
2. **Use table-driven tests** for multiple scenarios
3. **Arrange-Act-Assert** pattern
4. **Mock external dependencies**
5. **Use in-memory DB** for tests
6. **Keep tests fast** (< 10s total)
7. **Test error cases**
8. **Don't test external services** (use mocks)

---

## Resources

- Go Testing: https://golang.org/pkg/testing/
- Testify: https://github.com/stretchr/testify
- Go Test Coverage: https://go.dev/blog/cover

---

**Last Updated:** October 20, 2025
**Status:** Testing strategy defined, ready for implementation alongside features
