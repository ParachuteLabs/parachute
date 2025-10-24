# Backend Context

**Go backend for Parachute - Claude AI second brain via ACP.**

---

## Quick Commands

```bash
cd backend && make run          # Start dev server
cd backend && make test         # Run tests
cd backend && make build        # Build binary
```

---

## Core Architecture

```
HTTP/WebSocket API → Domain Services → ACP Client → Storage (SQLite)
```

**Responsibilities:**
- REST API for Spaces, Conversations, Messages
- WebSocket for real-time streaming
- ACP integration via `@zed-industries/claude-code-acp` subprocess
- SQLite persistence

---

## Critical Implementation Details

### ⚠️ ACP Process Management

**We spawn the Node.js ACP process:**
```go
cmd := exec.Command("npx", "@zed-industries/claude-code-acp")
stdin, _ := cmd.StdinPipe()
stdout, _ := cmd.StdoutPipe()
cmd.Env = append(os.Environ(), "ANTHROPIC_API_KEY="+apiKey)
cmd.Start()
```

**Communication:** JSON-RPC 2.0 via stdin/stdout

**Why not pure Go SDK?** The official `@zed-industries/claude-code-acp` is battle-tested and maintained by Zed.

### ⚠️ WebSocket Authentication

**Native apps (Flutter) don't send Origin headers!**
```go
// Allow connections without Origin header
if origin == "" {
    return true  // Native app
}
```

### ⚠️ Database Path Handling

**Always use absolute paths:**
- Space paths must be absolute (ACP requirement)
- Database stores absolute paths
- Convert relative → absolute at API boundary

---

## Key Components

**ACP Client** (`internal/acp/client.go`)
- Spawns subprocess, manages JSON-RPC communication
- Methods: `initialize`, `session/new`, `session/prompt`
- Handles `session/update` notifications for streaming

**WebSocket Handler** (`internal/api/handlers/websocket_handler.go`)
- Real-time bidirectional chat
- Events: `message_chunk`, `tool_call`, `tool_call_update`
- Commands: `subscribe`, `send_message`

**Domain Services** (`internal/domain/`)
- `space/` - Space CRUD, CLAUDE.md management
- `conversation/` - Conversation + message persistence
- `acp/` - ACP client integration

**Storage** (`internal/storage/sqlite/`)
- Repository pattern for data access
- Migrations in `migrations/`

---

## Environment Variables

```bash
PORT=8080                          # Default: 8080
DATABASE_PATH=./data/parachute.db  # SQLite path
ANTHROPIC_API_KEY=<optional>       # Falls back to OAuth
ALLOWED_ORIGINS=http://localhost   # CORS origins
```

---

## Reference Code

**Current Rust version:** `~/Symbols/Codes/para-claude-v2/src-tauri/src/acp_v2/`
- Study `manager.rs` for process management patterns
- Study `client.rs` for permission handling

**Zed implementation:** `~/Symbols/Codes/zed/crates/agent_ui/`

---

## Documentation

See root `ARCHITECTURE.md` and `docs/architecture/` for detailed design docs.
