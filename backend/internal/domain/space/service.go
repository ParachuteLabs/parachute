package space

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/unforced/parachute-backend/internal/domain"
)

// Service provides business logic for spaces
type Service struct {
	repo          Repository
	parachuteRoot string
}

// NewService creates a new space service
func NewService(repo Repository, parachuteRoot string) *Service {
	return &Service{
		repo:          repo,
		parachuteRoot: parachuteRoot,
	}
}

// sanitizeName converts a space name to a filesystem-safe name
// Example: "Work Project" -> "work-project"
func sanitizeName(name string) string {
	// Convert to lowercase
	s := strings.ToLower(name)

	// Replace spaces and underscores with hyphens
	s = strings.ReplaceAll(s, " ", "-")
	s = strings.ReplaceAll(s, "_", "-")

	// Remove any non-alphanumeric characters except hyphens
	reg := regexp.MustCompile("[^a-z0-9-]+")
	s = reg.ReplaceAllString(s, "")

	// Remove leading/trailing hyphens
	s = strings.Trim(s, "-")

	// Replace multiple consecutive hyphens with single hyphen
	reg = regexp.MustCompile("-+")
	s = reg.ReplaceAllString(s, "-")

	return s
}

// Create creates a new space with validation and auto-generated path
func (s *Service) Create(ctx context.Context, userID string, params CreateSpaceParams) (*Space, error) {
	// Validate name
	if params.Name == "" {
		return nil, domain.NewValidationError("name", "space name is required")
	}

	// Auto-generate path from name
	sanitized := sanitizeName(params.Name)
	if sanitized == "" {
		return nil, domain.NewValidationError("name", "space name contains no valid characters")
	}

	// Build absolute path: ~/Parachute/spaces/{sanitized-name}
	spacePath := filepath.Join(s.parachuteRoot, "spaces", sanitized)

	// Check if space already exists at this path
	existing, err := s.repo.GetByPath(ctx, spacePath)
	if err == nil && existing != nil {
		return nil, domain.NewConflictError("space", fmt.Sprintf("space already exists with name: %s", params.Name))
	}

	// Create the directory structure
	if err := os.MkdirAll(spacePath, 0755); err != nil {
		return nil, fmt.Errorf("failed to create space directory: %w", err)
	}

	// Create files/ subdirectory
	filesDir := filepath.Join(spacePath, "files")
	if err := os.MkdirAll(filesDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create files directory: %w", err)
	}

	// Create initial CLAUDE.md with template
	claudeMDPath := filepath.Join(spacePath, "CLAUDE.md")
	claudeMDTemplate := fmt.Sprintf(`# %s

This space is for organizing your conversations and files related to %s.

## Context
Add relevant context and information here to help Claude understand this space.

## Guidelines
- Keep conversations focused on topics related to this space
- Upload relevant files to the files/ directory
- Link to related recordings when needed

## Files
See the files/ directory for uploaded documents and resources.
`, params.Name, params.Name)

	if err := os.WriteFile(claudeMDPath, []byte(claudeMDTemplate), 0644); err != nil {
		return nil, fmt.Errorf("failed to create CLAUDE.md: %w", err)
	}

	// Create space record
	now := time.Now()
	space := &Space{
		ID:        uuid.New().String(),
		UserID:    userID,
		Name:      params.Name,
		Path:      spacePath,
		Icon:      params.Icon,
		Color:     params.Color,
		CreatedAt: now,
		UpdatedAt: now,
	}

	if err := s.repo.Create(ctx, space); err != nil {
		return nil, fmt.Errorf("failed to create space: %w", err)
	}

	return space, nil
}

// GetByID retrieves a space by ID
func (s *Service) GetByID(ctx context.Context, id string) (*Space, error) {
	space, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, domain.NewNotFoundError("space", id)
	}
	return space, nil
}

// List retrieves all spaces for a user
func (s *Service) List(ctx context.Context, userID string) ([]*Space, error) {
	return s.repo.List(ctx, userID)
}

// Update updates a space
func (s *Service) Update(ctx context.Context, id string, params UpdateSpaceParams) (*Space, error) {
	// Get existing space
	space, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}

	// Update fields
	if params.Name != "" {
		space.Name = params.Name
	}
	if params.Icon != "" {
		space.Icon = params.Icon
	}
	if params.Color != "" {
		space.Color = params.Color
	}

	// Save
	if err := s.repo.Update(ctx, space); err != nil {
		return nil, fmt.Errorf("failed to update space: %w", err)
	}

	return space, nil
}

// Delete deletes a space
func (s *Service) Delete(ctx context.Context, id string) error {
	return s.repo.Delete(ctx, id)
}

// GetClaudeMDPath returns the path to the CLAUDE.md file for a space
func (s *Service) GetClaudeMDPath(space *Space) string {
	return filepath.Join(space.Path, "CLAUDE.md")
}

// GetMCPConfigPath returns the path to the .mcp.json file for a space
func (s *Service) GetMCPConfigPath(space *Space) string {
	return filepath.Join(space.Path, ".mcp.json")
}

// ReadClaudeMD reads the CLAUDE.md file for a space
func (s *Service) ReadClaudeMD(space *Space) (string, error) {
	path := s.GetClaudeMDPath(space)

	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return "", nil // No CLAUDE.md file is okay
		}
		return "", fmt.Errorf("failed to read CLAUDE.md: %w", err)
	}

	return string(data), nil
}
