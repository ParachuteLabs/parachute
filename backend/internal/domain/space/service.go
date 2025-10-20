package space

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/google/uuid"
)

// Service provides business logic for spaces
type Service struct {
	repo Repository
}

// NewService creates a new space service
func NewService(repo Repository) *Service {
	return &Service{repo: repo}
}

// Create creates a new space with validation
func (s *Service) Create(ctx context.Context, userID string, params CreateSpaceParams) (*Space, error) {
	// Validate name
	if params.Name == "" {
		return nil, fmt.Errorf("space name is required")
	}

	// Validate path
	if params.Path == "" {
		return nil, fmt.Errorf("space path is required")
	}

	// Ensure absolute path
	absPath, err := filepath.Abs(params.Path)
	if err != nil {
		return nil, fmt.Errorf("invalid path: %w", err)
	}

	// Check if directory exists
	info, err := os.Stat(absPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("directory does not exist: %s", absPath)
		}
		return nil, fmt.Errorf("failed to stat directory: %w", err)
	}

	if !info.IsDir() {
		return nil, fmt.Errorf("path is not a directory: %s", absPath)
	}

	// Check if space already exists at this path
	existing, err := s.repo.GetByPath(ctx, absPath)
	if err == nil && existing != nil {
		return nil, fmt.Errorf("space already exists at path: %s", absPath)
	}

	// Create space
	now := time.Now()
	space := &Space{
		ID:        uuid.New().String(),
		UserID:    userID,
		Name:      params.Name,
		Path:      absPath,
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
	return s.repo.GetByID(ctx, id)
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
