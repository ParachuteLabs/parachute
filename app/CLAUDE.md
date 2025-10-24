# Frontend Context

**Flutter frontend for Parachute - Claude AI second brain.**

---

## Quick Commands

```bash
cd app && flutter run -d macos   # Run app
cd app && flutter test           # Run tests
cd app && flutter clean          # Clean build
```

---

## Core Architecture

```
Screens (UI) → Providers (Riverpod) → Services (API/WebSocket) → Models
```

**Stack:** Dart 3.5+ / Flutter 3.24+ / Riverpod state management

**Platforms:** iOS, Android, Web, macOS (primary), Windows, Linux

---

## Critical Implementation Details

### ⚠️ Package Name

```dart
✅ import 'package:app/...'        // Correct
❌ import 'package:parachute/...'  // Wrong - package name is "app"
```

### ⚠️ Riverpod Requirements

**All widgets using providers MUST be wrapped in `ProviderScope`:**
```dart
// main.dart
runApp(ProviderScope(child: ParachuteApp()));

// tests
testWidgets('Test', (tester) async {
  await tester.pumpWidget(ProviderScope(child: MyWidget()));
});
```

**Missing ProviderScope = crash!**

### ⚠️ WebSocket Event Handling

**Must call `subscribe(conversationId)` after connecting:**
```dart
await ws.connect();
ws.subscribe(conversationId);  // Required to receive events!
```

### ⚠️ API Response Format

**All collection endpoints return wrapped objects:**
```dart
✅ final Map<String, dynamic> data = response.data;
   final List<dynamic> spaces = data['spaces'];

❌ final List<dynamic> spaces = response.data;  // CRASHES!
```

**Why:** Backend returns `{"spaces": [...]}`, not `[...]`

---

## Key Components

**API Client** (`lib/core/services/api_client.dart`)
- Dio HTTP client for REST API
- Endpoints: spaces, conversations, messages
- Returns wrapped responses: `{"spaces": [...]}`

**WebSocket Service** (`lib/core/services/websocket_service.dart`)
- Real-time connection to `/ws`
- Events: `message_chunk`, `tool_call`, `tool_call_update`
- Must subscribe to conversation to receive events

**Message Provider** (`lib/features/chat/providers/message_provider.dart`)
- Manages chat state (messages, streaming, tool calls)
- Handles WebSocket events
- Updates UI via Riverpod

**Chat Screen** (`lib/features/chat/screens/chat_screen.dart`)
- Main chat interface
- Message list with auto-scroll
- Streaming indicators and tool call displays

---

## WebSocket Protocol

**Events (Backend → Flutter):**
- `subscribed` - Subscription confirmed
- `message_chunk` - Streaming text
- `tool_call` - Tool execution started
- `tool_call_update` - Tool status changed
- `message_complete` - Response finished

**Commands (Flutter → Backend):**
- `subscribe` - Subscribe to conversation updates
- `send_message` - Send user message

---

## Code Generation

Riverpod uses code generation for providers:

```bash
# Watch for changes (during development)
flutter pub run build_runner watch --delete-conflicting-outputs

# One-time generation
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## Reference Code

**Current Rust/React version:** `~/Symbols/Codes/para-claude-v2/`
- Study `src/components/ChatArea.tsx` for message display patterns
- Study `src/services/agentService.ts` for WebSocket event handling

---

## Documentation

See root `ARCHITECTURE.md` and `docs/` for detailed design docs.
