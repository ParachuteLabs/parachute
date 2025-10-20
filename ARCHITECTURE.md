# Parachute - System Architecture

**Version:** 1.0
**Date:** October 20, 2025
**Status:** Foundation Phase

---

## Overview

Parachute is a cross-platform second brain application that provides a beautiful interface for interacting with Claude AI via the Agent Client Protocol (ACP). It combines local file access, persistent context management, and MCP extensibility.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Frontend                        │
│           (iOS, Android, Web, Desktop)                      │
│                                                             │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │   Spaces    │  │     Chat     │  │    Settings     │   │
│  │   Screen    │  │    Screen    │  │     Screen      │   │
│  └─────────────┘  └──────────────┘  └─────────────────┘   │
│         │                 │                  │              │
│         └─────────────────┴──────────────────┘              │
│                        │                                    │
│              ┌─────────▼─────────┐                          │
│              │  Riverpod State   │                          │
│              │    Management     │                          │
│              └─────────┬─────────┘                          │
│                        │                                    │
│         ┌──────────────┴──────────────┐                     │
│         │                             │                     │
│    ┌────▼─────┐              ┌────────▼────────┐           │
│    │ API      │              │   WebSocket     │           │
│    │ Service  │              │   Service       │           │
│    │ (HTTP)   │              │   (Real-time)   │           │
│    └────┬─────┘              └────────┬────────┘           │
└─────────┼────────────────────────────┼────────────────────┘
          │                            │
          │    Network (HTTP/WS)       │
          │                            │
┌─────────▼────────────────────────────▼────────────────────┐
│                                                            │
│                    Go Backend Service                     │
│                  (Single Binary, Port 8080)               │
│                                                            │
│  ┌──────────────────────────────────────────────────┐    │
│  │              REST API + WebSocket                │    │
│  │                                                   │    │
│  │  /api/auth          - Authentication             │    │
│  │  /api/spaces        - Space CRUD                 │    │
│  │  /api/conversations - Conversation management    │    │
│  │  /api/messages      - Send messages              │    │
│  │  /ws                - WebSocket chat streaming   │    │
│  └───────────────────────┬──────────────────────────┘    │
│                          │                                │
│  ┌───────────────────────▼──────────────────────────┐    │
│  │            Business Logic Layer                   │    │
│  │                                                   │    │
│  │  • Space Service      - Manage Spaces            │    │
│  │  • Conversation Service - Manage conversations   │    │
│  │  • Session Service    - ACP session lifecycle    │    │
│  │  • Permission Service - Handle tool permissions  │    │
│  └───────────────────────┬──────────────────────────┘    │
│                          │                                │
│  ┌───────────────────────▼──────────────────────────┐    │
│  │            ACP Integration Layer                  │    │
│  │                                                   │    │
│  │  Spawns: npx @zed-industries/claude-code-acp     │    │
│  │  Communication: JSON-RPC 2.0 (stdin/stdout)      │    │
│  │  Methods: initialize, new_session, session/prompt│    │
│  │  Events: session/update (streaming)              │    │
│  └───────────────────────┬──────────────────────────┘    │
│                          │                                │
│  ┌───────────────────────▼──────────────────────────┐    │
│  │             Storage Layer (SQLite)                │    │
│  │                                                   │    │
│  │  Tables: spaces, conversations, messages,        │    │
│  │          sessions, users (future)                │    │
│  └──────────────────────────────────────────────────┘    │
│                                                            │
└────────────────────────────────────────────────────────────┘
                          │
                          │
              ┌───────────▼──────────────┐
              │  File System             │
              │                          │
              │  • Spaces directories    │
              │  • CLAUDE.md files       │
              │  • .mcp.json configs     │
              │  • User files            │
              └──────────────────────────┘
```

---

## Communication Flow: Sending a Message

```
1. User types message in Flutter app
   └─→ Flutter UI captures input

2. Flutter calls REST API
   └─→ POST /api/messages
       {
         "conversation_id": "uuid",
         "content": "Tell me about X"
       }

3. Go backend receives request
   └─→ Stores user message in database
   └─→ Retrieves conversation history
   └─→ Loads Space's CLAUDE.md file
   └─→ Builds ACP prompt with context

4. Backend calls ACP via claude-code-acp subprocess
   └─→ JSON-RPC request: session/prompt
   └─→ Includes: message + history + CLAUDE.md context

5. ACP streams response via session/update notifications
   └─→ Backend receives: text chunks, tool calls, permissions

