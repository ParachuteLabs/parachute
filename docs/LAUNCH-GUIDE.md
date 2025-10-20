# Parachute - Project Launch Guide

**Version:** 2.0
**Date:** October 20, 2025
**Tagline:** "The mind is like a parachute, it doesn't work if it's not open" — Frank Zappa
**Purpose:** Bootstrap the Go + Flutter redesign with all the context needed to begin
**Next Step:** Use this document to initialize the new project

---

## Table of Contents

1. [What We're Building](#what-were-building)
2. [Why We're Rebuilding](#why-were-rebuilding)
3. [Architecture at a Glance](#architecture-at-a-glance)
4. [Technology Stack](#technology-stack)
5. [Key Architectural Decisions](#key-architectural-decisions)
6. [Getting Started - First Steps](#getting-started---first-steps)
7. [Project Structure to Create](#project-structure-to-create)
8. [Initial CLAUDE.md Files](#initial-claudemd-files)
9. [Dev-Docs to Create](#dev-docs-to-create)
10. [Where to Find Information](#where-to-find-information)
11. [Development Workflow](#development-workflow)
12. [Success Criteria for MVP](#success-criteria-for-mvp)

---

## What We're Building

**Parachute** is your open, interoperable second brain powered by Claude AI. It makes the Agent Client Protocol (ACP) as accessible as Claude Desktop, but with the power of local file access, MCP servers, and cross-platform availability.

**Philosophy:** Like a parachute, your mind works best when it's open. Parachute embraces openness through:

- **Open protocols** (ACP, MCP)
- **Open data** (your files, your control)
- **Open platforms** (iOS, Android, Web, Desktop)
- **Open integration** (MCP servers connect to anything)

### Core Innovation: Spaces

Each **Space** is a cognitive context:

- Has its own `CLAUDE.md` file (persistent AI memory)
- Contains relevant files and resources
- Independent conversation history
- Optional MCP server configurations (`.mcp.json`)
- Separate ACP session management

Think: "Rooms in your digital memory palace"

### The Problem We Solve

Existing tools force you to choose:

- **Claude Desktop:** Simple but limited (no file access, no MCP, desktop-only)
- **Claude Code CLI:** Powerful but terminal-only, steep learning curve
- **Zed:** IDE-integrated but must use their editor

**Parachute provides:** Power + Simplicity + Openness + Any Platform

### Target Users

**Primary:** Anyone building a second brain

- Knowledge workers organizing information
- Researchers managing sources and notes
- Writers working on multiple projects
- Consultants managing client contexts

**Secondary:** Developers (complementary to IDE, not a replacement)

**Future:** Teams and organizations sharing knowledge

---

## Why We're Rebuilding

### Current State (Tauri + Rust + React)

✅ Working well, 95% complete
✅ Full ACP v2 integration
✅ MCP support, session persistence, slash commands
❌ Desktop-only (no mobile/web)
❌ Tauri ecosystem smaller than Go/Flutter
❌ Harder to add multi-user, cloud features later

### New Direction (Go + Flutter)

✅ **True cross-platform:** iOS, Android, Web, Desktop from one codebase
✅ **AI-friendly:** Go and Flutter excel with AI coding assistants
✅ **Modern stack:** Better DX, tooling, ecosystem
✅ **Modular:** Clean API/UI separation enables future features
✅ **Scalable:** Easy path to team features, cloud sync, multi-user

### What We Keep

✅ All core concepts (Spaces, CLAUDE.md, ACP integration pattern)
✅ UI/UX patterns that work well
✅ Database schema and domain models
✅ Hybrid ACP approach (using claude-code-acp)

---

## Architecture at a Glance

```
┌─────────────────────────────────────────┐
│       Go Backend Service                │
│       (Single binary, port 8080)        │
│                                         │
│  REST API + WebSocket Server            │
│         ↓                               │
│  Business Logic (Spaces, Conversations) │
│         ↓                               │
│  ACP Integration (claude-code-acp)      │
│         ↓                               │
│  SQLite Database                        │
└─────────────────────────────────────────┘
              ↕
      Network (HTTP/WS)
              ↕
┌─────────────────────────────────────────┐
│       Flutter Frontend                  │
│  (iOS, Android, Web, Desktop)           │
│                                         │
│  Screens (Chat, Spaces, Settings)       │
│         ↓                               │
│  State Management (Riverpod)            │
│         ↓                               │
│  API Service (HTTP) + WebSocket         │
└─────────────────────────────────────────┘
```

### Communication Flow (Sending a Message)

1. User types in Flutter app
2. Flutter calls Go backend REST API (`POST /api/messages`)
3. Go backend stores message, gets conversation history
4. Go backend calls ACP via claude-code-acp subprocess
5. ACP streams response via `session/update` notifications
6. Go backend emits WebSocket events to Flutter
7. Flutter receives events, updates UI in real-time

---

## Technology Stack

### Backend: Go 1.25+

**Framework:** Fiber (Express-like, WebSocket support)
**Database:** SQLite with pure Go driver (`modernc.org/sqlite`)
**ACP Integration:** Hybrid approach (spawn `claude-code-acp` Node.js process)
**Auth:** JWT tokens

**Why Go:**

- AI-friendly (excellent with AI coding assistants)
- Single binary deployment, low memory (~10-50MB)
- Great for web APIs, excellent concurrency (goroutines)
- Fast, reliable, simple syntax

### Frontend: Flutter 3.24+

**State Management:** Riverpod
**HTTP Client:** Dio
**WebSocket:** web_socket_channel
**UI:** Material Design 3 + Cupertino widgets

**Why Flutter:**

- One codebase → iOS, Android, Web, Desktop
- Beautiful UI, 60/120fps animations
- Hot reload, great tooling
- Google-backed, massive ecosystem

### ACP Integration: Hybrid (Recommended)

**Approach:** Go spawns `npx @zed-industries/claude-code-acp` subprocess
**Communication:** JSON-RPC 2.0 over stdin/stdout

**Why Hybrid (not pure Go SDK):**

- Battle-tested (Zed uses this)
- Official, maintained by Zed/Anthropic
- Gets updates automatically
- Lower risk

**Alternative:** `github.com/joshgarnett/agent-client-protocol-go` (early stage, but viable)

---

## Key Architectural Decisions

### Decision 1: Hybrid ACP Approach

**Choice:** Use `claude-code-acp` Node.js adapter (not pure Go SDK)
**Rationale:** Proven, stable, official
**Trade-off:** Node.js dependency vs. stability

### Decision 2: Fiber Web Framework

**Choice:** Fiber for Go backend
**Rationale:** Express-like API, excellent WebSocket support, fast
**Alternatives:** Echo (more structured), Chi (minimalist)

### Decision 3: Riverpod State Management

**Choice:** Riverpod for Flutter
**Rationale:** Modern, type-safe, compile-time checking
**Alternatives:** Bloc (more verbose), Provider (older)

### Decision 4: SQLite Database

**Choice:** SQLite (not PostgreSQL)
**Rationale:** Embedded, no server, works everywhere, perfect for MVP
**Migration Path:** Move to PostgreSQL when multi-user needed

### Decision 5: JWT Authentication

**Choice:** JWT tokens (not session cookies)
**Rationale:** Stateless, mobile-friendly, standard

---

## Getting Started - First Steps

### Phase 1: Environment Setup

**1. Install Go**

```bash
# macOS
brew install go

# Verify
go version  # Should be 1.25+
```

**2. Install Flutter**

```bash
# macOS
brew install --cask flutter

# Verify
flutter doctor
```

**3. Install Node.js (for claude-code-acp)**

```bash
# macOS
brew install node

# Verify
node -v  # Should be 18+
npx @zed-industries/claude-code-acp --version
```

**4. Create Project Directories**

```bash
# Backend
mkdir -p ~/Projects/thinking-space-backend
cd ~/Projects/thinking-space-backend
go mod init github.com/yourusername/thinking-space-backend

# Frontend
cd ~/Projects
flutter create thinking_space_app
```

### Phase 2: Backend Skeleton

**Create basic structure:**

```bash
cd ~/Projects/thinking-space-backend

mkdir -p cmd/server
mkdir -p internal/{api,domain,acp,storage,config}
mkdir -p pkg/jsonrpc
mkdir -p deployments/docker
mkdir -p scripts
```

**Create `cmd/server/main.go`:**

```go
package main

import (
    "log"
    "github.com/gofiber/fiber/v3"
)

func main() {
    app := fiber.New()

    app.Get("/health", func(c fiber.Ctx) error {
        return c.JSON(fiber.Map{"status": "ok"})
    })

    log.Fatal(app.Listen(":8080"))
}
```

**Test it:**

```bash
go run cmd/server/main.go
curl http://localhost:8080/health
```

### Phase 3: Frontend Skeleton

**Create basic structure:**

```bash
cd ~/Projects/thinking_space_app

mkdir -p lib/{core,features,shared,utils}
mkdir -p lib/core/{constants,theme,router,config}
mkdir -p lib/features/{auth,spaces,chat,settings}
mkdir -p lib/shared/{widgets,services,models}
```

**Update `lib/main.dart`:**

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thinking Space',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thinking Space'),
      ),
      body: const Center(
        child: Text('Hello World'),
      ),
    );
  }
}
```

**Test it:**

```bash
flutter run
```

---

## Project Structure to Create

### Backend (Go)

```
parachute-backend/
├── cmd/server/main.go           # Entry point ← START HERE
├── internal/
│   ├── api/
│   │   ├── handlers/            # HTTP handlers (spaces, chat, auth)
│   │   ├── middleware/          # Auth, CORS, logging
│   │   ├── websocket/           # WebSocket chat handler
│   │   └── routes.go            # Route definitions
│   ├── domain/
│   │   ├── space/               # Space entity + business logic
│   │   ├── conversation/        # Conversation management
│   │   ├── message/             # Message handling
│   │   └── session/             # ACP session management
│   ├── acp/
│   │   ├── client.go            # ACP client ← CRITICAL
│   │   ├── process.go           # claude-code-acp process mgmt
│   │   ├── jsonrpc.go           # JSON-RPC 2.0 client
│   │   └── types.go             # ACP data types
│   ├── storage/
│   │   └── sqlite/              # SQLite repos + migrations
│   └── config/
│       └── config.go            # App configuration
├── .env.example                 # Environment variables
├── Makefile                     # Common tasks (run, build, test)
├── CLAUDE.md                    # ← CREATE THIS FIRST
└── README.md
```

### Frontend (Flutter)

```
parachute_app/
├── lib/
│   ├── main.dart                # Entry point
│   ├── app.dart                 # MaterialApp setup
│   ├── core/
│   │   ├── constants/           # API URLs, app constants
│   │   ├── theme/               # Light/dark themes
│   │   └── router/              # go_router navigation
│   ├── features/
│   │   ├── auth/                # Login, API key input
│   │   ├── spaces/              # Space list, create, manage
│   │   ├── chat/                # Chat screen, messages, streaming
│   │   └── settings/            # Settings screen
│   └── shared/
│       ├── widgets/             # Reusable widgets
│       └── services/
│           ├── api_service.dart # HTTP client (Dio)
│           └── websocket_service.dart # WS connection
├── pubspec.yaml                 # Dependencies
├── CLAUDE.md                    # ← CREATE THIS FIRST
└── README.md
```

---

## Initial CLAUDE.md Files

### Backend CLAUDE.md

Create `parachute-backend/CLAUDE.md`:

```markdown
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

````

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
````

**Why:** Battle-tested, official, maintained by Zed.

**Alternative:** `github.com/joshgarnett/agent-client-protocol-go` (early stage).

## Database Schema

```sql
-- Spaces
CREATE TABLE spaces (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    path TEXT NOT NULL,  -- Absolute path
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

-- Conversations
CREATE TABLE conversations (
    id TEXT PRIMARY KEY,
    space_id TEXT NOT NULL REFERENCES spaces(id),
    title TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

-- Messages
CREATE TABLE messages (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL REFERENCES conversations(id),
    role TEXT NOT NULL,  -- "user" or "assistant"
    content TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    metadata TEXT  -- JSON for tool calls, etc.
);

-- Sessions (ACP session tracking)
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,  -- ACP session_id
    conversation_id TEXT NOT NULL REFERENCES conversations(id),
    created_at INTEGER NOT NULL,
    last_used_at INTEGER NOT NULL,
    is_active INTEGER DEFAULT 1
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
DATABASE_PATH=./data/thinking-space.db
JWT_SECRET=<generate-random>
ANTHROPIC_API_KEY=<optional-default>
SPACES_PATH=./data/spaces
LOG_LEVEL=info
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

````

### Frontend CLAUDE.md

Create `thinking_space_app/CLAUDE.md`:

```markdown
# Thinking Space Flutter App - Development Context

## What This Is

Flutter frontend for Thinking Space - a cross-platform UI for chatting with Claude AI.

## Core Responsibilities

- Chat interface with streaming messages
- Space management (list, create, switch)
- WebSocket connection for real-time events
- HTTP API calls to Go backend
- State management with Riverpod

## Tech Stack

- **Language:** Dart 3.5+
- **Framework:** Flutter 3.24+
- **State Management:** Riverpod
- **HTTP Client:** Dio
- **WebSocket:** web_socket_channel
- **Routing:** go_router
- **Markdown:** flutter_markdown

## Platforms

- iOS (primary mobile target)
- Android (primary mobile target)
- Web (PWA for desktop browsers)
- macOS/Windows/Linux (optional desktop apps)

## Architecture Pattern

````

Screens (UI)
↓
Providers (Riverpod state)
↓
Services (API + WebSocket)
↓
Models (data classes)

````

## Key Components

1. **API Service** (`lib/shared/services/api_service.dart`)
   - Dio HTTP client
   - Automatic JWT token injection
   - Error handling + retry logic

2. **WebSocket Service** (`lib/shared/services/websocket_service.dart`)
   - Real-time connection to backend
   - Event stream (message_chunk, tool_call, etc.)
   - Automatic reconnection

3. **Chat Provider** (`lib/features/chat/providers/chat_provider.dart`)
   - Manages chat state (messages, streaming, tool calls)
   - Handles WebSocket events
   - Updates UI via Riverpod

4. **Chat Screen** (`lib/features/chat/presentation/screens/chat_screen.dart`)
   - Main interface
   - Message list, input, tool call displays
   - Permission dialogs

## Reference Implementation

**Current React version:** `~/Symbols/Codes/para-claude-v2/src/src/`
- Study `components/ChatArea.tsx` for message display patterns
- Study `services/agentService.ts` for event handling
- Study `components/ToolCallDisplay.tsx` for tool UI

## State Management (Riverpod)

```dart
@riverpod
class ChatNotifier extends _$ChatNotifier {
  @override
  FutureOr<ChatState> build() async {
    // Initialize WebSocket
    final ws = ref.read(websocketServiceProvider);
    await ws.connect();

    // Listen to events
    ws.events.listen(_handleEvent);

    return const ChatState(messages: [], isStreaming: false);
  }

  void sendMessage(String content) {
    // Update state optimistically
    // Send to backend via WebSocket
  }

  void _handleEvent(WSEvent event) {
    // Update state based on event type
  }
}
````

## WebSocket Events (Backend → Flutter)

```dart
// Event types:
// - "message_chunk": Streaming text
// - "tool_call": Tool execution update
// - "permission_request": User approval needed
// - "message_complete": Response finished
// - "error": Error occurred
```

## WebSocket Commands (Flutter → Backend)

```dart
// Command types:
// - "send_message": User sent message
// - "approve_permission": User approved/denied
// - "cancel": Cancel current operation
```

## API Endpoints

```
POST /api/auth/login              # Login (get JWT)
GET  /api/spaces                  # List spaces
POST /api/spaces                  # Create space
GET  /api/conversations?space_id  # List conversations
POST /api/messages                # Send message (returns request_id)
```

## Development Workflow

```bash
# Run on iOS simulator
flutter run

# Run on Android emulator
flutter run

# Run on Web
flutter run -d chrome

# Hot reload (automatic during development)

# Run tests
flutter test

# Build for production
flutter build ios
flutter build android
flutter build web
```

## Dependencies

```yaml
dependencies:
  flutter_riverpod: ^2.5.0 # State management
  dio: ^5.4.0 # HTTP client
  web_socket_channel: ^3.0.0 # WebSocket
  flutter_markdown: ^0.7.0 # Markdown rendering
  go_router: ^14.0.0 # Navigation
  flutter_secure_storage: ^9.0.0 # Secure token storage
```

## Responsive Design

```dart
// Breakpoints
mobile: < 600px
tablet: 600px - 900px
desktop: > 900px

// Use LayoutBuilder or MediaQuery
ResponsiveLayout(
  mobile: ChatScreenMobile(),
  tablet: ChatScreenTablet(),
  desktop: ChatScreenDesktop(),
)
```

## Next Steps (Priority Order)

1. ✅ Create project structure
2. ⏳ Set up Riverpod + go_router
3. ⏳ Implement API service (Dio + JWT)
4. ⏳ Implement WebSocket service
5. ⏳ Create Space list screen
6. ⏳ Create Chat screen (main interface)
7. ⏳ Add message bubbles (user + assistant)
8. ⏳ Add streaming message widget
9. ⏳ Add tool call cards
10. ⏳ Add permission dialogs
11. ⏳ Test on iOS/Android/Web

## Resources

- **Flutter Docs:** https://docs.flutter.dev/
- **Riverpod:** https://riverpod.dev/
- **Dio:** https://pub.dev/packages/dio
- **Current React Code:** `~/Symbols/Codes/para-claude-v2/src/src/`

## Notes

- Use `flutter_secure_storage` for JWT tokens (iOS Keychain, Android Keystore)
- Material Design 3 for Android, Cupertino widgets for iOS where appropriate
- Handle platform-specific back button (Android)
- iOS safe areas (notch, home indicator)

````

---

## Dev-Docs to Create

### Backend Dev-Docs

Create `thinking-space-backend/dev-docs/`:

1. **`README.md`** - Doc index
2. **`ACP-INTEGRATION.md`** - How ACP works, our approach
3. **`DATABASE-SCHEMA.md`** - Full schema, migrations
4. **`API-SPEC.md`** - Complete endpoint documentation (create as needed)
5. **`DEPLOYMENT.md`** - How to deploy (Render, Docker, etc.)

### Frontend Dev-Docs

Create `thinking_space_app/dev-docs/`:

1. **`README.md`** - Doc index
2. **`STATE-MANAGEMENT.md`** - Riverpod patterns we use
3. **`API-CLIENT.md`** - How to call backend
4. **`WEBSOCKET.md`** - WebSocket event handling
5. **`DESIGN-SYSTEM.md`** - UI components, theme

### Shared Docs

These live in a separate repo or parent directory:

1. **`ARCHITECTURE.md`** - Overall system design
2. **`USER-GUIDE.md`** - How to use the app
3. **`PROGRESS.md`** - Track what's done

---

## Where to Find Information

### When Building Backend (Go)

**Question:** How does ACP work?
**Answer:** Read https://agentclientprotocol.com/ AND study `~/Symbols/Codes/para-claude-v2/src-tauri/src/acp_v2/manager.rs`

**Question:** How to spawn claude-code-acp?
**Answer:** See current Rust implementation in `manager.rs`, lines 75-150

**Question:** How to handle permissions?
**Answer:** Study `~/Symbols/Codes/para-claude-v2/src-tauri/src/acp_v2/client.rs`, the `request_permission` method

**Question:** How to do context restoration?
**Answer:** See `~/Symbols/Codes/para-claude-v2/dev-docs/CONTEXT-MANAGEMENT-2025-10-18.md`

**Question:** What's the database schema?
**Answer:** See `~/Symbols/Codes/para-claude-v2/src-tauri/src/sessions.rs` and `conversations.rs`

**Question:** How to load MCP configs?
**Answer:** Port from `~/Symbols/Codes/para-claude-v2/src-tauri/src/mcp_config.rs`

### When Building Frontend (Flutter)

**Question:** What should the UI look like?
**Answer:** Reference current React app in `~/Symbols/Codes/para-claude-v2/src/src/components/`

**Question:** How to display streaming messages?
**Answer:** Study `~/Symbols/Codes/para-claude-v2/src/src/components/ChatArea.tsx`

**Question:** How to display tool calls?
**Answer:** Study `~/Symbols/Codes/para-claude-v2/src/src/components/ToolCallDisplay.tsx`

**Question:** How to handle WebSocket events?
**Answer:** Study `~/Symbols/Codes/para-claude-v2/src/src/services/agentService.ts`

**Question:** What API endpoints exist?
**Answer:** See backend `dev-docs/API-SPEC.md` (create as you build)

### General Resources

**ACP Specification:** https://agentclientprotocol.com/
**Zed's Implementation:** `~/Symbols/Codes/zed/` (browse agent-related crates)
**Current Working App:** `~/Symbols/Codes/para-claude-v2/`
**Go Web Frameworks:** https://docs.gofiber.io/
**Flutter Docs:** https://docs.flutter.dev/
**Riverpod Guide:** https://riverpod.dev/docs/introduction/getting_started

---

## Development Workflow

### Daily Development

1. **Start Backend:**
   ```bash
   cd thinking-space-backend
   go run cmd/server/main.go
   # Or with hot reload: air
````

2. **Start Frontend:**

   ```bash
   cd thinking_space_app
   flutter run
   # Choose device (iOS sim, Android, Chrome)
   ```

3. **Make Changes:**
   - Backend: Edit Go files, server auto-restarts (with air)
   - Frontend: Edit Dart files, hot reload (r) or hot restart (R)

4. **Test:**

   ```bash
   # Backend
   go test ./...

   # Frontend
   flutter test
   ```

### Git Workflow

```bash
# Separate repos
thinking-space-backend/  (Go backend)
thinking_space_app/      (Flutter frontend)

# Or monorepo
thinking-space/
├── backend/
└── app/
```

### Documentation Updates

**Update CLAUDE.md whenever:**

- Architecture changes
- New patterns emerge
- Important decisions made
- New components added

**Update dev-docs whenever:**

- API changes
- Database schema changes
- New features complete

---

## Success Criteria for MVP

### Backend MVP

- [ ] Go server runs and serves REST API
- [ ] ACP integration works (spawn claude-code-acp, send/receive messages)
- [ ] WebSocket streaming works
- [ ] SQLite database persists data
- [ ] JWT authentication works
- [ ] Spaces CRUD complete
- [ ] Conversations + messages persist
- [ ] MCP config loading works
- [ ] Deploys to one environment (Render or Mac Mini)

### Frontend MVP

- [ ] Flutter app runs on iOS, Android, Web
- [ ] Login screen (API key input)
- [ ] Space list screen (view, create, switch)
- [ ] Chat screen (send message, see response)
- [ ] Streaming messages display correctly
- [ ] Tool calls shown (basic display)
- [ ] Permission dialogs work (approve/deny)
- [ ] Responsive design (works on phone and tablet)

### Integration MVP

- [ ] End-to-end: Send message from Flutter → Get streaming response
- [ ] Conversations persist across app restarts
- [ ] Context restoration works (history included in prompts)
- [ ] Tool calls flow: Backend → Flutter → User approval → Backend
- [ ] File operations work (Claude can read/write files)
- [ ] MCP servers can be configured and work

### MVP Timeline

**Aggressive (AI-assisted, full-time):** 4-6 weeks
**Realistic (AI-assisted, part-time):** 8-10 weeks
**Conservative (learning as you go):** 12-16 weeks

---

## Next Immediate Steps

### Right Now (Today)

1. **Create backend project:**

   ```bash
   cd ~/Projects
   mkdir thinking-space-backend
   cd thinking-space-backend
   go mod init github.com/yourusername/thinking-space-backend
   ```

2. **Create this CLAUDE.md file** (copy from this guide)

3. **Create `cmd/server/main.go`** (minimal working server)

4. **Test it:** `go run cmd/server/main.go`

5. **Create frontend project:**

   ```bash
   cd ~/Projects
   flutter create thinking_space_app
   cd thinking_space_app
   ```

6. **Create Flutter CLAUDE.md** (copy from this guide)

7. **Test it:** `flutter run`

### This Week

1. **Backend:**
   - Implement ACP client (spawn claude-code-acp)
   - Test basic JSON-RPC communication
   - Get one ACP method working (initialize)

2. **Frontend:**
   - Set up Riverpod
   - Create basic chat screen UI
   - Test HTTP call to backend health endpoint

3. **Documentation:**
   - Create `dev-docs/ACP-INTEGRATION.md` in backend
   - Document what you learn as you go

### Next Week

1. **Backend:**
   - Complete ACP integration (new_session, session/prompt)
   - Implement WebSocket handler
   - Add SQLite database

2. **Frontend:**
   - Implement WebSocket service
   - Connect to backend WebSocket
   - Display streaming messages

3. **Integration:**
   - Test end-to-end message flow
   - Fix any issues

---

## Questions to Answer Before Starting

1. **Where to deploy for testing?**
   - [ ] Mac Mini + Tailscale (free, private)
   - [ ] Render ($$7/month, public or private)
   - [ ] Local only (for now)

2. **Mobile priority?**
   - [ ] iOS first
   - [ ] Android first
   - [ ] Both simultaneously

3. **Timeline?**
   - [ ] Full-time focus (4-6 weeks)
   - [ ] Part-time (8-10 weeks)
   - [ ] Exploratory (12+ weeks)

4. **Authentication first?**
   - [ ] API key only (simplest)
   - [ ] JWT from day 1 (more work upfront, better long-term)

---

## Final Note: How to Use This Document

**This document is your launch pad.** Use it to:

1. ✅ **Bootstrap new projects** - Copy CLAUDE.md files, create structure
2. ✅ **Guide AI assistants** - Feed relevant sections to Claude/Cursor when coding
3. ✅ **Make decisions** - Reference architecture decisions when stuck
4. ✅ **Find information** - Use "Where to Find Information" section liberally
5. ✅ **Track progress** - Update success criteria as you complete items

**Update this document** as you learn and make decisions. It's a living guide.

**When you get stuck,** come back here and find the relevant reference (current Rust code, Zed's approach, ACP spec).

**When you finish MVP,** you'll have built two clean codebases with great documentation, ready to scale.

---

**Ready to begin? Start with "Next Immediate Steps" above.** 🚀
