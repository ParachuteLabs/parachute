package space

import (
	"context"
)

// Repository defines the interface for space persistence
type Repository interface {
	// Create creates a new space
	Create(ctx context.Context, space *Space) error

	// GetByID retrieves a space by ID
	GetByID(ctx context.Context, id string) (*Space, error)

	// GetByPath retrieves a space by path
	GetByPath(ctx context.Context, path string) (*Space, error)

	// List retrieves all spaces for a user
	List(ctx context.Context, userID string) ([]*Space, error)

	// Update updates a space
	Update(ctx context.Context, space *Space) error

	// Delete deletes a space
	Delete(ctx context.Context, id string) error
}
