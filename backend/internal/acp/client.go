package acp

import (
	"encoding/json"
	"fmt"
)

// ACPClient provides high-level ACP protocol methods
type ACPClient struct {
	jsonrpc *JSONRPCClient
	process *ACPProcess
}

// NewACPClient creates a new ACP client with the given API key
func NewACPClient(apiKey string) (*ACPClient, error) {
	// Spawn ACP process
	process, err := SpawnACP(apiKey)
	if err != nil {
		return nil, fmt.Errorf("failed to spawn ACP: %w", err)
	}

	// Create JSON-RPC client
	jsonrpc := NewJSONRPCClient(process)

	return &ACPClient{
		jsonrpc: jsonrpc,
		process: process,
	}, nil
}

// Close shuts down the ACP client
func (c *ACPClient) Close() error {
	return c.process.Close()
}

// Kill forcefully terminates the ACP process
func (c *ACPClient) Kill() error {
	return c.process.Kill()
}

// Notifications returns a channel that receives ACP notifications
func (c *ACPClient) Notifications() <-chan *JSONRPCNotification {
	return c.jsonrpc.Notifications()
}

// InitializeParams represents parameters for the initialize method
type InitializeParams struct {
	ClientName    string `json:"client_name"`
	ClientVersion string `json:"client_version"`
}

// InitializeResult represents the result of initialize
type InitializeResult struct {
	ServerName    string `json:"server_name"`
	ServerVersion string `json:"server_version"`
}

// Initialize performs the ACP handshake
func (c *ACPClient) Initialize() (*InitializeResult, error) {
	params := InitializeParams{
		ClientName:    "Parachute",
		ClientVersion: "0.1.0",
	}

	result, err := c.jsonrpc.Call("initialize", params)
	if err != nil {
		return nil, fmt.Errorf("initialize failed: %w", err)
	}

	var initResult InitializeResult
	if err := json.Unmarshal(result, &initResult); err != nil {
		return nil, fmt.Errorf("failed to parse initialize result: %w", err)
	}

	return &initResult, nil
}

// MCPServer represents an MCP server configuration
type MCPServer struct {
	Name    string                 `json:"name"`
	Command string                 `json:"command"`
	Args    []string               `json:"args,omitempty"`
	Env     map[string]string      `json:"env,omitempty"`
	Config  map[string]interface{} `json:"config,omitempty"`
}

// NewSessionParams represents parameters for new_session
type NewSessionParams struct {
	WorkingDirectory string      `json:"working_directory"`
	MCPServers       []MCPServer `json:"mcp_servers,omitempty"`
}

// NewSessionResult represents the result of new_session
type NewSessionResult struct {
	SessionID string `json:"session_id"`
}

// NewSession creates a new ACP session
func (c *ACPClient) NewSession(workingDir string, mcpServers []MCPServer) (string, error) {
	params := NewSessionParams{
		WorkingDirectory: workingDir,
		MCPServers:       mcpServers,
	}

	result, err := c.jsonrpc.Call("new_session", params)
	if err != nil {
		return "", fmt.Errorf("new_session failed: %w", err)
	}

	var sessionResult NewSessionResult
	if err := json.Unmarshal(result, &sessionResult); err != nil {
		return "", fmt.Errorf("failed to parse new_session result: %w", err)
	}

	return sessionResult.SessionID, nil
}

// SessionPromptParams represents parameters for session/prompt
type SessionPromptParams struct {
	SessionID string `json:"session_id"`
	Prompt    string `json:"prompt"`
}

// SessionPrompt sends a prompt to an ACP session
// This method returns immediately - responses come via Notifications()
func (c *ACPClient) SessionPrompt(sessionID, prompt string) error {
	params := SessionPromptParams{
		SessionID: sessionID,
		Prompt:    prompt,
	}

	_, err := c.jsonrpc.Call("session/prompt", params)
	if err != nil {
		return fmt.Errorf("session/prompt failed: %w", err)
	}

	return nil
}

// SessionUpdate represents a session/update notification
type SessionUpdate struct {
	SessionID string                 `json:"session_id"`
	Update    map[string]interface{} `json:"update"`
}

// ParseSessionUpdate parses a session/update notification
func ParseSessionUpdate(notif *JSONRPCNotification) (*SessionUpdate, error) {
	if notif.Method != "session/update" {
		return nil, fmt.Errorf("not a session/update notification: %s", notif.Method)
	}

	var update SessionUpdate
	if err := json.Unmarshal(notif.Params, &update); err != nil {
		return nil, fmt.Errorf("failed to parse session/update: %w", err)
	}

	return &update, nil
}
