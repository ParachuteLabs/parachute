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
}

// NewJSONRPCClient creates a new JSON-RPC client for the ACP process
func NewJSONRPCClient(process *ACPProcess) *JSONRPCClient {
	client := &JSONRPCClient{
		process:       process,
		pendingCalls:  make(map[int]chan *JSONRPCResponse),
		notifications: make(chan *JSONRPCNotification, 100),
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

// readLoop continuously reads from stdout and dispatches messages
func (c *JSONRPCClient) readLoop() {
	scanner := bufio.NewScanner(c.process.stdout)

	for scanner.Scan() {
		line := scanner.Bytes()

		// Try to parse as response first (has ID)
		var resp JSONRPCResponse
		if err := json.Unmarshal(line, &resp); err == nil && resp.ID != 0 {
			// It's a response
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
			select {
			case c.notifications <- &notif:
			default:
				// Channel full, drop notification
				fmt.Fprintf(os.Stderr, "[ACP] Dropped notification: %s\n", notif.Method)
			}
			continue
		}

		// Unknown message format
		fmt.Fprintf(os.Stderr, "[ACP] Unknown message: %s\n", string(line))
	}

	if err := scanner.Err(); err != nil {
		fmt.Fprintf(os.Stderr, "[ACP] Read error: %v\n", err)
	}
}