6. Backend emits WebSocket events to Flutter
   └─→ Events: message_chunk, tool_call, permission_request

7. Flutter receives events and updates UI in real-time
   └─→ Displays streaming text
   └─→ Shows tool execution
   └─→ Prompts for permissions if needed

8. On completion, backend stores assistant message
   └─→ Database updated with full conversation
```

---

## Technology Choices

### Backend: Go

**Why Go?**
- Single binary deployment (~10-50MB memory footprint)
- Excellent concurrency (goroutines) for WebSocket handling
- AI-friendly (works great with AI coding assistants)
- Fast compilation, simple syntax, reliable
- Great for web APIs

**Framework:** Fiber
- Express-like API (familiar to many developers)
- Built-in WebSocket support
- Fast and lightweight
- Great documentation

**Database:** SQLite
- Embedded (no separate server needed)
- Perfect for single-user/small deployments
- Works everywhere (mobile, desktop, server)
- Easy to back up (single file)
- Migration path to PostgreSQL when needed

### Frontend: Flutter

**Why Flutter?**
- One codebase → iOS, Android, Web, Desktop
- Beautiful UI with 60/120fps animations
- Hot reload for fast development
- Material Design 3 + Cupertino widgets
- Massive ecosystem, Google-backed

**State Management:** Riverpod
- Type-safe, compile-time checking
- Modern, well-documented
- Better than Provider (older) and Bloc (verbose)
- Great for async operations

**HTTP Client:** Dio
- Interceptors for JWT tokens
- Request/response logging
- Error handling and retries
- Well-tested and maintained

**WebSocket:** web_socket_channel
- Official Dart package
- Cross-platform
- Simple, reliable

### ACP Integration: Hybrid Approach

**Why Hybrid (not pure Go SDK)?**
- `claude-code-acp` is battle-tested by Zed
- Official, maintained by Zed/Anthropic
- Automatic updates
- Lower risk than early-stage Go SDK

**How it works:**
```go
// Spawn subprocess
cmd := exec.Command("npx", "@zed-industries/claude-code-acp")
cmd.Env = append(os.Environ(), "ANTHROPIC_API_KEY="+apiKey)
stdin, _ := cmd.StdinPipe()
stdout, _ := cmd.StdoutPipe()
cmd.Start()

// Communicate via JSON-RPC 2.0
// Write requests to stdin
// Read responses/notifications from stdout
```

**Alternative:** `github.com/joshgarnett/agent-client-protocol-go`
- Pure Go implementation
- Early stage but viable
- Consider for future if Node.js dependency becomes problematic

---

## Data Model

### Core Entities

```
User (future multi-user support)
  └─ has many Spaces
      ├─ CLAUDE.md file (persistent context)
      ├─ .mcp.json file (optional MCP configs)
      ├─ Files and directories
      └─ has many Conversations
          └─ has many Messages
              ├─ role: "user" | "assistant"
              ├─ content: text
              └─ metadata: tool calls, etc.

Session (ACP session tracking)
  └─ belongs to Conversation
  └─ tracks ACP session_id
  └─ lifecycle: active → inactive on app restart
