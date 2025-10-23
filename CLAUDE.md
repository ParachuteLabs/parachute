# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Parachute is a cross-platform second brain application powered by Claude AI via the Agent Client Protocol (ACP). It provides persistent context management through "Spaces" - independent cognitive contexts with their own files, conversations, and optional MCP server configurations.

**Tech Stack:**
- Backend: Go 1.25+ (Fiber web framework, SQLite database)
- Frontend: Flutter 3.24+ (iOS, Android, Web, macOS, Windows, Linux)
- AI Integration: Agent Client Protocol (ACP) via `@zed-industries/claude-code-acp`
- State Management: Riverpod (Flutter)

## Architecture

### System Design

```
Flutter App (Multi-platform)
    ↓ HTTP/WebSocket
Go Backend (Port 8080)
    ↓ JSON-RPC (stdin/stdout)
ACP Process (npx @zed-industries/claude-code-acp)
    ↓ API Calls
Claude AI (Anthropic)
```

### Key Architectural Decisions

1. **Authentication Strategy**: Backend uses OAuth credentials from macOS keychain (`~/.claude/.credentials.json`) OR `ANTHROPIC_API_KEY` environment variable. The ACP SDK automatically falls back to OAuth if no API key is provided.

2. **API Response Format**: All collection endpoints return wrapped responses:
   - `/api/spaces` → `{"spaces": [...]}`
   - `/api/conversations` → `{"conversations": [...]}`
   - `/api/messages` → `{"messages": [...]}`

   This is critical for Flutter type safety - never cast `response.data` directly as a List.

3. **ACP Protocol Version**: Always use `protocolVersion: 1` (integer, not string) in initialize calls.

4. **Flutter State Management**: Uses Riverpod. All widgets using providers MUST be wrapped in `ProviderScope`.

5. **macOS Entitlements**: The Flutter macOS app requires `com.apple.security.network.client` entitlement for HTTP/WebSocket connections due to App Sandbox.

### Directory Structure

```
parachute/
├── backend/                 # Go backend service
│   ├── cmd/server/         # Entry point (main.go)
│   ├── internal/
│   │   ├── api/handlers/   # HTTP/WebSocket handlers
│   │   ├── domain/         # Business logic (space, conversation services)
│   │   ├── acp/            # ACP client integration
│   │   └── storage/sqlite/ # Database repositories
│   └── Makefile            # Backend build commands
├── app/                    # Flutter frontend
│   ├── lib/
│   │   ├── main.dart      # Entry point with ProviderScope
│   │   ├── core/          # App-wide (services, models, constants)
│   │   ├── features/      # Feature modules (spaces, chat, conversations)
│   │   └── shared/        # Shared widgets
│   └── test/              # Tests
├── test.sh                # Automated test runner
└── TESTING.md             # Testing documentation
```

## Development Commands

### Backend

```bash
cd backend

# Development
make run              # Run development server
make build            # Build production binary
make test             # Run all tests
make test-v           # Run tests with verbose output
make test-coverage    # Generate coverage report
make clean            # Clean build artifacts

# Direct Go commands
go test ./internal/api/handlers/...  # API integration tests only
go test -timeout 20s -v ./...        # All tests with timeout
```

### Frontend

```bash
cd app

# Development
flutter run                    # Run on default device
flutter run -d macos          # Run on macOS
flutter test                  # Run all tests
flutter test test/api_client_test.dart  # Run specific test
flutter pub get               # Install dependencies

# Code generation (Riverpod)
flutter pub run build_runner watch --delete-conflicting-outputs
```

### Full Test Suite

```bash
./test.sh                  # Run all tests (backend + frontend)
./test.sh --backend-only   # Backend only
./test.sh --flutter-only   # Flutter only
./test.sh -v              # Verbose output
```

## Critical Implementation Details

### 1. ACP Authentication

The backend authenticates with Claude using one of two methods:

**Priority Order:**
1. `ANTHROPIC_API_KEY` environment variable (if set)
2. OAuth credentials from macOS keychain (automatic fallback)

**Implementation** (`backend/internal/acp/process.go`):
```go
func SpawnACP(apiKey string) (*ACPProcess, error) {
    cmd := exec.Command("npx", "@zed-industries/claude-code-acp")

    // Only set ANTHROPIC_API_KEY if provided
    if apiKey != "" {
        cmd.Env = append(os.Environ(), "ANTHROPIC_API_KEY="+apiKey)
    } else {
        cmd.Env = os.Environ()  // SDK uses OAuth automatically
    }
    // ...
}
```

**Keychain Access:**
```bash
# OAuth credentials stored at:
security find-generic-password -s "Claude Code-credentials"
# Returns: {"claudeAiOauth":{"accessToken":"sk-ant-oat01-...", ...}}
```

### 2. Flutter API Client Type Safety

**CRITICAL BUG TO AVOID:**

