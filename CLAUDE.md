# CLAUDE.md

**Guidance for Claude Code when working with the Parachute codebase.**

---

## Quick Command Reference

```bash
# Backend
cd backend && make run          # Start dev server
cd backend && make test         # Run tests
cd backend && make build        # Build binary

# Flutter
cd app && flutter run -d macos  # Run on macOS
cd app && flutter test          # Run tests

# Full test suite
./test.sh                       # All tests
./e2e-test.sh                   # E2E tests (backend must be running)
```

---

## Project Overview

**Parachute**: Cross-platform second brain app powered by Claude AI via Agent Client Protocol (ACP). Provides persistent context management through "Spaces" - independent cognitive contexts with their own files, conversations, and optional MCP servers.

**Tech Stack:**
- **Backend**: Go 1.25+ (Fiber, SQLite)
- **Frontend**: Flutter 3.24+ (Riverpod state management)
- **AI**: Agent Client Protocol via `@zed-industries/claude-code-acp`

**Architecture Flow:**
```
Flutter App → HTTP/WebSocket → Go Backend → JSON-RPC → ACP Process → Claude AI
```

**Current Status:** ✅ Streaming chat working, WebSocket real-time updates, 40 automated tests passing

---

## CRITICAL Implementation Details

### ⚠️ #1: Flutter Type Casting Bug (MOST COMMON RUNTIME ERROR)

**YOU MUST NEVER do this:**
```dart
❌ final List<dynamic> data = response.data as List<dynamic>;  // CRASHES!
```

**ALWAYS do this:**
```dart
✅ final Map<String, dynamic> data = response.data as Map<String, dynamic>;
   final List<dynamic> spaces = data['spaces'] as List<dynamic>;
```

**Why:** All collection endpoints return wrapped responses: `{"spaces": [...]}`, not `[...]`

**Location:** `app/lib/core/services/api_client.dart`
**Applies to:** `/api/spaces`, `/api/conversations`, `/api/messages`

### ⚠️ #2: ACP Protocol Requirements

**CRITICAL - Protocol Version:**
```go
✅ ProtocolVersion: 1  // int, not string
❌ ProtocolVersion: "1"
```

**CRITICAL - mcpServers Field:**
```go
✅ McpServers: []MCPServer{}  // REQUIRED, even if empty
❌ McpServers: nil            // SDK rejects this
```
Never use `omitempty` on `mcpServers` field - the ACP SDK requires it to always be present.

**Method Names (case-sensitive):**
- `initialize` - Initial handshake
- `session/new` - Create session
- `session/prompt` - Send prompt
- `session/update` - Agent notification

**Parameter Format:**
- Use `camelCase`: `sessionId`, not `session_id`
- Prompt is array: `[]ContentBlock`, not string
- Working directory: `cwd`, not `working_directory`

### ⚠️ #3: Flutter Riverpod Requirements

**YOU MUST wrap all widgets using providers in `ProviderScope`:**

```dart
// main.dart
runApp(ProviderScope(child: ParachuteApp()));

// tests
testWidgets('Test', (tester) async {
  await tester.pumpWidget(ProviderScope(child: MyWidget()));
});
```

**Missing ProviderScope = runtime crash!**

### ⚠️ #4: Authentication Fallback

Backend authentication priority:
1. `ANTHROPIC_API_KEY` environment variable (if set)
2. OAuth credentials from macOS keychain (automatic)

**Location:** `~/.claude/.credentials.json` (read via Security framework)

---

## Directory Structure

```
parachute/
├── backend/
│   ├── cmd/server/         # main.go entry point
│   ├── internal/
│   │   ├── api/handlers/   # HTTP/WebSocket handlers
│   │   ├── domain/         # Business logic
│   │   ├── acp/            # ACP client integration
│   │   └── storage/sqlite/ # Database repositories
│   └── Makefile
├── app/
│   ├── lib/
│   │   ├── main.dart       # Entry point (ProviderScope required)
│   │   ├── core/           # Services, models, constants
│   │   ├── features/       # Feature modules (spaces, chat)
│   │   └── shared/         # Shared widgets
│   └── test/
├── docs/
│   ├── setup/              # Installation guides
│   ├── development/        # Testing, workflow
│   ├── architecture/       # System design docs
│   ├── deployment/         # Deployment guides
│   └── project/            # Roadmap, branding
├── test.sh                 # Automated test runner
└── ARCHITECTURE.md         # Detailed architecture
```

---

## Common Pitfalls & Solutions

### 🔴 Port Already in Use
```bash
lsof -ti :8080 | xargs kill
```

### 🔴 Flutter Package Name
```dart
✅ import 'package:app/...'     // Correct
❌ import 'package:parachute/...' // Wrong - package name is "app"
```

### 🔴 ACP Process Not Found
```bash
npm install -g @zed-industries/claude-code-acp
which npx  # Verify npx is available
```

### 🔴 macOS Network Permissions
Flutter macOS requires `com.apple.security.network.client` entitlement in:
- `app/macos/Runner/DebugProfile.entitlements`
- `app/macos/Runner/Release.entitlements`

### 🔴 Forgot to Rebuild Backend
After changing Go code:
```bash
cd backend && make build
```

