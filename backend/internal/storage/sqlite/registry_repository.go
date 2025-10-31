package sqlite

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/unforced/parachute-backend/internal/domain/registry"
)

// RegistryRepository implements the registry.Repository interface
type RegistryRepository struct {
	db *sql.DB
}

// NewRegistryRepository creates a new registry repository
func NewRegistryRepository(db *sql.DB) *RegistryRepository {
	return &RegistryRepository{db: db}
}

// AddSpace adds a new space to the registry
func (r *RegistryRepository) AddSpace(ctx context.Context, space *registry.Space) error {
	now := space.AddedAt.Unix()

	// Insert with both old schema (created_at, updated_at, user_id) and new schema (added_at, last_accessed, config)
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO spaces (id, user_id, name, path, created_at, updated_at, icon, color, added_at, last_accessed, config)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`, space.ID, "default", space.Name, space.Path, now, now, "", "", now,
		nullTimeToUnix(space.LastAccessed), space.Config)

	if err != nil {
		return fmt.Errorf("failed to add space: %w", err)
	}
	return nil
}

// GetSpaceByID retrieves a space by ID
func (r *RegistryRepository) GetSpaceByID(ctx context.Context, id string) (*registry.Space, error) {
	space := &registry.Space{}
	var addedAt, lastAccessed sql.NullInt64

	err := r.db.QueryRowContext(ctx, `
		SELECT id, path, name, added_at, last_accessed, config
		FROM spaces WHERE id = ?
	`, id).Scan(&space.ID, &space.Path, &space.Name, &addedAt, &lastAccessed, &space.Config)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("space not found: %s", id)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get space: %w", err)
	}

	space.AddedAt = time.Unix(addedAt.Int64, 0)
	if lastAccessed.Valid {
		space.LastAccessed = time.Unix(lastAccessed.Int64, 0)
	}

	return space, nil
}

// GetSpaceByPath retrieves a space by its path
func (r *RegistryRepository) GetSpaceByPath(ctx context.Context, path string) (*registry.Space, error) {
	space := &registry.Space{}
	var addedAt, lastAccessed sql.NullInt64

	err := r.db.QueryRowContext(ctx, `
		SELECT id, path, name, added_at, last_accessed, config
		FROM spaces WHERE path = ?
	`, path).Scan(&space.ID, &space.Path, &space.Name, &addedAt, &lastAccessed, &space.Config)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("space not found at path: %s", path)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get space: %w", err)
	}

	space.AddedAt = time.Unix(addedAt.Int64, 0)
	if lastAccessed.Valid {
		space.LastAccessed = time.Unix(lastAccessed.Int64, 0)
	}

	return space, nil
}

// ListSpaces retrieves all registered spaces
func (r *RegistryRepository) ListSpaces(ctx context.Context) ([]*registry.Space, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, path, name, added_at, last_accessed, config
		FROM spaces
		ORDER BY last_accessed DESC, added_at DESC
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to list spaces: %w", err)
	}
	defer rows.Close()

	spaces := make([]*registry.Space, 0)
	for rows.Next() {
		space := &registry.Space{}
		var addedAt, lastAccessed sql.NullInt64

		err := rows.Scan(&space.ID, &space.Path, &space.Name, &addedAt, &lastAccessed, &space.Config)
		if err != nil {
			return nil, fmt.Errorf("failed to scan space: %w", err)
		}

		space.AddedAt = time.Unix(addedAt.Int64, 0)
		if lastAccessed.Valid {
			space.LastAccessed = time.Unix(lastAccessed.Int64, 0)
		}

		spaces = append(spaces, space)
	}

	return spaces, nil
}

// UpdateSpaceAccess updates the last accessed time for a space
func (r *RegistryRepository) UpdateSpaceAccess(ctx context.Context, id string) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE spaces SET last_accessed = ? WHERE id = ?
	`, time.Now().Unix(), id)

	if err != nil {
		return fmt.Errorf("failed to update space access: %w", err)
	}
	return nil
}

// RemoveSpace removes a space from the registry (doesn't delete the folder)
func (r *RegistryRepository) RemoveSpace(ctx context.Context, id string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM spaces WHERE id = ?`, id)
	if err != nil {
		return fmt.Errorf("failed to remove space: %w", err)
	}
	return nil
}

// AddCapture adds a new capture to the registry
func (r *RegistryRepository) AddCapture(ctx context.Context, capture *registry.Capture) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO captures (id, base_name, title, created_at, has_audio, has_transcript, metadata)
		VALUES (?, ?, ?, ?, ?, ?, ?)
	`, capture.ID, capture.BaseName, capture.Title, capture.CreatedAt.Unix(),
		capture.HasAudio, capture.HasTranscript, capture.Metadata)

	if err != nil {
		return fmt.Errorf("failed to add capture: %w", err)
	}
	return nil
}

