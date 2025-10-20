# Parachute - Development Workflow

**Last Updated:** October 20, 2025

This document describes the day-to-day development workflow for Parachute.

---

## Daily Development

### Starting Work

```bash
# Terminal 1: Backend
cd backend
go run cmd/server/main.go

# Or with hot reload (using air):
air

# Terminal 2: Frontend
cd app
flutter run
# Choose device: iOS sim, Android emulator, Chrome, or desktop

# Terminal 3: For commands, tests, etc.
cd parachute
```

### Hot Reload

**Backend (with air):**
```bash
# Install air
go install github.com/cosmtrek/air@latest

# Run with hot reload
cd backend
air
```

Creates `tmp/main` binary and restarts on file changes.

**Frontend:**
- Changes to Dart files: Press `r` for hot reload, `R` for hot restart
- Changes to pubspec.yaml: Stop and `flutter run` again
- Changes to assets: Press `R` for hot restart

---

## Git Workflow

### Branch Strategy

```
main              → Production-ready code (protected)
develop           → Integration branch
feature/xyz       → Feature branches
bugfix/xyz        → Bug fix branches
docs/xyz          → Documentation updates
```

### Working on a Feature

```bash
# Start from develop
git checkout develop
git pull origin develop

# Create feature branch
git checkout -b feature/acp-integration

# Make changes, commit frequently
git add .
git commit -m "feat: implement ACP client initialization"

# Push to remote
git push origin feature/acp-integration

# When complete, create PR to develop
# After review and tests pass, merge to develop
# Periodically merge develop → main for releases
```

### Commit Message Convention

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add ACP session management
fix: resolve WebSocket reconnection issue
docs: update CLAUDE.md with new patterns
refactor: simplify message handling logic
test: add integration tests for ACP client
chore: update dependencies
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style (formatting, no logic change)
- `refactor`: Code change without adding features or fixing bugs
- `test`: Adding or updating tests
- `chore`: Maintenance (deps, configs, etc.)

---

## Code Organization

### Backend Structure

```
backend/
├── cmd/server/main.go           # Entry point
├── internal/
│   ├── api/                     # HTTP handlers, WebSocket, middleware
│   │   ├── handlers/            # REST endpoint handlers
│   │   ├── websocket/           # WebSocket chat handler
│   │   ├── middleware/          # Auth, CORS, logging
│   │   └── routes.go            # Route definitions
│   ├── domain/                  # Business logic (domain-driven design)
│   │   ├── space/               # Space entity + service
│   │   ├── conversation/        # Conversation management
│   │   ├── message/             # Message handling
│   │   └── session/             # ACP session lifecycle
│   ├── acp/                     # ACP integration
│   │   ├── client.go            # ACP client
│   │   ├── process.go           # claude-code-acp process mgmt
│   │   └── types.go             # ACP data types
│   ├── storage/                 # Data persistence
│   │   └── sqlite/              # SQLite repositories
│   └── config/                  # Configuration
│       └── config.go            # Load env vars, settings
└── dev-docs/                    # Developer documentation
```

**Principles:**
- Keep `internal/` truly internal (not importable by other projects)
- Domain logic in `domain/` packages (pure business logic)
- External concerns (HTTP, DB) in `api/` and `storage/`
- ACP integration isolated in `acp/` package

### Frontend Structure

```
app/
├── lib/
│   ├── main.dart                # Entry point
│   ├── app.dart                 # MaterialApp setup
│   ├── core/                    # App-wide concerns
│   │   ├── constants/           # API URLs, app constants
│   │   ├── theme/               # Light/dark themes
│   │   ├── router/              # go_router navigation
│   │   └── config/              # App configuration
│   ├── features/                # Feature-first organization
│   │   ├── auth/                # Authentication
│   │   │   ├── presentation/    # Screens, widgets
│   │   │   ├── providers/       # Riverpod providers
│   │   │   └── models/          # Data models
│   │   ├── spaces/              # Space management
│   │   ├── chat/                # Chat interface
│   │   └── settings/            # Settings screen
│   └── shared/                  # Shared across features
│       ├── widgets/             # Reusable widgets
│       ├── services/            # API, WebSocket services
│       └── models/              # Shared models
└── dev-docs/                    # Developer documentation
```

**Principles:**
- Feature-first (not layer-first) organization
- Each feature is self-contained
- Shared code only when used by 2+ features
- Riverpod providers co-located with features