### 🔴 WebSocket Not Streaming
Check that client calls `subscribe(conversationId)` after connecting. Connection without subscription = no messages received.

---

## API Conventions

### Endpoints
- `GET /health` - Health check
- `GET /api/spaces` → `{"spaces": [...]}`
- `POST /api/spaces` - Create space
- `GET /api/conversations?space_id=...` → `{"conversations": [...]}`
- `POST /api/messages` - Send message
- `WS /ws` - WebSocket for streaming

### Field Naming
- **API responses**: `snake_case` (`created_at`, `user_id`)
- **Flutter models**: `camelCase` (`createdAt`, `userId`)
- **Conversion**: Happens in `fromJson`/`toJson` methods

### Response Format

**Collection (wrapped):**
```json
{"spaces": [{"id": "uuid", "name": "Space"}]}
```

**Single resource:**
```json
{"id": "uuid", "name": "Space"}
```

**Error:**
```json
{"error": "Error message"}
```

---

## Testing

**Quick Start:**
```bash
./test.sh           # All tests (backend + Flutter)
./test.sh -v        # Verbose output
./e2e-test.sh       # E2E tests
```

**Coverage:** 40 automated tests passing
- 11 backend integration tests
- 13 Flutter unit tests
- 16 E2E API tests

**What Tests Catch:**
1. ✅ Type casting errors (`Map` vs `List`)
2. ✅ API response format issues
3. ✅ Model serialization bugs
4. ✅ Validation and error handling

**Test Locations:**
- Backend: `backend/internal/api/handlers/*_test.go`
- Flutter: `app/test/`
- Testing guide: `docs/development/testing.md`

**Adding Tests:**

Backend:
```go
func TestFeature(t *testing.T) {
  app, _ := setupTestApp(t)
  req := httptest.NewRequest(http.MethodGet, "/api/endpoint", nil)
  resp, _ := app.Test(req)
  assert.Equal(t, http.StatusOK, resp.StatusCode)
}
```

Flutter:
```dart
test('Model parses', () {
  final model = Model.fromJson({'field': 'value'});
  expect(model.field, 'value');
});
```

---

## Environment Variables

**Backend:**
```bash
PORT=8080                          # Server port (default: 8080)
DATABASE_PATH=./data/parachute.db  # SQLite database
ANTHROPIC_API_KEY=sk-ant-...       # Optional (falls back to OAuth)
```

**Flutter:**
```bash
# Via --dart-define
API_BASE_URL=http://localhost:8080
WS_URL=ws://localhost:8080/ws
```

---

## Code Style

### Backend (Go)
- Use `gofmt` for formatting
- Repository pattern for data access
- Domain-driven design for business logic
- Handler pattern for HTTP endpoints
- Structured logging (migrate to `slog` - see TODO)

### Frontend (Flutter)
- Feature-based organization (`lib/features/[feature]/`)
- Riverpod for state management
- Models with `fromJson`/`toJson`
- Services for API/WebSocket
- Shared widgets in `shared/widgets/`

---

## Debugging

### Backend Logs
Emoji prefixes:
- 📦 Database operations
- 🤖 ACP initialization
- 💬 WebSocket messages
- ✅ Success
- ❌ Errors

### ACP Debugging
ACP stderr logged with `[ACP stderr]` prefix.

Common errors:
- "Invalid params" → Check `protocolVersion` is int, `mcpServers` is array
- "Authentication failed" → Check API key or OAuth credentials

### Flutter DevTools
```bash
flutter run
# Press 'w' to open DevTools
# Riverpod tab shows provider state
```

---

## Documentation Index

- **[README.md](README.md)** - Project overview
- **[GETTING-STARTED.md](GETTING-STARTED.md)** - Quick start guide
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture
- **[docs/development/testing.md](docs/development/testing.md)** - Comprehensive testing guide
- **[docs/development/workflow.md](docs/development/workflow.md)** - Development workflow
- **[docs/architecture/](docs/architecture/)** - ACP, database, WebSocket protocols
- **[backend/CLAUDE.md](backend/CLAUDE.md)** - Backend-specific context
- **[app/CLAUDE.md](app/CLAUDE.md)** - Frontend-specific context

---

## Known TODOs & Limitations

**High Priority:**
1. Fix CORS (currently allows all origins - production security risk)
2. Implement authentication (hard-coded user IDs)
3. Add manual approval UI for ACP operations

**Testing Gaps:**
- WebSocket reconnection logic
- ACP process crash recovery
- Concurrent message handling

**Future:**
- MCP server integration
- Space file management UI
- Multi-user support

See `docs/project/roadmap.md` for full roadmap.

---

## Troubleshooting Quick Reference

| Problem | Solution |
|---------|----------|
| Backend won't start | `lsof -ti :8080 \| xargs kill` |
| Flutter build fails | `cd app && flutter clean && flutter pub get` |
| Tests fail | `./test.sh -v` for detailed output |
| WebSocket not working | Check `subscribe(conversationId)` called |
| Type casting error | Verify response format matches expectations |
| ACP auth fails | Check `~/.claude/.credentials.json` exists |

---

**Questions?** Check component-specific CLAUDE.md files:
- Backend: `backend/CLAUDE.md`
- Frontend: `app/CLAUDE.md`
