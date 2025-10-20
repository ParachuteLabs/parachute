# ACP Integration Guide

**Status:** To be implemented in Phase 2

---

## Overview

Parachute uses the Agent Client Protocol (ACP) to communicate with Claude AI. This document describes our implementation approach.

---

## Approach: Hybrid (Node.js Adapter)

We spawn `@zed-industries/claude-code-acp` as a subprocess rather than using a pure Go SDK.

### Why Hybrid?

**Pros:**
- ✅ Battle-tested by Zed
- ✅ Official, maintained by Zed/Anthropic
- ✅ Automatic updates via npm
- ✅ Lower risk for MVP

**Cons:**
- ❌ Node.js dependency
- ❌ Subprocess management complexity

**Alternative Considered:** `github.com/joshgarnett/agent-client-protocol-go`
- Pure Go implementation
- Early stage (may revisit later)
- Worth considering if Node.js becomes problematic

---

## Implementation Plan

### Phase 1: Process Management (`internal/acp/process.go`)

Spawn and manage the claude-code-acp subprocess:

```go
type ACPProcess struct {
    cmd    *exec.Cmd
    stdin  io.WriteCloser
    stdout io.ReadCloser
    stderr io.ReadCloser
}

func SpawnACP(apiKey string) (*ACPProcess, error) {
    cmd := exec.Command("npx", "@zed-industries/claude-code-acp")

    // Set environment
    cmd.Env = append(os.Environ(),
        "ANTHROPIC_API_KEY="+apiKey,
    )

    // Attach pipes
    stdin, _ := cmd.StdinPipe()
    stdout, _ := cmd.StdoutPipe()
    stderr, _ := cmd.StderrPipe()

    // Start process
    if err := cmd.Start(); err != nil {
        return nil, err
    }

    return &ACPProcess{cmd, stdin, stdout, stderr}, nil
}
```

### Phase 2: JSON-RPC Client (`internal/acp/jsonrpc.go`)

Implement JSON-RPC 2.0 communication:

```go
type JSONRPCRequest struct {
    JSONRPC string      `json:"jsonrpc"`
    ID      int         `json:"id"`
    Method  string      `json:"method"`
    Params  interface{} `json:"params"`
}

type JSONRPCResponse struct {
    JSONRPC string      `json:"jsonrpc"`
    ID      int         `json:"id"`
    Result  interface{} `json:"result,omitempty"`
    Error   *RPCError   `json:"error,omitempty"`
}

func (p *ACPProcess) SendRequest(method string, params interface{}) (interface{}, error) {
    // Build request
    req := JSONRPCRequest{
        JSONRPC: "2.0",
        ID:      p.nextID(),
        Method:  method,
        Params:  params,
    }

    // Write to stdin
    encoder := json.NewEncoder(p.stdin)
    if err := encoder.Encode(req); err != nil {
        return nil, err
    }

    // Read response from stdout
    decoder := json.NewDecoder(p.stdout)
    var resp JSONRPCResponse
    if err := decoder.Decode(&resp); err != nil {
        return nil, err
    }

    return resp.Result, nil
}
```

### Phase 3: ACP Methods (`internal/acp/client.go`)

Implement ACP protocol methods:

```go
type ACPClient struct {
    process *ACPProcess
}

// Initialize the ACP connection
func (c *ACPClient) Initialize() error {
    params := map[string]interface{}{
        "client_name": "Parachute",
        "client_version": "0.1.0",
    }

    _, err := c.process.SendRequest("initialize", params)
    return err
}

// Create a new session
func (c *ACPClient) NewSession(workingDir string, mcpServers []MCPServer) (string, error) {
    params := map[string]interface{}{
        "working_directory": workingDir,
        "mcp_servers": mcpServers,
    }

    result, err := c.process.SendRequest("new_session", params)
    if err != nil {
        return "", err
    }

    // Extract session_id from result
    sessionID := result.(map[string]interface{})["session_id"].(string)
    return sessionID, nil
}

// Send a prompt to a session
func (c *ACPClient) SessionPrompt(sessionID, prompt string) error {
    params := map[string]interface{}{
        "session_id": sessionID,
        "prompt": prompt,
    }

    _, err := c.process.SendRequest("session/prompt", params)
    return err
}
```

### Phase 4: Notification Handling

Handle `session/update` notifications (streaming):

```go
func (c *ACPClient) ListenForNotifications(handler func(Notification)) {
    decoder := json.NewDecoder(c.process.stdout)

    for {
        var msg JSONRPCMessage
        if err := decoder.Decode(&msg); err != nil {
            // Handle error
            break
        }

        if msg.Method != "" {
            // It's a notification (no ID)
            notification := Notification{
                Method: msg.Method,
                Params: msg.Params,
            }
            handler(notification)
        }
    }
}
```

---

## JSON-RPC Communication Examples

### Request: Initialize

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "client_name": "Parachute",
    "client_version": "0.1.0"
  }
}
```

### Response: Initialize

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "server_name": "claude-code-acp",
    "server_version": "1.0.0"
  }
}
```

### Request: New Session

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "new_session",
  "params": {
    "working_directory": "/Users/me/my-space",
    "mcp_servers": []
  }
}
```

### Response: New Session

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "session_id": "sess_abc123"
  }
}
```

### Request: Session Prompt

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "session/prompt",
  "params": {
    "session_id": "sess_abc123",
    "prompt": "Tell me about Go"
  }
}
```

### Notification: Session Update (Streaming)

```json
{
  "jsonrpc": "2.0",
  "method": "session/update",
  "params": {
    "session_id": "sess_abc123",
    "update": {
      "type": "content_block_delta",
      "delta": {
        "type": "text_delta",
        "text": "Go is a programming language..."
      }
    }
  }
}
```

---

## References

- **ACP Specification:** https://agentclientprotocol.com/
- **Current Rust Implementation:** `~/Symbols/Codes/para-claude-v2/src-tauri/src/acp_v2/`
  - See `manager.rs` for process management patterns
  - See `client.rs` for permission handling
- **Zed's Implementation:** `~/Symbols/Codes/zed/crates/agent_ui/`

---

## Next Steps

1. Implement `internal/acp/process.go` - subprocess management
2. Implement `internal/acp/jsonrpc.go` - JSON-RPC client
3. Implement `internal/acp/client.go` - ACP methods
4. Add tests for each component
5. Integration test: Full prompt → response flow

---

**Last Updated:** October 20, 2025
**Status:** Planning complete, ready for Phase 2 implementation
