# Next Steps: Tool Calls and Permission Handling

## Current Status ✅

The ACP integration is **working** for basic message exchange:
- ✅ Sessions created and cached per conversation
- ✅ Messages sent to Claude via `session/prompt`
- ✅ Responses received via `agent_message_chunk` notifications
- ✅ Responses saved to database and displayed in UI
- ✅ Loading indicator shows "Claude is thinking..."
- ✅ Null-safe list responses prevent crashes

## What's Missing 🚧

Tool calls and permission requests are **not handled**. When Claude tries to use a tool (e.g., web search), we see:

```
[ACP] method=session/update, sessionUpdate=tool_call
[ACP] method=session/request_permission (id: 0)
```

But we don't handle the permission request, so the tool never executes and Claude hangs.

## Architecture Discovery

### JSON-RPC Message Types

We currently handle 2 types:
1. **Responses** - `{id: N, result: {...}}` - Responses to our calls
2. **Notifications** - `{method: "...", params: {...}}` - One-way messages from ACP

**Missing**:
3. **Requests** - `{id: N, method: "...", params: {...}}` - ACP asking us to do something, expecting a response

Permission requests are **type 3** - the ACP agent is calling a method on *us*.

### Permission Request Flow (from para-claude-v2 research)

```
1. Claude decides to use a tool
   ↓
2. ACP sends: session/update with sessionUpdate="tool_call"
   status: "pending", toolCallId, kind, title, raw_input
   ↓
3. ACP sends: session/request_permission (JSON-RPC request, id: 0)
   params: { sessionId, toolCall, options: [allow_always, allow, reject] }
   ↓
4. Backend should:
   a) Store the pending permission request
   b) Emit event to Flutter (via WebSocket or polling endpoint)
   c) Wait for user response
   ↓
5. Flutter shows permission dialog
   User clicks: Always Allow / Allow Once / Reject
   ↓
6. Flutter calls backend API: POST /api/permissions/respond
   body: { request_id, option_id }
   ↓
7. Backend sends JSON-RPC response back to ACP:
   { jsonrpc: "2.0", id: 0, result: { optionId: "allow" } }
   ↓
8. ACP executes tool (or rejects)
   ↓
9. ACP sends: session/update with sessionUpdate="tool_call_update"
   status: "in_progress" → "success" or "failed"
   ↓
10. Show tool result in UI
```

## Implementation Tasks

### Backend (Go)

#### 1. Handle Incoming JSON-RPC Requests ⚠️ CRITICAL
File: `backend/internal/acp/jsonrpc.go`

```go
// Add new type for incoming requests
type JSONRPCRequest struct {
    JSONRPC string          `json:"jsonrpc"`
    ID      int             `json:"id"`
    Method  string          `json:"method"`
    Params  json.RawMessage `json:"params"`
}

// Add requests channel to JSONRPCClient
requests chan *JSONRPCRequest

// Update readLoop to detect and route requests
if has ID and Method:
    → requests channel
```

#### 2. Permission Request Handler
File: `backend/internal/acp/permissions.go` (new)

```go
type PermissionRequest struct {
    RequestID   int    // JSON-RPC request ID (usually 0)
    SessionID   string
    ToolCallID  string
    Title       string
    Kind        string
    RawInput    map[string]interface{}
    Options     []PermissionOption
    ResponseChan chan<- PermissionResponse
}

type PermissionOption struct {
    OptionID string  // "allow", "allow_always", "reject"
    Name     string
    Kind     string
}

type PermissionResponse struct {
    OptionID string
}

func (c *ACPClient) HandlePermissionRequest(req *PermissionRequest) {
    // Send JSON-RPC response
    response := map[string]interface{}{
        "jsonrpc": "2.0",
        "id":      req.RequestID,
        "result": map[string]interface{}{
            "optionId": req.Response.OptionID,
        },
    }
    c.jsonrpc.SendRaw(response)
}
```