❌ **Wrong** (causes runtime error):
```dart
final response = await _dio.get('/api/spaces');
final List<dynamic> data = response.data as List<dynamic>;  // CRASH!
```

✅ **Correct**:
```dart
final response = await _dio.get('/api/spaces');
final Map<String, dynamic> data = response.data as Map<String, dynamic>;
final List<dynamic> spaces = data['spaces'] as List<dynamic>;
return spaces.map((json) => Space.fromJson(json as Map<String, dynamic>)).toList();
```

**Location:** `app/lib/core/services/api_client.dart`

This pattern applies to ALL collection endpoints (spaces, conversations, messages).

### 3. ACP Protocol Methods and Parameters

**CRITICAL:** The ACP protocol uses specific method names and parameter formats:

**Method Names:**
- `initialize` - Initial handshake
- `session/new` - Create new session (NOT `new_session`)
- `session/prompt` - Send prompt (NOT `session_prompt`)
- `session/update` - Notification from agent

**Initialize Parameters:**
```go
// backend/internal/acp/client.go
type InitializeParams struct {
    ProtocolVersion int    `json:"protocolVersion"`  // MUST be int (1), not string
    ClientName      string `json:"client_name,omitempty"`
    ClientVersion   string `json:"client_version,omitempty"`
}
```

**Session/New Parameters:**
```go
type NewSessionParams struct {
    Cwd        string      `json:"cwd"`              // Working directory (NOT working_directory)
    McpServers []MCPServer `json:"mcpServers"`       // REQUIRED: Must be array, use [] if no servers
                                                      // CANNOT use omitempty - SDK requires this field
}

type NewSessionResult struct {
    SessionID string `json:"sessionId"`  // Camel case, not session_id
}

// Always ensure mcpServers is an array (empty if nil)
if mcpServers == nil {
    mcpServers = []MCPServer{}
}
```

**Session/Prompt Parameters:**
```go
type ContentBlock struct {
    Type string `json:"type"`  // "text"
    Text string `json:"text"`  // Actual content
}

type SessionPromptParams struct {
    SessionID string         `json:"sessionId"`  // Camel case
    Prompt    []ContentBlock `json:"prompt"`     // Array of content blocks, NOT string
}
```

### 4. Flutter Widget Testing with Riverpod

All widget tests MUST wrap the app in `ProviderScope`:

```dart
// test/widget_test.dart
testWidgets('App loads', (WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(  // REQUIRED for Riverpod
      child: ParachuteApp(),
    ),
  );
  await tester.pumpAndSettle();
  // assertions...
});
```

## Testing Strategy

### Test Coverage

- **Backend**: 11 tests (API integration tests)
- **Flutter**: 13 tests (models, API format validation, type safety)
- **Total**: 24 automated tests

### What Tests Catch

1. **Type Casting Errors**: `Map<String, dynamic>` vs `List<dynamic>` mismatches
2. **API Response Format**: Validates `{"spaces": [...]}` wrapper structure
3. **Model Serialization**: JSON parsing for all data models
4. **API Behavior**: Status codes, validation, error handling

### Running Tests

The automated test suite (`./test.sh`) provides:
- Fast feedback (runs in ~10 seconds)
- Backend API integration tests (Go)
- Flutter model and API client tests (Dart)
- Optional E2E health checks (if backend running)

**Test Locations:**
- Backend: `backend/internal/api/handlers/api_test.go`
- Flutter: `app/test/api_client_test.dart`, `app/test/widget_test.dart`

### Adding Tests

**Backend Test Template:**
```go
func TestNewFeature(t *testing.T) {
    app, _ := setupTestApp(t)

    t.Run("TestCase", func(t *testing.T) {
        req := httptest.NewRequest(http.MethodGet, "/api/endpoint", nil)
        resp, err := app.Test(req)
        require.NoError(t, err)
        assert.Equal(t, http.StatusOK, resp.StatusCode)

        var result map[string]interface{}
        json.NewDecoder(resp.Body).Decode(&result)
        assert.Contains(t, result, "expected_key")
    })
}
```

**Flutter Test Template:**
```dart
test('Model parses correctly', () {
  final json = {'field': 'value'};
  final model = Model.fromJson(json);
  expect(model.field, 'value');
});
```

## Common Pitfalls

1. **Port Already in Use**: If backend fails with "address already in use", kill existing process:
   ```bash
   lsof -ti :8080 | xargs kill
   ```

2. **Flutter Package Name**: The package name is `app`, not `parachute`. Use `import 'package:app/...'`

3. **ACP Process Not Found**: Ensure `npx` and `@zed-industries/claude-code-acp` are available:
   ```bash
   npm install -g @zed-industries/claude-code-acp
   ```

4. **macOS Network Errors**: Flutter macOS app requires network entitlements in both:
   - `app/macos/Runner/DebugProfile.entitlements`
   - `app/macos/Runner/Release.entitlements`

