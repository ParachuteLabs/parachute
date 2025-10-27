package space

import (
	"time"
)

// Space represents a cognitive context with its own CLAUDE.md and files
type Space struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Name      string    `json:"name"`
	Path      string    `json:"path"`            // Absolute path to directory (auto-generated from name)
	Icon      string    `json:"icon,omitempty"`  // Emoji icon for the space
	Color     string    `json:"color,omitempty"` // Hex color code (e.g., "#2E7D32")
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// CreateSpaceParams represents parameters for creating a new space
type CreateSpaceParams struct {
	Name  string `json:"name"`
	Icon  string `json:"icon,omitempty"`
	Color string `json:"color,omitempty"`
}

// UpdateSpaceParams represents parameters for updating a space
type UpdateSpaceParams struct {
	Name  string `json:"name,omitempty"`
	Icon  string `json:"icon,omitempty"`
	Color string `json:"color,omitempty"`
}