---

## Testing Strategy

### Backend Tests

**Unit Tests:**
```bash
# Run all tests
go test ./...

# Run specific package
go test ./internal/domain/space

# Run with coverage
go test -cover ./...

# Generate coverage report
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

**Test Structure:**
```go
// internal/domain/space/service_test.go
package space_test

import (
    "testing"
    "github.com/stretchr/testify/assert"
)

func TestCreateSpace(t *testing.T) {
    // Given
    service := NewSpaceService(mockRepo)

    // When
    space, err := service.Create("Test Space", "/path/to/space")

    // Then
    assert.NoError(t, err)
    assert.Equal(t, "Test Space", space.Name)
}
```

**Integration Tests:**
```bash
# Run with integration tag
go test -tags=integration ./...
```

### Frontend Tests

**Widget Tests:**
```bash
# Run all tests
flutter test

# Run specific test
flutter test test/features/chat/chat_screen_test.dart

# Run with coverage
flutter test --coverage
```

**Test Structure:**
```dart
// test/features/chat/chat_screen_test.dart
void main() {
  testWidgets('Chat screen displays messages', (WidgetTester tester) async {
    // Given
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: ChatScreen()),
      ),
    );

    // When
    await tester.pump();

    // Then
    expect(find.text('Hello'), findsOneWidget);
  });
}
```

**Integration Tests:**
```bash
# Run integration tests
flutter test integration_test/
```

---

## Documentation Standards

### When to Update CLAUDE.md

Update `backend/CLAUDE.md` or `app/CLAUDE.md` when:

- ✅ Making architectural decisions
- ✅ Changing major dependencies
- ✅ Discovering new patterns
- ✅ Learning important things about ACP/MCP
- ✅ Completing major features
- ✅ Adding new components

### When to Create dev-docs

Create detailed docs in `dev-docs/` for:

- New subsystems (ACP integration, WebSocket protocol)
- Complex algorithms (context restoration, permission handling)
- API specifications
- Database schemas
- Deployment procedures

### Code Comments

**Do comment:**
- Why something is done (rationale)
- Complex business logic
- Workarounds and their reasons
- Public API functions (godoc style)

**Don't comment:**
- What the code does (code should be self-explanatory)
- Obvious things
- Redundant information

**Examples:**

```go
// Good: Explains why
// We spawn claude-code-acp as a subprocess instead of using a pure Go SDK
// because it's battle-tested by Zed and maintained by Anthropic.
cmd := exec.Command("npx", "@zed-industries/claude-code-acp")

// Bad: Explains what (obvious)
// Create a new command
cmd := exec.Command("npx", "@zed-industries/claude-code-acp")
```

---

## Debugging

### Backend Debugging

**Print Debugging:**
```go
import "log"

log.Printf("Session ID: %s", sessionID)
log.Printf("Message: %+v", message) // %+v prints struct fields
```

**VSCode Debugging:**
1. Set breakpoint (click left of line number)
2. F5 to start debugging
3. Use Debug Console

**Delve (CLI debugger):**
```bash
# Install
go install github.com/go-delve/delve/cmd/dlv@latest

# Run with debugger
dlv debug cmd/server/main.go
```

### Frontend Debugging

**Flutter DevTools:**
```bash
# Run app
flutter run

# Open DevTools (click link in terminal or)
flutter pub global activate devtools
flutter pub global run devtools
```

**Print Debugging:**
```dart
import 'package:flutter/foundation.dart';

debugPrint('State updated: $state');
```

**VSCode Debugging:**
1. Set breakpoint
2. F5 to start debugging
3. Use Debug Console

---

## Performance Monitoring

### Backend

**Profiling:**
```bash
# CPU profiling
go test -cpuprofile=cpu.prof -bench=.
go tool pprof cpu.prof

# Memory profiling
go test -memprofile=mem.prof -bench=.
go tool pprof mem.prof
```

**Benchmarking:**
```go
func BenchmarkMessageProcessing(b *testing.B) {
    for i := 0; i < b.N; i++ {
        ProcessMessage("test message")
    }
}
```

### Frontend

**Performance Overlay:**
```dart
MaterialApp(
  showPerformanceOverlay: true, // Shows FPS
  // ...
)
```

**Timeline:**
```bash
flutter run --profile
# Use DevTools → Performance tab
```

---

## Database Management

### Migrations

**Creating Migrations:**
```bash
# Backend: Manual migrations (simple for SQLite)
# Create file: backend/internal/storage/sqlite/migrations/001_initial.sql