```

### Database Schema

```sql
-- Spaces
CREATE TABLE spaces (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,              -- Future: FK to users
    name TEXT NOT NULL,
    path TEXT NOT NULL UNIQUE,          -- Absolute path
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

-- Conversations
CREATE TABLE conversations (
    id TEXT PRIMARY KEY,
    space_id TEXT NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    title TEXT NOT NULL,                -- Auto-generated or user-set
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
    metadata TEXT                       -- JSON: tool calls, permissions, etc.
);

-- Sessions (ACP session tracking)
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,                -- ACP session_id
    conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    created_at INTEGER NOT NULL,
    last_used_at INTEGER NOT NULL,
    is_active INTEGER DEFAULT 1,        -- Boolean: 1=active, 0=inactive
    UNIQUE(conversation_id)             -- One active session per conversation
);
```

---

## Key Architectural Decisions

### Decision 1: Monorepo Structure

**Choice:** Single repo with `backend/` and `app/` directories

**Rationale:**
- Easier to coordinate changes
- Shared documentation in one place
- Single issue tracker
- Can split later if needed

**Trade-offs:**
- Larger repo size
- Different build processes in one repo

### Decision 2: Hybrid ACP Approach

**Choice:** Spawn `claude-code-acp` Node.js subprocess (not pure Go SDK)

**Rationale:**
- Battle-tested by Zed
- Official, maintained by Zed/Anthropic
- Gets updates automatically
- Lower risk for MVP

**Trade-offs:**
- Node.js dependency
- Slightly more complex process management

**Alternative Considered:** Pure Go SDK (`github.com/joshgarnett/agent-client-protocol-go`)
- May revisit in future if Node.js becomes problematic

### Decision 3: SQLite for MVP

**Choice:** SQLite (not PostgreSQL)

**Rationale:**
- Embedded, no separate server
- Works everywhere (mobile, desktop, server)
- Perfect for single-user application
- Easy backups (single file)

**Migration Path:** Move to PostgreSQL when adding:
- Multi-user support
- Team features
- Cloud sync with conflict resolution

### Decision 4: JWT Authentication

**Choice:** JWT tokens (not session cookies)

**Rationale:**
- Stateless
- Mobile-friendly
- Standard approach for API authentication
- Works across domains (future web app)

**Implementation:**
- Store in Flutter secure storage (iOS Keychain, Android Keystore)
- Include in Authorization header
- Short-lived access tokens (future: refresh tokens)

### Decision 5: Local-First Architecture

**Choice:** All data local by default, cloud sync optional (future)

**Rationale:**
- Privacy by default
- Works offline
- Fast performance
- User owns their data
- Aligns with brand philosophy (openness, control)

**Future Cloud Features:**
- Optional sync for multi-device
- Optional team Spaces
- User chooses what to sync

---

## Security Considerations

### MVP (Local-only)

- User provides their own Anthropic API key
- Stored securely (Flutter secure storage)
- Never transmitted to our servers (we don't have servers yet)
- All data local

### Future (Cloud sync)

- End-to-end encryption for synced data
- API keys never leave device
- Backend uses user's key from secure storage
- Zero-knowledge architecture where possible

---

## Scalability Considerations

### Current (MVP)

- Single Go binary per user/device
- SQLite database per user
- No shared infrastructure needed
- Can deploy on Mac Mini, Render, Fly.io, etc.

### Future Growth Path

**Phase 1: Multi-device for single user**
- Cloud sync service
- Conflict resolution
- Still using SQLite per user

**Phase 2: Team features**
- PostgreSQL for shared data
- Role-based permissions
- Team Spaces

**Phase 3: SaaS platform**
- Multi-tenant architecture
- Usage metering
- Horizontal scaling

---

## Development Workflow

### Local Development

```bash
# Terminal 1: Backend
cd backend
go run cmd/server/main.go

# Terminal 2: Frontend
cd app
flutter run
```

### Testing Strategy

**Backend:**
- Unit tests for business logic
- Integration tests for ACP client
- API tests for endpoints

**Frontend:**
- Widget tests for UI components
- Integration tests for user flows
- Golden tests for visual regression (optional)

**End-to-End:**
- Test message flow from Flutter → Backend → ACP → Backend → Flutter
- Test tool execution flow
- Test permission handling

---

## Deployment Options

### MVP Options

1. **Local only**
   - Run on same machine as user
   - Simplest to start

2. **Mac Mini + Tailscale**
   - Backend on Mac Mini
   - Tailscale for private network
   - Access from mobile via VPN
   - Free, private

3. **Render.com**
   - $7/month for persistent service
   - Public or private
   - Easy deploy from Git

4. **Fly.io**
   - Pay-as-you-go
   - Global edge deployment
   - Good for scaling later

**Recommendation:** Start local, deploy to Mac Mini for mobile testing, move to Render/Fly for beta users.

---

## Open Questions

- [ ] **Authentication for MVP:** API key only vs. account system?
- [ ] **Mobile priority:** iOS first, Android first, or both?
- [ ] **Deployment:** Where to host for beta testing?
- [ ] **MCP configuration:** UI for managing MCP servers or file-only?
- [ ] **Context restoration strategy:** Full history vs. summarization?

---

## References

- **ACP Specification:** https://agentclientprotocol.com/
- **MCP Specification:** https://modelcontextprotocol.io/
- **Fiber Docs:** https://docs.gofiber.io/
- **Flutter Docs:** https://docs.flutter.dev/
- **Riverpod Docs:** https://riverpod.dev/

---

## Next Steps

See [ROADMAP.md](docs/ROADMAP.md) for detailed implementation phases.

**Immediate priorities:**
1. Complete project structure
2. Create skeleton applications (backend + frontend)
3. Verify environment setup
4. Begin ACP integration

---

**Last Updated:** October 20, 2025
**Status:** Foundation Phase - Architecture defined, implementation starting
