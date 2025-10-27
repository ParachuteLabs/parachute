package integration

import (
	"fmt"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/fasthttp/websocket"
	"github.com/gofiber/fiber/v3"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/unforced/parachute-backend/internal/acp"
	"github.com/unforced/parachute-backend/internal/api/handlers"
	"github.com/unforced/parachute-backend/internal/domain/conversation"
	"github.com/unforced/parachute-backend/internal/domain/space"
	"github.com/unforced/parachute-backend/internal/storage/sqlite"
)

// TestWebSocketMessageChunkBroadcast tests that message chunks are broadcast to connected clients
func TestWebSocketMessageChunkBroadcast(t *testing.T) {
	// Setup test server
	app, wsHandler, cleanup := setupTestServer(t)
	defer cleanup()

	// Start server
	server := httptest.NewServer(app)
	defer server.Close()

	// Connect WebSocket client
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws"
	client, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	require.NoError(t, err, "Failed to connect WebSocket")
	defer client.Close()

	// Subscribe to a conversation
	conversationID := "test-conversation-123"
	subscribeMsg := map[string]interface{}{
		"type": "subscribe",
		"payload": map[string]interface{}{
			"session_id": conversationID,
		},
	}
	err = client.WriteJSON(subscribeMsg)
	require.NoError(t, err, "Failed to send subscribe message")

	// Wait for subscription confirmation
	var response map[string]interface{}
	err = client.ReadJSON(&response)
	require.NoError(t, err, "Failed to read subscription response")
	assert.Equal(t, "subscribed", response["type"])

	// Broadcast a message chunk
	testChunk := "Hello, this is a test chunk!"
	wsHandler.BroadcastMessageChunk(conversationID, testChunk)

	// Read the broadcast message
	var broadcastMsg map[string]interface{}
	client.SetReadDeadline(time.Now().Add(2 * time.Second))
	err = client.ReadJSON(&broadcastMsg)
	require.NoError(t, err, "Failed to read broadcast message")

	// Verify message structure
	assert.Equal(t, "message_chunk", broadcastMsg["type"])
	payload, ok := broadcastMsg["payload"].(map[string]interface{})
	require.True(t, ok, "Payload should be a map")
	assert.Equal(t, conversationID, payload["conversation_id"])
	assert.Equal(t, testChunk, payload["chunk"])
}

// TestWebSocketToolCallBroadcast tests that tool calls are broadcast to connected clients
func TestWebSocketToolCallBroadcast(t *testing.T) {
	app, wsHandler, cleanup := setupTestServer(t)
	defer cleanup()

	server := httptest.NewServer(app)
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws"
	client, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	require.NoError(t, err)
	defer client.Close()

	conversationID := "test-conversation-456"
	subscribeMsg := map[string]interface{}{
		"type": "subscribe",
		"payload": map[string]interface{}{
			"session_id": conversationID,
		},
	}
	err = client.WriteJSON(subscribeMsg)
	require.NoError(t, err)

	// Read subscription confirmation
	var response map[string]interface{}
	client.ReadJSON(&response)

	// Broadcast a tool call
	toolCallID := "tool-123"
	title := "Search for information"
	kind := "fetch"
	status := "pending"
	wsHandler.BroadcastToolCall(conversationID, toolCallID, title, kind, status)

	// Read the broadcast
	var toolCallMsg map[string]interface{}
	client.SetReadDeadline(time.Now().Add(2 * time.Second))
	err = client.ReadJSON(&toolCallMsg)
	require.NoError(t, err, "Failed to read tool call broadcast")

	// Verify tool call structure
	assert.Equal(t, "tool_call", toolCallMsg["type"])
	payload, ok := toolCallMsg["payload"].(map[string]interface{})
	require.True(t, ok)
	assert.Equal(t, conversationID, payload["conversation_id"])
	assert.Equal(t, toolCallID, payload["tool_call_id"])
	assert.Equal(t, title, payload["title"])
	assert.Equal(t, kind, payload["kind"])
	assert.Equal(t, status, payload["status"])
}

// TestWebSocketToolCallUpdate tests tool call status updates
func TestWebSocketToolCallUpdate(t *testing.T) {
	app, wsHandler, cleanup := setupTestServer(t)
	defer cleanup()

	server := httptest.NewServer(app)
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws"
	client, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	require.NoError(t, err)
	defer client.Close()

	conversationID := "test-conversation-789"
	subscribeMsg := map[string]interface{}{
		"type": "subscribe",
		"payload": map[string]interface{}{
			"session_id": conversationID,
		},
	}
	client.WriteJSON(subscribeMsg)

	// Read subscription confirmation
	var response map[string]interface{}
	client.ReadJSON(&response)

	// Broadcast tool call update
	toolCallID := "tool-456"
	wsHandler.BroadcastToolCallUpdate(conversationID, toolCallID, "completed")

	// Read the update
	var updateMsg map[string]interface{}
	client.SetReadDeadline(time.Now().Add(2 * time.Second))
	err = client.ReadJSON(&updateMsg)
	require.NoError(t, err)

	// Verify update structure
	assert.Equal(t, "tool_call_update", updateMsg["type"])
	payload, ok := updateMsg["payload"].(map[string]interface{})
	require.True(t, ok)
	assert.Equal(t, conversationID, payload["conversation_id"])
	assert.Equal(t, toolCallID, payload["tool_call_id"])
	assert.Equal(t, "completed", payload["status"])
}

