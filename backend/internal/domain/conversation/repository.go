package conversation

import (
	"context"
)

// Repository defines the interface for conversation and message persistence
type Repository interface {
	// Conversation methods
	CreateConversation(ctx context.Context, conv *Conversation) error
	GetConversation(ctx context.Context, id string) (*Conversation, error)
	ListConversations(ctx context.Context, spaceID string) ([]*Conversation, error)
	UpdateConversation(ctx context.Context, conv *Conversation) error
	DeleteConversation(ctx context.Context, id string) error

	// Message methods
	CreateMessage(ctx context.Context, msg *Message) error
	GetMessage(ctx context.Context, id string) (*Message, error)
	ListMessages(ctx context.Context, conversationID string) ([]*Message, error)
	DeleteMessage(ctx context.Context, id string) error
}
