package handlers

import (
	"encoding/json"
	"log"
	"sync"

	"github.com/fasthttp/websocket"
	"github.com/gofiber/fiber/v3"
	"github.com/unforced/parachute-backend/internal/acp"
	"github.com/valyala/fasthttp"
)

var upgrader = websocket.FastHTTPUpgrader{
	CheckOrigin: func(ctx *fasthttp.RequestCtx) bool {
		// Allow all origins for development
		// TODO: Restrict this in production
		return true
	},
}

// WebSocketHandler manages WebSocket connections for real-time chat
type WebSocketHandler struct {
	acpClient   *acp.ACPClient
	connections sync.Map // map[string]*websocket.Conn - session_id -> conn
	mu          sync.Mutex
}

// NewWebSocketHandler creates a new WebSocket handler
func NewWebSocketHandler(acpClient *acp.ACPClient) *WebSocketHandler {
	handler := &WebSocketHandler{
		acpClient: acpClient,
	}

	// TODO: Refactor to use per-session notification channels instead of global channel
	// Currently disabled because it competes with the broadcaster for notifications
	// go handler.listenForACPNotifications()

	return handler
}

// WSMessage represents a WebSocket message
type WSMessage struct {
	Type    string                 `json:"type"`
	Payload map[string]interface{} `json:"payload"`
}

// HandleUpgrade checks if the request should be upgraded to WebSocket
func (h *WebSocketHandler) HandleUpgrade() fiber.Handler {
	return func(c fiber.Ctx) error {
		return upgrader.Upgrade(c.Context(), func(conn *websocket.Conn) {
			h.handleConnection(conn)
		})
	}
}

// handleConnection handles a WebSocket connection
func (h *WebSocketHandler) handleConnection(conn *websocket.Conn) {
	log.Printf("WebSocket connection established from %s", conn.RemoteAddr())

	sessionID := "" // Will be set when client sends session info

	defer func() {
		if sessionID != "" {
			h.connections.Delete(sessionID)
		}
		conn.Close()
		log.Printf("WebSocket connection closed")
	}()

	// Read messages from client
	for {
		messageType, msg, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsCloseError(err, websocket.CloseGoingAway, websocket.CloseNormalClosure) {
				log.Println("WebSocket closed normally")
			} else {
				log.Printf("WebSocket read error: %v", err)
			}
			break
		}

		if messageType == websocket.TextMessage {
			var wsMsg WSMessage
			if err := json.Unmarshal(msg, &wsMsg); err != nil {
				log.Printf("Failed to parse WebSocket message: %v", err)
				continue
			}

			h.handleClientMessage(conn, &wsMsg, &sessionID)
		}
	}
}

// handleClientMessage handles messages from the WebSocket client
func (h *WebSocketHandler) handleClientMessage(conn *websocket.Conn, msg *WSMessage, sessionID *string) {
	switch msg.Type {
	case "subscribe":
		// Client subscribes to ACP session updates
		if sid, ok := msg.Payload["session_id"].(string); ok {
			*sessionID = sid
			h.connections.Store(sid, conn)
			log.Printf("Client subscribed to session: %s", sid)

			// Send acknowledgment
			h.sendMessage(conn, WSMessage{
				Type: "subscribed",
				Payload: map[string]interface{}{
					"session_id": sid,
				},
			})
		}

	case "unsubscribe":
		if *sessionID != "" {
			h.connections.Delete(*sessionID)
			*sessionID = ""
			log.Println("Client unsubscribed")
		}

	default:
		log.Printf("Unknown WebSocket message type: %s", msg.Type)
	}
}

