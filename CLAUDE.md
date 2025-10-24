# CLAUDE.md

**Essential guidance for Claude Code when working with Parachute.**

---

## Quick Commands

```bash
# Backend
cd backend && make run          # Start server
cd backend && make test         # Run tests

# Flutter
cd app && flutter run -d macos  # Run app
cd app && flutter test          # Run tests

# Full test suite
./test.sh                       # All tests
```

---

## Project Overview

**Parachute**: Second brain app with Claude AI via Agent Client Protocol (ACP).

**Stack:** Go backend (Fiber, SQLite) + Flutter frontend (Riverpod)

**Architecture:** `Flutter → HTTP/WebSocket → Go → JSON-RPC → ACP → Claude`

---

## CRITICAL Bug Preventions

### ⚠️ #1: Flutter Type Casting (MOST COMMON ERROR)

**NEVER do this:**
```dart
❌ final List<dynamic> data = response.data as List<dynamic>;  // CRASHES!
```

**ALWAYS do this:**
```dart
✅ final Map<String, dynamic> data = response.data as Map<String, dynamic>;
   final List<dynamic> spaces = data['spaces'] as List<dynamic>;
```

**Why:** API endpoints return `{"spaces": [...]}`, not `[...]`

### ⚠️ #2: ACP Protocol Requirements

```go
✅ ProtocolVersion: 1           // int, not string
✅ McpServers: []MCPServer{}    // REQUIRED, even if empty (no omitempty)
```

**Method names:** `initialize`, `session/new`, `session/prompt`, `session/update`
**Parameters:** Use `camelCase` (`sessionId`, `cwd`), not `snake_case`

### ⚠️ #3: Flutter Riverpod

**All widgets using providers MUST be wrapped in `ProviderScope`:**
```dart
runApp(ProviderScope(child: ParachuteApp()));
```

### ⚠️ #4: Authentication

Backend tries `ANTHROPIC_API_KEY` env var, then falls back to `~/.claude/.credentials.json`

---

## Git Workflow

**DO NOT commit before user testing!**

1. Make code change
2. Tell user what changed
3. Ask user to test
4. Wait for confirmation
5. Ask permission to commit
6. Commit only after approval

**Why:** Avoids messy history with reverts and bug-filled commits.

---

## Common Quick Fixes

```bash
# Port in use
lsof -ti :8080 | xargs kill

# Flutter clean build
cd app && flutter clean && flutter pub get

# Rebuild backend after Go changes
cd backend && make build
```

**Flutter package name:** `package:app/...` (not `parachute`)

**WebSocket not streaming?** Check client calls `subscribe(conversationId)` after connecting.

---

## Documentation

**Detailed info available in:**
- `README.md` - Project overview
- `ARCHITECTURE.md` - System design
- `docs/development/testing.md` - Testing guide
- `docs/development/workflow.md` - Development workflow
- `docs/architecture/` - ACP, database, WebSocket details
- `backend/CLAUDE.md` - Backend-specific context
- `app/CLAUDE.md` - Frontend-specific context

Read these files as needed for specific tasks.
