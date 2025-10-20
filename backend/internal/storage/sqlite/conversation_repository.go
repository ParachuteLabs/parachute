package sqlite

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/unforced/parachute-backend/internal/domain/conversation"
)

// ConversationRepository implements the conversation.Repository interface
type ConversationRepository struct {
	db *sql.DB
}

// NewConversationRepository creates a new conversation repository
func NewConversationRepository(db *sql.DB) *ConversationRepository {
	return &ConversationRepository{db: db}
}

// CreateConversation creates a new conversation
func (r *ConversationRepository) CreateConversation(ctx context.Context, conv *conversation.Conversation) error {
	query := `
		INSERT INTO conversations (id, space_id, title, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?)
	`

	_, err := r.db.ExecContext(ctx, query,
		conv.ID,
		conv.SpaceID,
		conv.Title,
		conv.CreatedAt.Unix(),
		conv.UpdatedAt.Unix(),
	)

	if err != nil {
		return fmt.Errorf("failed to create conversation: %w", err)
	}

	return nil
}

// GetConversation retrieves a conversation by ID
func (r *ConversationRepository) GetConversation(ctx context.Context, id string) (*conversation.Conversation, error) {
	query := `
		SELECT id, space_id, title, created_at, updated_at
		FROM conversations
		WHERE id = ?
	`

	var conv conversation.Conversation
	var createdAt, updatedAt int64

	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&conv.ID,
		&conv.SpaceID,
		&conv.Title,
		&createdAt,
		&updatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("conversation not found: %s", id)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get conversation: %w", err)
	}

	conv.CreatedAt = time.Unix(createdAt, 0)
	conv.UpdatedAt = time.Unix(updatedAt, 0)

	return &conv, nil
}

// ListConversations retrieves all conversations for a space
func (r *ConversationRepository) ListConversations(ctx context.Context, spaceID string) ([]*conversation.Conversation, error) {
	query := `
		SELECT id, space_id, title, created_at, updated_at
		FROM conversations
		WHERE space_id = ?
		ORDER BY updated_at DESC
	`

	rows, err := r.db.QueryContext(ctx, query, spaceID)
	if err != nil {
		return nil, fmt.Errorf("failed to list conversations: %w", err)
	}
	defer rows.Close()

	var conversations []*conversation.Conversation

	for rows.Next() {
		var conv conversation.Conversation
		var createdAt, updatedAt int64

		err := rows.Scan(
			&conv.ID,
			&conv.SpaceID,
			&conv.Title,
			&createdAt,
			&updatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan conversation: %w", err)
		}

		conv.CreatedAt = time.Unix(createdAt, 0)
		conv.UpdatedAt = time.Unix(updatedAt, 0)

		conversations = append(conversations, &conv)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating conversations: %w", err)
	}

	return conversations, nil
}

// UpdateConversation updates a conversation
func (r *ConversationRepository) UpdateConversation(ctx context.Context, conv *conversation.Conversation) error {
	query := `
		UPDATE conversations
		SET title = ?, updated_at = ?
		WHERE id = ?
	`

	conv.UpdatedAt = time.Now()

	result, err := r.db.ExecContext(ctx, query,
		conv.Title,
		conv.UpdatedAt.Unix(),
		conv.ID,
	)

	if err != nil {
		return fmt.Errorf("failed to update conversation: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to check rows affected: %w", err)
	}

	if rows == 0 {
		return fmt.Errorf("conversation not found: %s", conv.ID)
	}

	return nil
}

// DeleteConversation deletes a conversation
func (r *ConversationRepository) DeleteConversation(ctx context.Context, id string) error {
	query := `DELETE FROM conversations WHERE id = ?`

	result, err := r.db.ExecContext(ctx, query, id)
	if err != nil {
		return fmt.Errorf("failed to delete conversation: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to check rows affected: %w", err)
	}

	if rows == 0 {
		return fmt.Errorf("conversation not found: %s", id)
	}

	return nil
}

// CreateMessage creates a new message
func (r *ConversationRepository) CreateMessage(ctx context.Context, msg *conversation.Message) error {
	query := `
		INSERT INTO messages (id, conversation_id, role, content, created_at, metadata)
		VALUES (?, ?, ?, ?, ?, ?)
	`

	_, err := r.db.ExecContext(ctx, query,
		msg.ID,
		msg.ConversationID,
		msg.Role,
		msg.Content,
		msg.CreatedAt.Unix(),
		msg.Metadata,
	)

	if err != nil {
		return fmt.Errorf("failed to create message: %w", err)
	}

	return nil
}

// GetMessage retrieves a message by ID
func (r *ConversationRepository) GetMessage(ctx context.Context, id string) (*conversation.Message, error) {
	query := `
		SELECT id, conversation_id, role, content, created_at, metadata
		FROM messages
		WHERE id = ?
	`

	var msg conversation.Message
	var createdAt int64
	var metadata sql.NullString

	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&msg.ID,
		&msg.ConversationID,
		&msg.Role,
		&msg.Content,
		&createdAt,
		&metadata,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("message not found: %s", id)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get message: %w", err)
	}

	msg.CreatedAt = time.Unix(createdAt, 0)
	if metadata.Valid {
		msg.Metadata = metadata.String
	}

	return &msg, nil
}

// ListMessages retrieves all messages for a conversation
func (r *ConversationRepository) ListMessages(ctx context.Context, conversationID string) ([]*conversation.Message, error) {
	query := `
		SELECT id, conversation_id, role, content, created_at, metadata
		FROM messages
		WHERE conversation_id = ?
		ORDER BY created_at ASC
	`

	rows, err := r.db.QueryContext(ctx, query, conversationID)
	if err != nil {
		return nil, fmt.Errorf("failed to list messages: %w", err)
	}
	defer rows.Close()

	var messages []*conversation.Message

	for rows.Next() {
		var msg conversation.Message
		var createdAt int64
		var metadata sql.NullString

		err := rows.Scan(
			&msg.ID,
			&msg.ConversationID,
			&msg.Role,
			&msg.Content,
			&createdAt,
			&metadata,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan message: %w", err)
		}

		msg.CreatedAt = time.Unix(createdAt, 0)
		if metadata.Valid {
			msg.Metadata = metadata.String
		}

		messages = append(messages, &msg)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating messages: %w", err)
	}

	return messages, nil
}

// DeleteMessage deletes a message
func (r *ConversationRepository) DeleteMessage(ctx context.Context, id string) error {
	query := `DELETE FROM messages WHERE id = ?`

	result, err := r.db.ExecContext(ctx, query, id)
	if err != nil {
		return fmt.Errorf("failed to delete message: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to check rows affected: %w", err)
	}

	if rows == 0 {
		return fmt.Errorf("message not found: %s", id)
	}

	return nil
}
