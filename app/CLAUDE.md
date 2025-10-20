# Parachute Flutter App - Development Context

## What This Is

Flutter frontend for Parachute - your open, interoperable second brain powered by Claude AI. Cross-platform UI for iOS, Android, Web, and Desktop.

## Core Responsibilities

- Chat interface with streaming messages
- Space management (list, create, switch)
- WebSocket connection for real-time events
- HTTP API calls to Go backend
- State management with Riverpod
- Beautiful, responsive UI

## Tech Stack

- **Language:** Dart 3.5+
- **Framework:** Flutter 3.24+
- **State Management:** Riverpod
- **HTTP Client:** Dio
- **WebSocket:** web_socket_channel
- **Routing:** go_router
- **Markdown:** flutter_markdown
- **Storage:** flutter_secure_storage

## Platforms

- iOS (primary mobile target)
- Android (primary mobile target)
- Web (PWA for desktop browsers)
- macOS/Windows/Linux (optional desktop apps)

## Architecture Pattern

```
Screens (UI)
↓
Providers (Riverpod state)
↓
Services (API + WebSocket)
↓
Models (data classes)
```

## Key Components

1. **API Service** (`lib/shared/services/api_service.dart`)
   - Dio HTTP client
   - Automatic JWT token injection
   - Error handling + retry logic
   - Base URL configuration

2. **WebSocket Service** (`lib/shared/services/websocket_service.dart`)
   - Real-time connection to backend
   - Event stream (message_chunk, tool_call, etc.)
   - Automatic reconnection
   - Command sending

3. **Chat Provider** (`lib/features/chat/providers/chat_provider.dart`)
   - Manages chat state (messages, streaming, tool calls)
   - Handles WebSocket events
   - Updates UI via Riverpod
   - Optimistic updates

4. **Chat Screen** (`lib/features/chat/presentation/screens/chat_screen.dart`)
   - Main interface
   - Message list with auto-scroll
   - Input field
   - Tool call displays
   - Permission dialogs

## Reference Implementation

**Current React version:** `~/Symbols/Codes/para-claude-v2/src/src/`
- Study `components/ChatArea.tsx` for message display patterns
- Study `services/agentService.ts` for event handling
- Study `components/ToolCallDisplay.tsx` for tool UI
- Study `components/Sidebar.tsx` for navigation patterns

## State Management (Riverpod)

**Provider Types:**
- `Provider` - Immutable values
- `StateProvider` - Simple mutable state
- `StateNotifierProvider` - Complex mutable state
- `FutureProvider` - Async data
- `StreamProvider` - Streaming data

**Example Chat Provider:**

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
    final currentState = state.value!;
    state = AsyncValue.data(currentState.copyWith(
      messages: [...currentState.messages, UserMessage(content)],
      isStreaming: true,
    ));

    // Send to backend via WebSocket
    final ws = ref.read(websocketServiceProvider);
    ws.sendCommand(SendMessageCommand(content));
  }

  void _handleEvent(WSEvent event) {
    switch (event.type) {
      case 'message_chunk':
        _handleMessageChunk(event);
        break;
      case 'tool_call':
        _handleToolCall(event);
        break;
      case 'permission_request':
        _handlePermissionRequest(event);
        break;
      case 'message_complete':
        _handleMessageComplete(event);
        break;
    }
  }
}
```

## WebSocket Events (Backend → Flutter)

**Event types:**
- `message_chunk` - Streaming text
- `tool_call` - Tool execution update
- `permission_request` - User approval needed
- `tool_result` - Tool execution result
- `message_complete` - Response finished
- `error` - Error occurred

## WebSocket Commands (Flutter → Backend)

**Command types:**
- `send_message` - User sent message
- `approve_permission` - User approved/denied
- `cancel` - Cancel current operation

## API Endpoints

```dart
// Spaces
GET    /api/spaces              // List spaces
POST   /api/spaces              // Create space
GET    /api/spaces/:id          // Get space
PUT    /api/spaces/:id          // Update space
DELETE /api/spaces/:id          // Delete space