5. **Riverpod Errors in Tests**: Always wrap test widgets in `ProviderScope`

6. **ACP Invalid Params Error**: The `mcpServers` field is REQUIRED in `session/new` requests. Always send an empty array `[]` if no MCP servers are configured. Never use `omitempty` on this field.

7. **Forgot to Rebuild**: After changing Go code, always rebuild with `cd backend && make build`

## API Conventions

### Endpoints

- `GET /health` - Health check (no auth required)
- `GET /api/spaces` - List spaces
- `POST /api/spaces` - Create space
- `GET /api/spaces/:id` - Get space
- `PUT /api/spaces/:id` - Update space
- `DELETE /api/spaces/:id` - Delete space
- `GET /api/conversations?space_id=...` - List conversations
- `POST /api/conversations` - Create conversation
- `GET /api/messages?conversation_id=...` - List messages
- `POST /api/messages` - Send message
- `WS /ws` - WebSocket for real-time chat

### Response Format

**Success (Collection):**
```json
{
  "spaces": [
    {
      "id": "uuid",
      "name": "Space Name",
      "path": "/path/to/space",
      "created_at": "2025-10-20T...",
      "updated_at": "2025-10-20T..."
    }
  ]
}
```

**Success (Single Resource):**
```json
{
  "id": "uuid",
  "name": "Space Name",
  "path": "/path/to/space"
}
```

**Error:**
```json
{
  "error": "Error message"
}
```

### Field Naming

- Backend: `snake_case` (Go struct tags: `json:"created_at"`)
- Flutter: `camelCase` (Dart properties: `createdAt`)
- API responses: `snake_case`
- Conversion happens in `fromJson`/`toJson` methods

## Database Schema

**Location:** `backend/internal/storage/sqlite/migrations.go`

**Key Tables:**
- `spaces` - Space metadata and paths
- `conversations` - Conversation threads per space
- `messages` - Chat messages with role (user/assistant)
- Future: `users`, `sessions`, `permissions`

**Important:** The database uses SQLite with file storage at `./data/parachute.db` (configurable via `DATABASE_PATH` env var).

## Environment Variables

**Backend:**
```bash
PORT=8080                          # Server port
DATABASE_PATH=./data/parachute.db  # SQLite database path
ANTHROPIC_API_KEY=sk-ant-...       # Optional (falls back to OAuth)
```

**Flutter:**
```bash
# Set via --dart-define
API_BASE_URL=http://localhost:8080  # Backend URL
WS_URL=ws://localhost:8080/ws       # WebSocket URL
```

## Documentation

- **[README.md](README.md)** - Project overview and quick start
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture
- **[TESTING.md](TESTING.md)** - Testing guide
- **[test.sh](test.sh)** - Automated test runner script
- **[backend/README.md](backend/README.md)** - Backend documentation
- **[app/README.md](app/README.md)** - Flutter app documentation

## Code Style

### Backend (Go)

- Use `gofmt` for formatting
- Follow standard Go project layout
- Domain-driven design: `internal/domain/` for business logic
- Repository pattern: `internal/storage/` for data access
- Handler pattern: `internal/api/handlers/` for HTTP endpoints

### Frontend (Flutter)

- Feature-based organization: `lib/features/[feature]/`
- Riverpod for state management
- Models in `models/` with `fromJson`/`toJson`
- Services in `services/` for API/WebSocket
- Shared widgets in `shared/widgets/`

## Building for Production

### Backend

```bash
cd backend
make build
# Binary: ./bin/server
./bin/server  # Runs on port 8080
```

### Flutter

```bash
cd app

# iOS
flutter build ios --release

# Android
flutter build appbundle --release

# Web
flutter build web --release

# macOS
flutter build macos --release
```

## Debugging

### Backend Logs

The backend logs to stdout with emoji prefixes:
- 📦 Database operations
- 🤖 ACP initialization
- ✅ Success messages
- ⚠️ Warnings
- ❌ Errors

### ACP Process Debugging

ACP stderr is logged with `[ACP stderr]` prefix. Common errors:
- "Invalid params" → Check `protocolVersion` is integer
- "Authentication failed" → Check API key or OAuth credentials

### Flutter DevTools

```bash
flutter run
# Press 'w' to open DevTools in browser
# Riverpod tab shows provider state
```

## Current Status

**Phase:** Foundation + Implementation in Progress

**Completed:**
- ✅ Project structure
- ✅ Backend API skeleton with tests
- ✅ Flutter app skeleton with tests
- ✅ ACP integration with OAuth support
- ✅ Automated test suite
- ✅ Database schema and migrations

**In Progress:**
- 🚧 WebSocket real-time chat
- 🚧 Space file management
- 🚧 MCP server integration

**Next:**
- Full ACP session management
- Chat UI with streaming
- Space CRUD UI
- Settings and configuration
