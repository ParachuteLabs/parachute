package registry

import (
	"context"
)

// Repository defines the interface for registry storage operations
type Repository interface {
	// Space operations
	AddSpace(ctx context.Context, space *Space) error
	GetSpaceByID(ctx context.Context, id string) (*Space, error)
	GetSpaceByPath(ctx context.Context, path string) (*Space, error)
	ListSpaces(ctx context.Context) ([]*Space, error)
	UpdateSpaceAccess(ctx context.Context, id string) error
	RemoveSpace(ctx context.Context, id string) error

	// Capture operations
	AddCapture(ctx context.Context, capture *Capture) error
	GetCaptureByID(ctx context.Context, id string) (*Capture, error)
	GetCaptureByBaseName(ctx context.Context, baseName string) (*Capture, error)
	ListCaptures(ctx context.Context) ([]*Capture, error)
	UpdateCapture(ctx context.Context, capture *Capture) error
	DeleteCapture(ctx context.Context, id string) error

	// Settings operations
	GetSetting(ctx context.Context, key string) (*Setting, error)
	SetSetting(ctx context.Context, key, value string) error
	ListSettings(ctx context.Context) ([]*Setting, error)
}