CREATE TABLE spaces (...);
CREATE TABLE conversations (...);
-- etc.
```

**Running Migrations:**
```go
// In code
func RunMigrations(db *sql.DB) error {
    migrations := []string{
        "001_initial.sql",
        "002_add_sessions.sql",
    }

    for _, migration := range migrations {
        // Read and execute SQL
    }
}
```

### Inspecting Database

**DB Browser for SQLite:**
- Open `backend/data/parachute.db`
- Browse data, run queries

**Command Line:**
```bash
sqlite3 backend/data/parachute.db

# List tables
.tables

# Schema
.schema spaces

# Query
SELECT * FROM spaces;

# Exit
.quit
```

---

## Common Tasks

### Adding a New API Endpoint

1. Define route in `backend/internal/api/routes.go`
2. Create handler in `backend/internal/api/handlers/`
3. Add business logic in `backend/internal/domain/`
4. Add repository method if needed
5. Write tests
6. Update API documentation

### Adding a New Flutter Screen

1. Create screen in `app/lib/features/[feature]/presentation/screens/`
2. Create provider in `app/lib/features/[feature]/providers/`
3. Add route in `app/lib/core/router/`
4. Create widgets if needed
5. Write widget tests

### Adding a New Dependency

**Backend:**
```bash
cd backend
go get github.com/some/package
go mod tidy
```

**Frontend:**
```bash
cd app

# Add to pubspec.yaml
flutter pub add package_name

# Or edit pubspec.yaml and run
flutter pub get
```

---

## Deployment

### Local Deployment

**Backend:**
```bash
cd backend
go build -o bin/server cmd/server/main.go
./bin/server
```

**Frontend (Web):**
```bash
cd app
flutter build web
# Serve from app/build/web/
```

### Production Deployment

See `backend/dev-docs/DEPLOYMENT.md` for detailed instructions.

**Quick overview:**

1. **Render.com:**
   - Connect GitHub repo
   - Render auto-builds and deploys

2. **Fly.io:**
   ```bash
   fly launch
   fly deploy
   ```

3. **Mac Mini + Tailscale:**
   - Build binary
   - Copy to Mac Mini
   - Run as service (systemd/launchd)
   - Access via Tailscale VPN

---

## Troubleshooting

### Backend Won't Start

**Check:**
- `.env` file exists and has correct values
- Port 8080 not already in use: `lsof -i :8080`
- Database directory exists: `mkdir -p backend/data`
- Go dependencies installed: `go mod tidy`

### Frontend Won't Build

**Check:**
- Dependencies installed: `flutter pub get`
- Generated files up to date: `flutter pub run build_runner build`
- No syntax errors: `flutter analyze`
- Clear cache if needed: `flutter clean && flutter pub get`

### ACP Integration Issues

**Check:**
- Node.js installed: `node -v`
- claude-code-acp works: `npx @zed-industries/claude-code-acp --version`
- ANTHROPIC_API_KEY set in `.env`
- Check logs for subprocess errors

### WebSocket Issues

**Check:**
- Backend WebSocket endpoint running: `ws://localhost:8080/ws`
- CORS settings if testing from web
- Check browser console for errors
- Verify WebSocket service in Flutter is connecting

---

## Getting Help

**During Development:**
- Check CLAUDE.md files for component context
- Review dev-docs for specific subsystems
- Search existing issues on GitHub
- Ask in team chat (future)

**Stuck on Implementation:**
- Break down problem into smaller pieces
- Add debug logging
- Write a test to reproduce issue
- Check reference implementations (Rust version, Zed)

---

## Best Practices

### Code Quality

- Run tests before committing
- Run linter: `go vet ./...` (backend), `flutter analyze` (frontend)
- Format code: `go fmt ./...` (backend), `dart format lib/` (frontend)
- Review your own PR before requesting review

### Commits

- Commit frequently (small, logical changes)
- Write clear commit messages
- Don't commit secrets or large files
- Don't commit generated files

### Documentation

- Update CLAUDE.md when making architectural changes
- Keep dev-docs in sync with code
- Comment complex logic
- Update README if adding new setup steps

---

**Last Updated:** October 20, 2025
**Status:** Foundation phase development workflow established
