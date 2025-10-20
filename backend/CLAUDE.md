# Parachute Backend - Development Context

## What This Is

Go backend service for Parachute - your open, interoperable second brain powered by Claude AI via the Agent Client Protocol (ACP).

## Core Responsibilities

- REST API for Spaces, Conversations, Messages
- WebSocket server for real-time chat streaming
- ACP integration via claude-code-acp subprocess
- SQLite database for persistence
- JWT authentication

## Tech Stack

- **Language:** Go 1.25+
- **Framework:** Fiber (web server + WebSocket)
- **Database:** SQLite (modernc.org/sqlite - pure Go, no CGO)
- **ACP:** Hybrid approach (spawn Node.js claude-code-acp process)
- **Auth:** JWT tokens

## Architecture Pattern

```
HTTP/WebSocket API
↓
Business Logic Layer (domain services)
↓
ACP Integration Layer (claude-code-acp process)
↓
Storage Layer (SQLite repositories)
```

## Key Components

1. **ACP Client** (`internal/acp/client.go`)
   - Spawns claude-code-acp subprocess
   - JSON-RPC 2.0 communication via stdin/stdout
   - Methods: initialize, new_session, session/prompt
   - Handles session/update notifications (streaming)

2. **WebSocket Handler** (`internal/api/websocket/chat.go`)
   - Real-time bidirectional communication
   - Events: message_chunk, tool_call, permission_request
   - Commands: send_message, approve_permission

3. **Space Service** (`internal/domain/space/service.go`)
   - CRUD operations for Spaces
   - CLAUDE.md file management
   - .mcp.json loading

4. **Conversation Service** (`internal/domain/conversation/service.go`)
   - Conversation + message persistence
   - Context restoration (include history in prompts)

## Reference Implementation

**Current Rust version:** `~/Symbols/Codes/para-claude-v2/src-tauri/src/acp_v2/`
- Study `manager.rs` for ACP process management
- Study `client.rs` for permission handling patterns

**Zed's implementation:** `~/Symbols/Codes/zed/crates/agent_ui/`

## ACP Integration Approach

**IMPORTANT:** We use the hybrid approach (not pure Go SDK):

```go
// Spawn claude-code-acp
cmd := exec.Command("npx", "@zed-industries/claude-code-acp")
stdin, _ := cmd.StdinPipe()
stdout, _ := cmd.StdoutPipe()
cmd.Env = append(os.Environ(), "ANTHROPIC_API_KEY="+apiKey)
cmd.Start()

// Communicate via JSON-RPC 2.0
// Read from stdout, write to stdin
```

**Why:** Battle-tested, official, maintained by Zed.

**Alternative:** `github.com/joshgarnett/agent-client-protocol-go` (early stage).

## Database Schema

```sql
-- Spaces
CREATE TABLE spaces (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    path TEXT NOT NULL UNIQUE,  -- Absolute path
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

-- Conversations
CREATE TABLE conversations (
    id TEXT PRIMARY KEY,
    space_id TEXT NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

-- Messages
CREATE TABLE messages (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK(role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    metadata TEXT  -- JSON for tool calls, etc.
);

-- Sessions (ACP session tracking)
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,  -- ACP session_id
    conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    created_at INTEGER NOT NULL,
    last_used_at INTEGER NOT NULL,
    is_active INTEGER DEFAULT 1,
    UNIQUE(conversation_id)  -- One active session per conversation
);
```

## Development Workflow

```bash
# Run development server
go run cmd/server/main.go

# Run with hot reload (using air)
air

# Run tests
go test ./...

# Build for production
go build -o bin/server cmd/server/main.go
```

## Environment Variables

```
PORT=8080
DATABASE_PATH=./data/parachute.db
JWT_SECRET=<generate-random>
ANTHROPIC_API_KEY=<optional-default>
SPACES_PATH=./data/spaces
LOG_LEVEL=info
NODE_PATH=/usr/local/bin/node
NPX_PATH=/usr/local/bin/npx
```

## Next Steps (Priority Order)

1. ✅ Create project structure
2. ⏳ Implement ACP client (spawn claude-code-acp, JSON-RPC)
3. ⏳ Implement WebSocket handler (chat streaming)
4. ⏳ Implement Space service (CRUD + CLAUDE.md)
5. ⏳ Implement Conversation service (history + persistence)
6. ⏳ Add authentication (JWT)
7. ⏳ Wire up all endpoints
8. ⏳ Test end-to-end with Flutter frontend

## Resources

- **ACP Spec:** https://agentclientprotocol.com/
- **Fiber Docs:** https://docs.gofiber.io/
- **Current Rust Code:** `~/Symbols/Codes/para-claude-v2/`
- **Zed Reference:** `~/Symbols/Codes/zed/`

## Notes

- Always use absolute paths for file operations (ACP requirement)
- Line numbers are 1-based (not 0-based)
- Context restoration: Include conversation history in first prompt after app restart
- Permission auto-approval: Safe operations (read-only, searches) auto-approved

---

**Last Updated:** October 20, 2025
**Status:** Foundation phase - Project structure created, ready for implementation
