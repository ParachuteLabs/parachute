package handlers

import (
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestWebSocketHandler_Creation tests handler creation
func TestWebSocketHandler_Creation(t *testing.T) {
	handler := NewWebSocketHandler(nil)

	assert.NotNil(t, handler)
	assert.Nil(t, handler.acpClient)

	// Verify connections map is initialized (not nil)
	count := 0
	handler.connections.Range(func(key, value interface{}) bool {
		count++
		return true
	})
	assert.Equal(t, 0, count, "Should start with no connections")
}

// TestWSMessage_Serialization tests message JSON serialization
func TestWSMessage_Serialization(t *testing.T) {
	msg := WSMessage{
		Type: "test_type",
		Payload: map[string]interface{}{
			"key1": "value1",
			"key2": 123,
			"key3": true,
		},
	}

	// Serialize
	data, err := json.Marshal(msg)
	require.NoError(t, err)

	// Deserialize
	var decoded WSMessage
	err = json.Unmarshal(data, &decoded)
	require.NoError(t, err)

	assert.Equal(t, msg.Type, decoded.Type)
	assert.Equal(t, "value1", decoded.Payload["key1"])
	assert.Equal(t, float64(123), decoded.Payload["key2"]) // JSON numbers are float64
	assert.Equal(t, true, decoded.Payload["key3"])
}

// TestWSMessage_MessageChunk tests message_chunk format
func TestWSMessage_MessageChunk(t *testing.T) {
	msg := WSMessage{
		Type: "message_chunk",
		Payload: map[string]interface{}{
			"conversation_id": "conv-123",
			"chunk":           "Hello, world!",
		},
	}

	data, err := json.Marshal(msg)
	require.NoError(t, err)
	assert.NotEmpty(t, data)

	var result WSMessage
	require.NoError(t, json.Unmarshal(data, &result))

	assert.Equal(t, "message_chunk", result.Type)
	assert.Equal(t, "conv-123", result.Payload["conversation_id"])
	assert.Equal(t, "Hello, world!", result.Payload["chunk"])
}

// TestWSMessage_ToolCall tests tool_call format
func TestWSMessage_ToolCall(t *testing.T) {
	msg := WSMessage{
		Type: "tool_call",
		Payload: map[string]interface{}{
			"conversation_id": "conv-123",
			"tool_call_id":    "tool-1",
			"title":           "Searching web",
			"kind":            "fetch",
			"status":          "pending",
		},
	}

	data, err := json.Marshal(msg)
	require.NoError(t, err)

	var result WSMessage
	require.NoError(t, json.Unmarshal(data, &result))

	assert.Equal(t, "tool_call", result.Type)
	assert.Equal(t, "conv-123", result.Payload["conversation_id"])
	assert.Equal(t, "tool-1", result.Payload["tool_call_id"])
	assert.Equal(t, "Searching web", result.Payload["title"])
	assert.Equal(t, "fetch", result.Payload["kind"])
	assert.Equal(t, "pending", result.Payload["status"])
}

// TestWSMessage_Subscribe tests subscribe message format
func TestWSMessage_Subscribe(t *testing.T) {
	msg := WSMessage{
		Type: "subscribe",
		Payload: map[string]interface{}{
			"session_id": "test-session-123",
		},
	}

	data, err := json.Marshal(msg)
	require.NoError(t, err)

	var result WSMessage
	require.NoError(t, json.Unmarshal(data, &result))

	assert.Equal(t, "subscribe", result.Type)
	assert.Equal(t, "test-session-123", result.Payload["session_id"])
}

// TestWSMessage_Subscribed tests subscribed acknowledgment format
func TestWSMessage_Subscribed(t *testing.T) {
	msg := WSMessage{
		Type: "subscribed",
		Payload: map[string]interface{}{
			"session_id": "test-session-123",
		},
	}

	data, err := json.Marshal(msg)
	require.NoError(t, err)

	var result WSMessage
	require.NoError(t, json.Unmarshal(data, &result))

	assert.Equal(t, "subscribed", result.Type)
	assert.Equal(t, "test-session-123", result.Payload["session_id"])
}

// TestWSMessage_ToolCallUpdate tests tool_call_update format
func TestWSMessage_ToolCallUpdate(t *testing.T) {
	msg := WSMessage{
		Type: "tool_call_update",
		Payload: map[string]interface{}{
			"conversation_id": "conv-123",
			"tool_call_id":    "tool-1",
			"status":          "completed",
		},
	}

	data, err := json.Marshal(msg)
	require.NoError(t, err)

	var result WSMessage
	require.NoError(t, json.Unmarshal(data, &result))

	assert.Equal(t, "tool_call_update", result.Type)
	assert.Equal(t, "conv-123", result.Payload["conversation_id"])
	assert.Equal(t, "tool-1", result.Payload["tool_call_id"])
	assert.Equal(t, "completed", result.Payload["status"])
}

// TestWebSocketHandler_BroadcastToNoConnections tests broadcasting with no connections
func TestWebSocketHandler_BroadcastToNoConnections(t *testing.T) {
	handler := NewWebSocketHandler(nil)

	// Should not panic when broadcasting to no connections
	assert.NotPanics(t, func() {
		handler.BroadcastMessageChunk("conv-123", "test chunk")
	})

	assert.NotPanics(t, func() {
		handler.BroadcastToolCall("conv-123", "tool-1", "Test", "fetch", "pending")
	})

	assert.NotPanics(t, func() {
		handler.BroadcastToolCallUpdate("conv-123", "tool-1", "completed")
	})
}