// listenForACPNotifications listens for ACP notifications and broadcasts to WebSocket clients
func (h *WebSocketHandler) listenForACPNotifications() {
	for notif := range h.acpClient.Notifications() {
		if notif.Method == "session/update" {
			update, err := acp.ParseSessionUpdate(notif)
			if err != nil {
				log.Printf("Failed to parse session/update: %v", err)
				continue
			}

			// Find connection for this session
			if conn, ok := h.connections.Load(update.SessionID); ok {
				if wsConn, ok := conn.(*websocket.Conn); ok {
					// Send update to client
					msg := WSMessage{
						Type: "session_update",
						Payload: map[string]interface{}{
							"session_id": update.SessionID,
							"update":     update.Update,
						},
					}

					if err := h.sendMessage(wsConn, msg); err != nil {
						log.Printf("Failed to send message to WebSocket client: %v", err)
						h.connections.Delete(update.SessionID)
					}
				}
			}
		}
	}
}

// sendMessage sends a message to a WebSocket connection
func (h *WebSocketHandler) sendMessage(conn *websocket.Conn, msg WSMessage) error {
	data, err := json.Marshal(msg)
	if err != nil {
		return err
	}

	h.mu.Lock()
	defer h.mu.Unlock()
	return conn.WriteMessage(websocket.TextMessage, data)
}

// BroadcastMessageChunk broadcasts a message chunk to all clients subscribed to a conversation
func (h *WebSocketHandler) BroadcastMessageChunk(conversationID, chunk string) {
	msg := WSMessage{
		Type: "message_chunk",
		Payload: map[string]interface{}{
			"conversation_id": conversationID,
			"chunk":           chunk,
		},
	}

	// Count connections
	connCount := 0
	h.connections.Range(func(key, value interface{}) bool {
		connCount++
		return true
	})

	log.Printf("💬 Broadcasting chunk to %d WebSocket connection(s)", connCount)

	// Send to all connections (they can filter by conversation_id on client side)
	sentCount := 0
	h.connections.Range(func(key, value interface{}) bool {
		if conn, ok := value.(*websocket.Conn); ok {
			if err := h.sendMessage(conn, msg); err != nil {
				log.Printf("❌ Failed to send chunk to WebSocket client: %v", err)
				// Remove dead connection
				if sessionID, ok := key.(string); ok {
					h.connections.Delete(sessionID)
				}
			} else {
				sentCount++
			}
		}
		return true // continue iteration
	})
	log.Printf("✅ Sent chunk to %d/%d connections", sentCount, connCount)
}

// BroadcastToolCall broadcasts a tool call event to all clients
func (h *WebSocketHandler) BroadcastToolCall(conversationID, toolCallID, title, kind, status string) {
	msg := WSMessage{
		Type: "tool_call",
		Payload: map[string]interface{}{
			"conversation_id": conversationID,
			"tool_call_id":    toolCallID,
			"title":           title,
			"kind":            kind,
			"status":          status,
		},
	}

	// Count connections
	connCount := 0
	h.connections.Range(func(key, value interface{}) bool {
		connCount++
		return true
	})

	log.Printf("🔧 Broadcasting tool call to %d WebSocket connection(s)", connCount)

	sentCount := 0
	h.connections.Range(func(key, value interface{}) bool {
		if conn, ok := value.(*websocket.Conn); ok {
			if err := h.sendMessage(conn, msg); err != nil {
				log.Printf("❌ Failed to send tool call to WebSocket client: %v", err)
				if sessionID, ok := key.(string); ok {
					h.connections.Delete(sessionID)
				}
			} else {
				sentCount++
			}
		}
		return true
	})
	log.Printf("✅ Sent tool call to %d/%d connections", sentCount, connCount)
}

// BroadcastToolCallUpdate broadcasts a tool call update event to all clients
func (h *WebSocketHandler) BroadcastToolCallUpdate(conversationID, toolCallID, status string) {
	msg := WSMessage{
		Type: "tool_call_update",
		Payload: map[string]interface{}{
			"conversation_id": conversationID,
			"tool_call_id":    toolCallID,
			"status":          status,
		},
	}

	h.connections.Range(func(key, value interface{}) bool {
		if conn, ok := value.(*websocket.Conn); ok {
			if err := h.sendMessage(conn, msg); err != nil {
				log.Printf("Failed to send tool call update to WebSocket client: %v", err)
				if sessionID, ok := key.(string); ok {
					h.connections.Delete(sessionID)
				}
			}
		}
		return true
	})
}
