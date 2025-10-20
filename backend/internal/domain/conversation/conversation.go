package conversation

import (
	"time"
)

// Conversation represents a chat conversation within a space
type Conversation struct {
	ID        string    `json:"id"`
	SpaceID   string    `json:"space_id"`
	Title     string    `json:"title"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// Message represents a single message in a conversation
type Message struct {
	ID             string    `json:"id"`
	ConversationID string    `json:"conversation_id"`
	Role           string    `json:"role"` // "user" or "assistant"
	Content        string    `json:"content"`
	CreatedAt      time.Time `json:"created_at"`
	Metadata       string    `json:"metadata,omitempty"` // JSON metadata
}

// CreateConversationParams represents parameters for creating a conversation
type CreateConversationParams struct {
	SpaceID string `json:"space_id"`
	Title   string `json:"title"`
}

// CreateMessageParams represents parameters for creating a message
type CreateMessageParams struct {
	ConversationID string `json:"conversation_id"`
	Role           string `json:"role"`
	Content        string `json:"content"`
	Metadata       string `json:"metadata,omitempty"`
}
