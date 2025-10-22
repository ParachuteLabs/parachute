package acp

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"sync"
	"sync/atomic"
)

// JSONRPCRequest represents a JSON-RPC 2.0 request
type JSONRPCRequest struct {
	JSONRPC string      `json:"jsonrpc"`
	ID      int         `json:"id"`
	Method  string      `json:"method"`
	Params  interface{} `json:"params,omitempty"`
}

// JSONRPCResponse represents a JSON-RPC 2.0 response
type JSONRPCResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      int             `json:"id"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *RPCError       `json:"error,omitempty"`
}

// JSONRPCNotification represents a JSON-RPC 2.0 notification (no ID)
type JSONRPCNotification struct {
	JSONRPC string          `json:"jsonrpc"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
}

// JSONRPCIncomingRequest represents a JSON-RPC 2.0 request from the server to us
type JSONRPCIncomingRequest struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      *int            `json:"id,omitempty"` // Pointer so we can distinguish between missing ID and ID=0
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
}

// RPCError represents a JSON-RPC 2.0 error
type RPCError struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

func (e *RPCError) Error() string {
	return fmt.Sprintf("RPC error %d: %s", e.Code, e.Message)
}

// JSONRPCClient manages JSON-RPC communication with ACP process
type JSONRPCClient struct {
	process       *ACPProcess
	nextID        atomic.Int32
	pendingCalls  map[int]chan *JSONRPCResponse
	mu            sync.Mutex
	notifications chan *JSONRPCNotification
	requests      chan *JSONRPCIncomingRequest
}

// NewJSONRPCClient creates a new JSON-RPC client for the ACP process
func NewJSONRPCClient(process *ACPProcess) *JSONRPCClient {
	client := &JSONRPCClient{
		process:       process,
		pendingCalls:  make(map[int]chan *JSONRPCResponse),
		notifications: make(chan *JSONRPCNotification, 100),
		requests:      make(chan *JSONRPCIncomingRequest, 100),
	}

	// Start reading responses in background
	go client.readLoop()

	return client
}

// Call sends a JSON-RPC request and waits for the response
func (c *JSONRPCClient) Call(method string, params interface{}) (json.RawMessage, error) {
	// Generate request ID
	id := int(c.nextID.Add(1))

	// Create response channel
	respChan := make(chan *JSONRPCResponse, 1)
	c.mu.Lock()
	c.pendingCalls[id] = respChan
	c.mu.Unlock()

	// Clean up on exit
	defer func() {
		c.mu.Lock()
		delete(c.pendingCalls, id)
		c.mu.Unlock()
	}()

	// Build request
	req := JSONRPCRequest{
		JSONRPC: "2.0",
		ID:      id,
		Method:  method,
		Params:  params,
	}

	// Marshal to JSON
	data, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	// Send request (with newline delimiter)
	c.process.mu.Lock()
	_, err = c.process.stdin.Write(append(data, '\n'))
	c.process.mu.Unlock()

	if err != nil {
		return nil, fmt.Errorf("failed to send request: %w", err)
	}

	// Wait for response
	resp := <-respChan

	// Check for error
	if resp.Error != nil {
		return nil, resp.Error
	}

	return resp.Result, nil
}

// Notifications returns a channel that receives JSON-RPC notifications
func (c *JSONRPCClient) Notifications() <-chan *JSONRPCNotification {
	return c.notifications
}

// Requests returns a channel that receives JSON-RPC requests from the server
func (c *JSONRPCClient) Requests() <-chan *JSONRPCIncomingRequest {
	return c.requests
}

// SendResponse sends a JSON-RPC response back to the server
func (c *JSONRPCClient) SendResponse(id int, result interface{}) error {
	response := map[string]interface{}{
		"jsonrpc": "2.0",
		"id":      id,
		"result":  result,
	}

	data, err := json.Marshal(response)
	if err != nil {
		return fmt.Errorf("failed to marshal response: %w", err)
	}

	// Log the exact JSON being sent for debugging
	fmt.Fprintf(os.Stderr, "[ACP] 📤 Sending response: %s\n", string(data))

	c.process.mu.Lock()
	_, err = c.process.stdin.Write(append(data, '\n'))
	c.process.mu.Unlock()

	if err != nil {
		return fmt.Errorf("failed to send response: %w", err)
	}

	fmt.Fprintf(os.Stderr, "[ACP] ✅ Sent response for request ID=%d\n", id)
	return nil
}

// readLoop continuously reads from stdout and dispatches messages
func (c *JSONRPCClient) readLoop() {
	scanner := bufio.NewScanner(c.process.stdout)

	lineCount := 0
	for scanner.Scan() {
		line := scanner.Bytes()
		lineCount++

		// DEBUG: Log all raw output from ACP
		fmt.Fprintf(os.Stderr, "[ACP stdout #%d] %s\n", lineCount, string(line))

		// Try to parse as incoming request (has both ID and Method)
		var req JSONRPCIncomingRequest
		if err := json.Unmarshal(line, &req); err == nil && req.ID != nil && req.Method != "" {
			// It's an incoming request from ACP (has ID field)
			fmt.Fprintf(os.Stderr, "[ACP] 📥 Parsed as incoming request: method=%s, id=%d\n", req.Method, *req.ID)
			select {
			case c.requests <- &req:
				fmt.Fprintf(os.Stderr, "[ACP] ✅ Request sent to channel\n")
			default:
				// Channel full, drop request
				fmt.Fprintf(os.Stderr, "[ACP] ❌ Dropped request (channel full): %s\n", req.Method)
			}
			continue
		}

		// Try to parse as response (has ID, no Method)
		var resp JSONRPCResponse
		if err := json.Unmarshal(line, &resp); err == nil && resp.ID != 0 {
			// It's a response
			fmt.Fprintf(os.Stderr, "[ACP] ✅ Parsed as response ID=%d\n", resp.ID)
			c.mu.Lock()
			if respChan, ok := c.pendingCalls[resp.ID]; ok {
				respChan <- &resp
			}
			c.mu.Unlock()
			continue
		}

		// Try to parse as notification (no ID, has method)
		var notif JSONRPCNotification
		if err := json.Unmarshal(line, &notif); err == nil && notif.Method != "" {
			// It's a notification
			fmt.Fprintf(os.Stderr, "[ACP] 📨 Parsed as notification: method=%s\n", notif.Method)
			select {
			case c.notifications <- &notif:
				fmt.Fprintf(os.Stderr, "[ACP] ✅ Notification sent to channel\n")
			default:
				// Channel full, drop notification
				fmt.Fprintf(os.Stderr, "[ACP] ❌ Dropped notification (channel full): %s\n", notif.Method)
			}
			continue
		}

		// Unknown message format
		fmt.Fprintf(os.Stderr, "[ACP] ⚠️  Unknown message format\n")
	}

	fmt.Fprintf(os.Stderr, "[ACP] 🛑 Read loop exited (total lines: %d)\n", lineCount)

	if err := scanner.Err(); err != nil {
		fmt.Fprintf(os.Stderr, "[ACP] ❌ Read error: %v\n", err)
	}
}
