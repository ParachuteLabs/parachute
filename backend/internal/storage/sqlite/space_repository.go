package sqlite

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/unforced/parachute-backend/internal/domain/space"
)

// SpaceRepository implements the space.Repository interface
type SpaceRepository struct {
	db *sql.DB
}

// NewSpaceRepository creates a new space repository
func NewSpaceRepository(db *sql.DB) *SpaceRepository {
	return &SpaceRepository{db: db}
}

// Create creates a new space
func (r *SpaceRepository) Create(ctx context.Context, s *space.Space) error {
	query := `
		INSERT INTO spaces (id, user_id, name, path, icon, color, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)
	`

	_, err := r.db.ExecContext(ctx, query,
		s.ID,
		s.UserID,
		s.Name,
		s.Path,
		s.Icon,
		s.Color,
		s.CreatedAt.Unix(),
		s.UpdatedAt.Unix(),
	)

	if err != nil {
		return fmt.Errorf("failed to create space: %w", err)
	}

	return nil
}

// GetByID retrieves a space by ID
func (r *SpaceRepository) GetByID(ctx context.Context, id string) (*space.Space, error) {
	query := `
		SELECT id, user_id, name, path, icon, color, created_at, updated_at
		FROM spaces
		WHERE id = ?
	`

	var s space.Space
	var createdAt, updatedAt int64

	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&s.ID,
		&s.UserID,
		&s.Name,
		&s.Path,
		&s.Icon,
		&s.Color,
		&createdAt,
		&updatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("space not found: %s", id)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get space: %w", err)
	}

	s.CreatedAt = time.Unix(createdAt, 0)
	s.UpdatedAt = time.Unix(updatedAt, 0)

	return &s, nil
}

// GetByPath retrieves a space by path
func (r *SpaceRepository) GetByPath(ctx context.Context, path string) (*space.Space, error) {
	query := `
		SELECT id, user_id, name, path, icon, color, created_at, updated_at
		FROM spaces
		WHERE path = ?
	`

	var s space.Space
	var createdAt, updatedAt int64

	err := r.db.QueryRowContext(ctx, query, path).Scan(
		&s.ID,
		&s.UserID,
		&s.Name,
		&s.Path,
		&s.Icon,
		&s.Color,
		&createdAt,
		&updatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("space not found at path: %s", path)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get space: %w", err)
	}

	s.CreatedAt = time.Unix(createdAt, 0)
	s.UpdatedAt = time.Unix(updatedAt, 0)

	return &s, nil
}

// List retrieves all spaces for a user
func (r *SpaceRepository) List(ctx context.Context, userID string) ([]*space.Space, error) {
	query := `
		SELECT id, user_id, name, path, icon, color, created_at, updated_at
		FROM spaces
		WHERE user_id = ?
		ORDER BY updated_at DESC
	`

	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to list spaces: %w", err)
	}
	defer rows.Close()

	var spaces []*space.Space

	for rows.Next() {
		var s space.Space
		var createdAt, updatedAt int64

		err := rows.Scan(
			&s.ID,
			&s.UserID,
			&s.Name,
			&s.Path,
			&s.Icon,
			&s.Color,
			&createdAt,
			&updatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan space: %w", err)
		}

		s.CreatedAt = time.Unix(createdAt, 0)
		s.UpdatedAt = time.Unix(updatedAt, 0)

		spaces = append(spaces, &s)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating spaces: %w", err)
	}

	return spaces, nil
}

// Update updates a space
func (r *SpaceRepository) Update(ctx context.Context, s *space.Space) error {
	query := `
		UPDATE spaces
		SET name = ?, icon = ?, color = ?, updated_at = ?
		WHERE id = ?
	`

	s.UpdatedAt = time.Now()

	result, err := r.db.ExecContext(ctx, query,
		s.Name,
		s.Icon,
		s.Color,
		s.UpdatedAt.Unix(),
		s.ID,
	)

	if err != nil {
		return fmt.Errorf("failed to update space: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to check rows affected: %w", err)
	}

	if rows == 0 {
		return fmt.Errorf("space not found: %s", s.ID)
	}

	return nil
}

// Delete deletes a space
func (r *SpaceRepository) Delete(ctx context.Context, id string) error {
	query := `DELETE FROM spaces WHERE id = ?`

	result, err := r.db.ExecContext(ctx, query, id)
	if err != nil {
		return fmt.Errorf("failed to delete space: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to check rows affected: %w", err)
	}

	if rows == 0 {
		return fmt.Errorf("space not found: %s", id)
	}

	return nil
}
