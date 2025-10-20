package handlers

import (
	"context"
	"fmt"
	"log"

	"github.com/gofiber/fiber/v3"
	"github.com/unforced/parachute-backend/internal/acp"
	"github.com/unforced/parachute-backend/internal/domain/conversation"
	"github.com/unforced/parachute-backend/internal/domain/space"
)

// MessageHandler handles message-related HTTP requests
type MessageHandler struct {
	conversationService *conversation.Service
	spaceService        *space.Service
	acpClient           *acp.ACPClient
}

// NewMessageHandler creates a new message handler
func NewMessageHandler(
	conversationService *conversation.Service,
	spaceService *space.Service,
	acpClient *acp.ACPClient,
) *MessageHandler {
	return &MessageHandler{
		conversationService: conversationService,
		spaceService:        spaceService,
		acpClient:           acpClient,
	}
}

// SendMessageRequest represents a request to send a message
type SendMessageRequest struct {
	ConversationID string `json:"conversation_id"`
	Content        string `json:"content"`
}

// SendMessage handles POST /api/messages
// This creates a user message and sends it to ACP
func (h *MessageHandler) SendMessage(c fiber.Ctx) error {
	ctx := c.Context()

	// Parse request
	var req SendMessageRequest
	if err := c.Bind().JSON(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	if req.ConversationID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "conversation_id is required",
		})
	}

	if req.Content == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "content is required",
		})
	}

	// Get conversation
	conv, err := h.conversationService.GetConversation(ctx, req.ConversationID)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"error": "Conversation not found",
		})
	}

	// Get space
	spaceObj, err := h.spaceService.GetByID(ctx, conv.SpaceID)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"error": "Space not found",
		})
	}

	// Create user message
	userMessage, err := h.conversationService.CreateMessage(ctx, conversation.CreateMessageParams{
		ConversationID: req.ConversationID,
		Role:           "user",
		Content:        req.Content,
	})
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to create message",
		})
	}

	// Get conversation history
	messages, err := h.conversationService.ListMessages(ctx, req.ConversationID)
	if err != nil {
		log.Printf("Failed to get message history: %v", err)
		messages = []*conversation.Message{} // Continue with empty history
	}

	// Build prompt with context and send to ACP if available
	if h.acpClient != nil {
		prompt := h.buildPromptWithContext(spaceObj, messages, req.Content)

		// TODO: Create or get ACP session for this conversation
		// For now, create a new session each time
		sessionID, err := h.acpClient.NewSession(spaceObj.Path, nil)
		if err != nil {
			log.Printf("Failed to create ACP session: %v", err)
			// Continue without ACP
		} else {
			// Send prompt to ACP (non-blocking)
			go h.handleACPResponse(sessionID, prompt, req.ConversationID)
		}
	}

	// Return user message immediately
	return c.Status(fiber.StatusCreated).JSON(userMessage)
}

// handleACPResponse handles the ACP response in a background goroutine
func (h *MessageHandler) handleACPResponse(sessionID, prompt, conversationID string) {
	ctx := context.Background()

	if h.acpClient == nil {
		return
	}

	if err := h.acpClient.SessionPrompt(sessionID, prompt); err != nil {
		log.Printf("Failed to send prompt to ACP: %v", err)
		return
	}

	// Listen for responses
	// TODO: This should be handled by WebSocket connection
	// For now, we'll collect the full response
	fullResponse := ""
	for notif := range h.acpClient.Notifications() {
		if notif.Method == "session/update" {
			update, err := acp.ParseSessionUpdate(notif)
			if err != nil {
				log.Printf("Failed to parse update: %v", err)
				continue
			}

			if update.SessionID != sessionID {
				continue // Not our session
			}

			// Extract text from update
			if updateType, ok := update.Update["type"].(string); ok {
				if updateType == "content_block_delta" {
					if delta, ok := update.Update["delta"].(map[string]interface{}); ok {
						if text, ok := delta["text"].(string); ok {
							fullResponse += text
						}
					}
				} else if updateType == "message_stop" {
					// Response complete
					break
				}
			}
		}
	}

	// Create assistant message
	if fullResponse != "" {
		_, err := h.conversationService.CreateMessage(ctx, conversation.CreateMessageParams{
			ConversationID: conversationID,
			Role:           "assistant",
			Content:        fullResponse,
		})
		if err != nil {
			log.Printf("Failed to save assistant message: %v", err)
		}
	}
}

// buildPromptWithContext builds a prompt including conversation history and CLAUDE.md
func (h *MessageHandler) buildPromptWithContext(
	spaceObj *space.Space,
	messages []*conversation.Message,
	currentPrompt string,
) string {
	prompt := ""

	// Include CLAUDE.md context if it exists
	claudeMD, err := h.spaceService.ReadClaudeMD(spaceObj)
	if err == nil && claudeMD != "" {
		prompt += "# Context from CLAUDE.md\n\n"
		prompt += claudeMD
		prompt += "\n\n---\n\n"
	}

	// Include conversation history (last 10 messages for now)
	if len(messages) > 0 {
		prompt += "# Conversation History\n\n"

		start := 0
		if len(messages) > 10 {
			start = len(messages) - 10
		}

		for _, msg := range messages[start:] {
			if msg.Role == "user" {
				prompt += fmt.Sprintf("User: %s\n\n", msg.Content)
			} else {
				prompt += fmt.Sprintf("Assistant: %s\n\n", msg.Content)
			}
		}

		prompt += "---\n\n"
	}

	// Current prompt
	prompt += currentPrompt

	return prompt
}

// ListMessages handles GET /api/messages?conversation_id=...
func (h *MessageHandler) ListMessages(c fiber.Ctx) error {
	ctx := c.Context()

	conversationID := c.Query("conversation_id")
	if conversationID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "conversation_id query parameter required",
		})
	}

	messages, err := h.conversationService.ListMessages(ctx, conversationID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to list messages",
		})
	}

	return c.JSON(fiber.Map{
		"messages": messages,
	})
}
