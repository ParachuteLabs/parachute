package conversation

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
)

// Service provides business logic for conversations and messages
type Service struct {
	repo Repository
}

// NewService creates a new conversation service
func NewService(repo Repository) *Service {
	return &Service{repo: repo}
}

// CreateConversation creates a new conversation
func (s *Service) CreateConversation(ctx context.Context, params CreateConversationParams) (*Conversation, error) {
	if params.SpaceID == "" {
		return nil, fmt.Errorf("space_id is required")
	}

	if params.Title == "" {
		params.Title = "New Conversation"
	}

	now := time.Now()
	conv := &Conversation{
		ID:        uuid.New().String(),
		SpaceID:   params.SpaceID,
		Title:     params.Title,
		CreatedAt: now,
		UpdatedAt: now,
	}

	if err := s.repo.CreateConversation(ctx, conv); err != nil {
		return nil, fmt.Errorf("failed to create conversation: %w", err)
	}

	return conv, nil
}

// GetConversation retrieves a conversation by ID
func (s *Service) GetConversation(ctx context.Context, id string) (*Conversation, error) {
	return s.repo.GetConversation(ctx, id)
}

// ListConversations retrieves all conversations for a space
func (s *Service) ListConversations(ctx context.Context, spaceID string) ([]*Conversation, error) {
	return s.repo.ListConversations(ctx, spaceID)
}

// UpdateConversation updates a conversation
func (s *Service) UpdateConversation(ctx context.Context, id string, title string) (*Conversation, error) {
	conv, err := s.repo.GetConversation(ctx, id)
	if err != nil {
		return nil, err
	}

	conv.Title = title

	if err := s.repo.UpdateConversation(ctx, conv); err != nil {
		return nil, fmt.Errorf("failed to update conversation: %w", err)
	}

	return conv, nil
}

// DeleteConversation deletes a conversation
func (s *Service) DeleteConversation(ctx context.Context, id string) error {
	return s.repo.DeleteConversation(ctx, id)
}

// CreateMessage creates a new message in a conversation
func (s *Service) CreateMessage(ctx context.Context, params CreateMessageParams) (*Message, error) {
	if params.ConversationID == "" {
		return nil, fmt.Errorf("conversation_id is required")
	}

	if params.Role == "" {
		return nil, fmt.Errorf("role is required")
	}

	if params.Role != "user" && params.Role != "assistant" {
		return nil, fmt.Errorf("role must be 'user' or 'assistant'")
	}

	if params.Content == "" {
		return nil, fmt.Errorf("content is required")
	}

	msg := &Message{
		ID:             uuid.New().String(),
		ConversationID: params.ConversationID,
		Role:           params.Role,
		Content:        params.Content,
		CreatedAt:      time.Now(),
		Metadata:       params.Metadata,
	}

	if err := s.repo.CreateMessage(ctx, msg); err != nil {
		return nil, fmt.Errorf("failed to create message: %w", err)
	}

	// Update conversation's updated_at timestamp
	conv, err := s.repo.GetConversation(ctx, params.ConversationID)
	if err == nil {
		conv.UpdatedAt = time.Now()
		s.repo.UpdateConversation(ctx, conv)
	}

	return msg, nil
}

// GetMessage retrieves a message by ID
func (s *Service) GetMessage(ctx context.Context, id string) (*Message, error) {
	return s.repo.GetMessage(ctx, id)
}

// ListMessages retrieves all messages for a conversation
func (s *Service) ListMessages(ctx context.Context, conversationID string) ([]*Message, error) {
	return s.repo.ListMessages(ctx, conversationID)
}

// DeleteMessage deletes a message
func (s *Service) DeleteMessage(ctx context.Context, id string) error {
	return s.repo.DeleteMessage(ctx, id)
}
