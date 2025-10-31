package registry

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/google/uuid"
)

// Service provides business logic for the registry
type Service struct {
	repo          Repository
	parachuteRoot string
}

// NewService creates a new registry service
func NewService(repo Repository, parachuteRoot string) *Service {
	return &Service{
		repo:          repo,
		parachuteRoot: parachuteRoot,
	}
}

// IsSpace checks if a directory is a valid space (has agents.md or CLAUDE.md)
func (s *Service) IsSpace(path string) bool {
	// Check for agents.md (new standard)
	if _, err := os.Stat(filepath.Join(path, "agents.md")); err == nil {
		return true
	}

	// Check for CLAUDE.md (legacy support)
	if _, err := os.Stat(filepath.Join(path, "CLAUDE.md")); err == nil {
		return true
	}

	return false
}

// AddSpace adds an existing directory as a space
func (s *Service) AddSpace(ctx context.Context, params AddSpaceParams) (*Space, error) {
	// Validate path exists
	if _, err := os.Stat(params.Path); os.IsNotExist(err) {
		return nil, fmt.Errorf("path does not exist: %s", params.Path)
	}

	// Validate it's a valid space
	if !s.IsSpace(params.Path) {
		return nil, fmt.Errorf("path is not a valid space (missing agents.md or CLAUDE.md): %s", params.Path)
	}

	// Check if already registered
	existing, err := s.repo.GetSpaceByPath(ctx, params.Path)
	if err == nil && existing != nil {
		return nil, fmt.Errorf("space already registered at path: %s", params.Path)
	}

	// Default name to folder name if not provided
	name := params.Name
	if name == "" {
		name = filepath.Base(params.Path)
	}

	// Create space record
	space := &Space{
		ID:      uuid.New().String(),
		Path:    params.Path,
		Name:    name,
		AddedAt: time.Now(),
		Config:  params.Config,
	}

	if err := s.repo.AddSpace(ctx, space); err != nil {
		return nil, fmt.Errorf("failed to add space: %w", err)
	}

	return space, nil
}

// CreateSpace creates a new space directory with agents.md
func (s *Service) CreateSpace(ctx context.Context, params CreateSpaceParams) (*Space, error) {
	// Validate name
	if params.Name == "" {
		return nil, fmt.Errorf("space name is required")
	}

	// Create directory
	if err := os.MkdirAll(params.Path, 0755); err != nil {
		return nil, fmt.Errorf("failed to create space directory: %w", err)
	}

	// Create files/ subdirectory
	filesDir := filepath.Join(params.Path, "files")
	if err := os.MkdirAll(filesDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create files directory: %w", err)
	}

	// Create agents.md with template
	agentsMDPath := filepath.Join(params.Path, "agents.md")
	agentsMDTemplate := fmt.Sprintf(`# %s

This space is for organizing conversations and knowledge related to %s.

## Context
Add relevant context here to help AI agents understand this space.

## Available Knowledge
- Linked notes will appear here as you connect recordings and notes to this space
- Use the space.sqlite database to track relationships and metadata

## Guidelines
- Keep conversations focused on topics related to this space
- Upload relevant files to the files/ directory
- Link recordings and notes to build your knowledge base

## Files
See the files/ directory for uploaded documents and resources.
`, params.Name, params.Name)

	if err := os.WriteFile(agentsMDPath, []byte(agentsMDTemplate), 0644); err != nil {
		return nil, fmt.Errorf("failed to create agents.md: %w", err)
	}

	// Add to registry
	return s.AddSpace(ctx, AddSpaceParams{
		Path:   params.Path,
		Name:   params.Name,
		Config: params.Config,
	})
}

// GetSpaceByID retrieves a space by ID
func (s *Service) GetSpaceByID(ctx context.Context, id string) (*Space, error) {
	return s.repo.GetSpaceByID(ctx, id)
}

// GetSpaceByPath retrieves a space by path
func (s *Service) GetSpaceByPath(ctx context.Context, path string) (*Space, error) {
	return s.repo.GetSpaceByPath(ctx, path)
}

// ListSpaces retrieves all registered spaces
func (s *Service) ListSpaces(ctx context.Context) ([]*Space, error) {
	return s.repo.ListSpaces(ctx)
}

// UpdateSpaceAccess updates the last accessed timestamp
func (s *Service) UpdateSpaceAccess(ctx context.Context, id string) error {
	return s.repo.UpdateSpaceAccess(ctx, id)
}

// RemoveSpace removes a space from the registry (doesn't delete folder)
func (s *Service) RemoveSpace(ctx context.Context, id string) error {
	return s.repo.RemoveSpace(ctx, id)
}

// AddCapture registers a new capture/note
func (s *Service) AddCapture(ctx context.Context, params AddCaptureParams) (*Capture, error) {
	// Validate base name
	if params.BaseName == "" {
		return nil, fmt.Errorf("base_name is required")
	}

	// Check if already exists
	existing, err := s.repo.GetCaptureByBaseName(ctx, params.BaseName)
	if err == nil && existing != nil {
		return existing, nil // Already registered, return existing
	}

	// Create capture record
	capture := &Capture{
		ID:            uuid.New().String(),
		BaseName:      params.BaseName,
		Title:         params.Title,
		CreatedAt:     time.Now(),
		HasAudio:      params.HasAudio,
		HasTranscript: params.HasTranscript,
		Metadata:      params.Metadata,
	}

	if err := s.repo.AddCapture(ctx, capture); err != nil {
		return nil, fmt.Errorf("failed to add capture: %w", err)
	}

	return capture, nil
}

// GetCaptureByID retrieves a capture by ID
func (s *Service) GetCaptureByID(ctx context.Context, id string) (*Capture, error) {
	return s.repo.GetCaptureByID(ctx, id)
}

// GetCaptureByBaseName retrieves a capture by base name
func (s *Service) GetCaptureByBaseName(ctx context.Context, baseName string) (*Capture, error) {
	return s.repo.GetCaptureByBaseName(ctx, baseName)
}

// ListCaptures retrieves all captures
func (s *Service) ListCaptures(ctx context.Context) ([]*Capture, error) {
	return s.repo.ListCaptures(ctx)
}

// UpdateCapture updates a capture
func (s *Service) UpdateCapture(ctx context.Context, capture *Capture) error {
	return s.repo.UpdateCapture(ctx, capture)
}

// DeleteCapture removes a capture from registry
func (s *Service) DeleteCapture(ctx context.Context, id string) error {
	return s.repo.DeleteCapture(ctx, id)
}

// GetSetting retrieves a setting
func (s *Service) GetSetting(ctx context.Context, key string) (string, error) {
	setting, err := s.repo.GetSetting(ctx, key)
	if err != nil {
		return "", err
	}
	return setting.Value, nil
}

// SetSetting sets a setting value
func (s *Service) SetSetting(ctx context.Context, key, value string) error {
	return s.repo.SetSetting(ctx, key, value)
}

// GetNotesFolder returns the notes folder path
func (s *Service) GetNotesFolder(ctx context.Context) string {
	folder, err := s.GetSetting(ctx, "notes_folder")
	if err != nil {
		folder = "notes" // Default
	}
	return filepath.Join(s.parachuteRoot, folder)
}

// GetSpacesFolder returns the spaces folder path
func (s *Service) GetSpacesFolder(ctx context.Context) string {
	folder, err := s.GetSetting(ctx, "spaces_folder")
	if err != nil {
		folder = "spaces" // Default
	}
	return filepath.Join(s.parachuteRoot, folder)
}