// Conversations
GET  /api/conversations?space_id=...  // List conversations
POST /api/messages                    // Send message
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
# Press 'r' for hot reload, 'R' for hot restart

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
  flutter_riverpod: ^2.5.0           # State management
  riverpod_annotation: ^2.3.5        # Code generation for Riverpod
  dio: ^5.4.0                        # HTTP client
  web_socket_channel: ^3.0.0         # WebSocket
  flutter_markdown: ^0.7.0           # Markdown rendering
  go_router: ^14.0.0                 # Navigation
  flutter_secure_storage: ^9.0.0    # Secure token storage
  uuid: ^4.0.0                       # UUID generation

dev_dependencies:
  build_runner: ^2.4.0               # Code generation
  riverpod_generator: ^2.4.0         # Riverpod code gen
  flutter_lints: ^4.0.0              # Linting
```

## Responsive Design

```dart
// Breakpoints
mobile: < 600px
tablet: 600px - 900px
desktop: > 900px

// Use MediaQuery or LayoutBuilder
class ChatScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) {
      return MobileChatLayout();
    } else if (width < 900) {
      return TabletChatLayout();
    } else {
      return DesktopChatLayout();
    }
  }
}
```

## Project Structure

```
app/
├── lib/
│   ├── main.dart                # Entry point
│   ├── app.dart                 # MaterialApp setup
│   ├── core/
│   │   ├── constants/
│   │   │   └── api_constants.dart
│   │   ├── theme/
│   │   │   ├── app_theme.dart
│   │   │   └── colors.dart
│   │   ├── router/
│   │   │   └── app_router.dart
│   │   └── config/
│   │       └── app_config.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── presentation/    # Screens, widgets
│   │   │   ├── providers/       # Riverpod providers
│   │   │   └── models/          # Data models
│   │   ├── spaces/
│   │   │   ├── presentation/
│   │   │   ├── providers/
│   │   │   └── models/
│   │   ├── chat/
│   │   │   ├── presentation/
│   │   │   ├── providers/
│   │   │   └── models/
│   │   └── settings/
│   │       ├── presentation/
│   │       ├── providers/
│   │       └── models/
│   └── shared/
│       ├── widgets/             # Reusable widgets
│       ├── services/            # API, WebSocket services
│       └── models/              # Shared models
├── test/                        # Tests
├── dev-docs/                    # Developer docs
├── pubspec.yaml                 # Dependencies
└── CLAUDE.md                    # This file
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
- **go_router:** https://pub.dev/packages/go_router
- **Current React Code:** `~/Symbols/Codes/para-claude-v2/src/src/`

## Notes

- Use `flutter_secure_storage` for JWT tokens (iOS Keychain, Android Keystore)
- Material Design 3 for Android, Cupertino widgets for iOS where appropriate
- Handle platform-specific back button (Android)
- iOS safe areas (notch, home indicator)
- Test on real devices, not just simulators
- Use `debugPrint()` for logging (stripped in production)

## Code Generation

Riverpod uses code generation:

```bash
# Watch for changes and regenerate
flutter pub run build_runner watch --delete-conflicting-outputs

# One-time generation
flutter pub run build_runner build --delete-conflicting-outputs
```

## Platform-Specific Considerations

### iOS
- Use `CupertinoPageRoute` for native transitions
- Handle safe areas with `SafeArea` widget
- Test on various iPhone sizes (SE, 14, 14 Pro Max)
- Request permissions (if needed)

### Android
- Use `MaterialPageRoute` for transitions
- Handle back button with `WillPopScope`
- Test on various screen sizes and Android versions
- Handle app lifecycle (paused, resumed)

### Web
- Responsive design crucial
- Use `kIsWeb` to detect platform
- Handle URL routing properly
- Consider PWA features

---

**Last Updated:** October 20, 2025
**Status:** Foundation phase - Project structure created, ready for implementation