// GetCaptureByID retrieves a capture by ID
func (r *RegistryRepository) GetCaptureByID(ctx context.Context, id string) (*registry.Capture, error) {
	capture := &registry.Capture{}
	var createdAt int64

	err := r.db.QueryRowContext(ctx, `
		SELECT id, base_name, title, created_at, has_audio, has_transcript, metadata
		FROM captures WHERE id = ?
	`, id).Scan(&capture.ID, &capture.BaseName, &capture.Title, &createdAt,
		&capture.HasAudio, &capture.HasTranscript, &capture.Metadata)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("capture not found: %s", id)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get capture: %w", err)
	}

	capture.CreatedAt = time.Unix(createdAt, 0)
	return capture, nil
}

// GetCaptureByBaseName retrieves a capture by its base name
func (r *RegistryRepository) GetCaptureByBaseName(ctx context.Context, baseName string) (*registry.Capture, error) {
	capture := &registry.Capture{}
	var createdAt int64

	err := r.db.QueryRowContext(ctx, `
		SELECT id, base_name, title, created_at, has_audio, has_transcript, metadata
		FROM captures WHERE base_name = ?
	`, baseName).Scan(&capture.ID, &capture.BaseName, &capture.Title, &createdAt,
		&capture.HasAudio, &capture.HasTranscript, &capture.Metadata)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("capture not found: %s", baseName)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get capture: %w", err)
	}

	capture.CreatedAt = time.Unix(createdAt, 0)
	return capture, nil
}

// ListCaptures retrieves all captures
func (r *RegistryRepository) ListCaptures(ctx context.Context) ([]*registry.Capture, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id, base_name, title, created_at, has_audio, has_transcript, metadata
		FROM captures
		ORDER BY created_at DESC
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to list captures: %w", err)
	}
	defer rows.Close()

	captures := make([]*registry.Capture, 0)
	for rows.Next() {
		capture := &registry.Capture{}
		var createdAt int64

		err := rows.Scan(&capture.ID, &capture.BaseName, &capture.Title, &createdAt,
			&capture.HasAudio, &capture.HasTranscript, &capture.Metadata)
		if err != nil {
			return nil, fmt.Errorf("failed to scan capture: %w", err)
		}

		capture.CreatedAt = time.Unix(createdAt, 0)
		captures = append(captures, capture)
	}

	return captures, nil
}

// UpdateCapture updates a capture
func (r *RegistryRepository) UpdateCapture(ctx context.Context, capture *registry.Capture) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE captures
		SET base_name = ?, title = ?, has_audio = ?, has_transcript = ?, metadata = ?
		WHERE id = ?
	`, capture.BaseName, capture.Title, capture.HasAudio, capture.HasTranscript,
		capture.Metadata, capture.ID)

	if err != nil {
		return fmt.Errorf("failed to update capture: %w", err)
	}
	return nil
}

// DeleteCapture removes a capture from the registry
func (r *RegistryRepository) DeleteCapture(ctx context.Context, id string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM captures WHERE id = ?`, id)
	if err != nil {
		return fmt.Errorf("failed to delete capture: %w", err)
	}
	return nil
}

// GetSetting retrieves a setting by key
func (r *RegistryRepository) GetSetting(ctx context.Context, key string) (*registry.Setting, error) {
	setting := &registry.Setting{}

	err := r.db.QueryRowContext(ctx, `
		SELECT key, value FROM settings WHERE key = ?
	`, key).Scan(&setting.Key, &setting.Value)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("setting not found: %s", key)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get setting: %w", err)
	}

	return setting, nil
}

// SetSetting sets a setting value
func (r *RegistryRepository) SetSetting(ctx context.Context, key, value string) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO settings (key, value) VALUES (?, ?)
		ON CONFLICT(key) DO UPDATE SET value = excluded.value
	`, key, value)

	if err != nil {
		return fmt.Errorf("failed to set setting: %w", err)
	}
	return nil
}

// ListSettings retrieves all settings
func (r *RegistryRepository) ListSettings(ctx context.Context) ([]*registry.Setting, error) {
	rows, err := r.db.QueryContext(ctx, `SELECT key, value FROM settings ORDER BY key`)
	if err != nil {
		return nil, fmt.Errorf("failed to list settings: %w", err)
	}
	defer rows.Close()

	settings := make([]*registry.Setting, 0)
	for rows.Next() {
		setting := &registry.Setting{}
		if err := rows.Scan(&setting.Key, &setting.Value); err != nil {
			return nil, fmt.Errorf("failed to scan setting: %w", err)
		}
		settings = append(settings, setting)
	}

	return settings, nil
}

// nullTimeToUnix converts a time.Time to nullable Unix timestamp
func nullTimeToUnix(t time.Time) sql.NullInt64 {
	if t.IsZero() {
		return sql.NullInt64{Valid: false}
	}
	return sql.NullInt64{Int64: t.Unix(), Valid: true}
}
