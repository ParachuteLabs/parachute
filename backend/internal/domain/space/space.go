package space

import (
	"time"
)

// Space represents a cognitive context with its own CLAUDE.md and files
type Space struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Name      string    `json:"name"`
	Path      string    `json:"path"` // Absolute path to directory
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// CreateSpaceParams represents parameters for creating a new space
type CreateSpaceParams struct {
	Name string `json:"name"`
	Path string `json:"path"`
}

// UpdateSpaceParams represents parameters for updating a space
type UpdateSpaceParams struct {
	Name string `json:"name,omitempty"`
}