#### 3. Permission Storage and API
File: `backend/internal/api/handlers/permission_handler.go` (new)

```go
type PermissionHandler struct {
    // Map: permissionID -> pending request
    pendingPermissions map[string]*PendingPermission
    mu                 sync.RWMutex
}

// GET /api/permissions - List pending permissions
// POST /api/permissions/respond - Respond to a permission
```

#### 4. Tool Call Tracking
File: `backend/internal/api/handlers/message_handler.go`

Update `startSessionListener` to handle:
- `tool_call` sessionUpdates
- `tool_call_update` sessionUpdates
- Store tool status in conversation/message metadata

### Flutter (Dart)

#### 1. Permission Dialog Widget
File: `app/lib/features/permissions/widgets/permission_dialog.dart` (new)

```dart
class PermissionDialog extends StatelessWidget {
  final PermissionRequest request;

  // Show:
  // - Tool title and kind
  // - Input parameters
  // - Three buttons: Always Allow, Allow Once, Reject
}
```

#### 2. Tool Call Display Widget
File: `app/lib/features/chat/widgets/tool_call_widget.dart` (new)

```dart
class ToolCallWidget extends StatelessWidget {
  final ToolCall toolCall;

  // Show:
  // - Tool icon based on kind
  // - Status indicator (pending/running/success/failed)
  // - Collapsible input/output
}
```

#### 3. Permission Polling/WebSocket
File: `app/lib/core/services/api_client.dart`

```dart
// Poll for pending permissions
Future<List<PermissionRequest>> getPendingPermissions()

// Respond to permission
Future<void> respondToPermission(String id, String optionId)
```

#### 4. Integrate into Chat Screen
File: `app/lib/features/chat/screens/chat_screen.dart`

- Poll for pending permissions
- Show permission dialog when detected
- Display tool calls in message list

## Quick Win: Auto-Approve Safe Tools

For MVP, we could auto-approve certain safe tools without UI:
- Web search (`kind: "fetch"`)
- File read (`kind: "read"`)
- Glob/grep patterns

This would let Claude work while we build the full permission UI.

```go
func (h *PermissionHandler) shouldAutoApprove(req *PermissionRequest) bool {
    switch req.Kind {
    case "fetch": // Web search
        return true
    case "read": // File read
        return true
    default:
        return false
    }
}
```

## Testing Plan

1. **Test with web search**: Ask "What is Nostr?" - should auto-approve fetch
2. **Test with file read**: Ask Claude to "read CLAUDE.md" - should auto-approve
3. **Test with file write**: Ask Claude to "create test.txt" - should show permission dialog
4. **Test with bash**: Ask Claude to "run ls" - should show permission dialog

## Files to Create/Modify

### Backend
- [ ] `internal/acp/jsonrpc.go` - Add request handling
- [ ] `internal/acp/permissions.go` (new) - Permission types and logic
- [ ] `internal/api/handlers/permission_handler.go` (new) - HTTP API
- [ ] `internal/api/handlers/message_handler.go` - Add tool tracking
- [ ] `cmd/server/main.go` - Add permission routes

### Flutter
- [ ] `lib/core/models/permission.dart` (new) - Permission models
- [ ] `lib/core/models/tool_call.dart` (new) - Tool call models
- [ ] `lib/features/permissions/widgets/permission_dialog.dart` (new)
- [ ] `lib/features/chat/widgets/tool_call_widget.dart` (new)
- [ ] `lib/core/services/api_client.dart` - Add permission methods
- [ ] `lib/features/chat/screens/chat_screen.dart` - Integrate permissions

## Estimated Effort

- Backend JSON-RPC request handling: 1-2 hours
- Backend permission API: 1 hour
- Flutter permission dialog: 1 hour
- Flutter tool call display: 1 hour
- Integration and testing: 1-2 hours

**Total**: 5-7 hours for full implementation

**Quick win** (auto-approve only): 1-2 hours