// TestMultipleWebSocketClients tests broadcasting to multiple connected clients
func TestMultipleWebSocketClients(t *testing.T) {
	app, wsHandler, cleanup := setupTestServer(t)
	defer cleanup()

	server := httptest.NewServer(app)
	defer server.Close()

	// Connect 3 clients
	clients := make([]*websocket.Conn, 3)
	for i := 0; i < 3; i++ {
		wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws"
		client, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
		require.NoError(t, err, fmt.Sprintf("Failed to connect client %d", i))
		clients[i] = client
		defer client.Close()

		// Subscribe each client
		conversationID := fmt.Sprintf("test-conversation-%d", i)
		subscribeMsg := map[string]interface{}{
			"type": "subscribe",
			"payload": map[string]interface{}{
				"session_id": conversationID,
			},
		}
		client.WriteJSON(subscribeMsg)

		// Read subscription confirmation
		var response map[string]interface{}
		client.ReadJSON(&response)
	}

	// Broadcast to all conversations
	for i := 0; i < 3; i++ {
		conversationID := fmt.Sprintf("test-conversation-%d", i)
		testChunk := fmt.Sprintf("Message for conversation %d", i)
		wsHandler.BroadcastMessageChunk(conversationID, testChunk)
	}

	// Verify each client receives its message
	for i, client := range clients {
		var msg map[string]interface{}
		client.SetReadDeadline(time.Now().Add(2 * time.Second))
		err := client.ReadJSON(&msg)
		require.NoError(t, err, fmt.Sprintf("Client %d failed to read message", i))

		payload, ok := msg["payload"].(map[string]interface{})
		require.True(t, ok)

		// Each client should receive the message for its conversation
		expectedChunk := fmt.Sprintf("Message for conversation %d", i)
		assert.Equal(t, expectedChunk, payload["chunk"])
	}
}

// TestWebSocketConversationFiltering tests that clients only receive messages for their conversation
func TestWebSocketConversationFiltering(t *testing.T) {
	app, wsHandler, cleanup := setupTestServer(t)
	defer cleanup()

	server := httptest.NewServer(app)
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws"
	client, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	require.NoError(t, err)
	defer client.Close()

	// Subscribe to conversation A
	conversationA := "conversation-a"
	subscribeMsg := map[string]interface{}{
		"type": "subscribe",
		"payload": map[string]interface{}{
			"session_id": conversationA,
		},
	}
	client.WriteJSON(subscribeMsg)

	// Read subscription confirmation
	var response map[string]interface{}
	client.ReadJSON(&response)

	// Broadcast to conversation B (different conversation)
	conversationB := "conversation-b"
	wsHandler.BroadcastMessageChunk(conversationB, "Message for B")

	// Broadcast to conversation A (our conversation)
	wsHandler.BroadcastMessageChunk(conversationA, "Message for A")

	// Client should only receive message for conversation A
	var msg map[string]interface{}
	client.SetReadDeadline(time.Now().Add(2 * time.Second))
	err = client.ReadJSON(&msg)
	require.NoError(t, err)

	payload, ok := msg["payload"].(map[string]interface{})
	require.True(t, ok)

	// Should receive message A, not message B
	assert.Equal(t, conversationA, payload["conversation_id"])
	assert.Equal(t, "Message for A", payload["chunk"])
}

// TestWebSocketReconnection tests handling of client disconnection and reconnection
func TestWebSocketReconnection(t *testing.T) {
	app, wsHandler, cleanup := setupTestServer(t)
	defer cleanup()

	server := httptest.NewServer(app)
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws"

	// Connect first time
	client1, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	require.NoError(t, err)

	conversationID := "test-reconnect"
	subscribeMsg := map[string]interface{}{
		"type": "subscribe",
		"payload": map[string]interface{}{
			"session_id": conversationID,
		},
	}
	client1.WriteJSON(subscribeMsg)

	var response map[string]interface{}
	client1.ReadJSON(&response)

	// Disconnect
	client1.Close()

	// Wait a bit
	time.Sleep(100 * time.Millisecond)

	// Reconnect
	client2, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	require.NoError(t, err)
	defer client2.Close()

	// Subscribe again
	client2.WriteJSON(subscribeMsg)
	client2.ReadJSON(&response)

	// Broadcast a message
	wsHandler.BroadcastMessageChunk(conversationID, "After reconnect")

	// Should receive the message
	var msg map[string]interface{}
	client2.SetReadDeadline(time.Now().Add(2 * time.Second))
	err = client2.ReadJSON(&msg)
	require.NoError(t, err)

	payload, ok := msg["payload"].(map[string]interface{})
	require.True(t, ok)
	assert.Equal(t, "After reconnect", payload["chunk"])
}

// setupTestServer creates a test Fiber app with WebSocket handler
func setupTestServer(t *testing.T) (*fiber.App, *handlers.WebSocketHandler, func()) {
	// Setup in-memory database
	db, err := sqlite.NewDatabase(":memory:")
	require.NoError(t, err)

	// Initialize services
	spaceRepo := sqlite.NewSpaceRepository(db.DB)
	conversationRepo := sqlite.NewConversationRepository(db.DB)
	spaceService := space.NewService(spaceRepo, "/tmp/parachute-test")
	conversationService := conversation.NewService(conversationRepo)

	// Create mock ACP client (nil for testing, or use a mock)
	var acpClient *acp.ACPClient = nil

	// Create handlers
	wsHandler := handlers.NewWebSocketHandler(acpClient)
	messageHandler := handlers.NewMessageHandler(conversationService, spaceService, acpClient, wsHandler)

	// Create Fiber app
	app := fiber.New()
	app.Get("/ws", wsHandler.HandleUpgrade())

	// Cleanup function
	cleanup := func() {
		db.Close()
	}

	return app, wsHandler, cleanup
}
