package space

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/google/uuid"
	_ "modernc.org/sqlite"
)

// SpaceDatabaseService manages space-specific SQLite databases
type SpaceDatabaseService struct {
	parachuteRoot string
}

// NewSpaceDatabaseService creates a new space database service
func NewSpaceDatabaseService(parachuteRoot string) *SpaceDatabaseService {
	return &SpaceDatabaseService{
		parachuteRoot: parachuteRoot,
	}
}

// MigrateAllSpaces initializes space.sqlite for all existing spaces
func (s *SpaceDatabaseService) MigrateAllSpaces(spaceRepo Repository) error {
	// Get all spaces from repository
	// Note: This requires context, so we'll need to be called with context
	// For now, we'll just scan the filesystem
	spacesDir := filepath.Join(s.parachuteRoot, "spaces")

	// Check if spaces directory exists
	if _, err := os.Stat(spacesDir); os.IsNotExist(err) {
		return nil // No spaces to migrate
	}

	entries, err := os.ReadDir(spacesDir)
	if err != nil {
		return fmt.Errorf("failed to read spaces directory: %w", err)
	}

	migrated := 0
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		spacePath := filepath.Join(spacesDir, entry.Name())
		dbPath := filepath.Join(spacePath, "space.sqlite")

		// Check if space.sqlite already exists
		if _, err := os.Stat(dbPath); err == nil {
			continue // Already migrated
		}

		// Initialize database for this space
		// We'll use a placeholder UUID for migration
		spaceID := uuid.New().String()
		if err := s.InitializeSpaceDatabase(spaceID, spacePath); err != nil {
			return fmt.Errorf("failed to migrate space %s: %w", entry.Name(), err)
		}

		migrated++
	}

	if migrated > 0 {
		fmt.Printf("Migrated %d spaces to space.sqlite\n", migrated)
	}

	return nil
}

// RelevantNote represents a note linked to a space
type RelevantNote struct {
	ID             string                 `json:"id"`
	CaptureID      string                 `json:"capture_id"`
	NotePath       string                 `json:"note_path"`
	LinkedAt       time.Time              `json:"linked_at"`
	Context        string                 `json:"context"`
	Tags           []string               `json:"tags"`
	LastReferenced *time.Time             `json:"last_referenced,omitempty"`
	Metadata       map[string]interface{} `json:"metadata,omitempty"`
}

// NoteFilters for querying relevant notes (exported for use in handlers)
type NoteFilters struct {
	Tags      []string
	StartDate *time.Time
	EndDate   *time.Time
	Limit     int
	Offset    int
}

// InitializeSpaceDatabase creates or updates space.sqlite for a space
func (s *SpaceDatabaseService) InitializeSpaceDatabase(spaceID, spacePath string) error {
	dbPath := filepath.Join(spacePath, "space.sqlite")

	// Create space directory if it doesn't exist
	if err := os.MkdirAll(spacePath, 0755); err != nil {
		return fmt.Errorf("failed to create space directory: %w", err)
	}

	// Open/create database
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return fmt.Errorf("failed to open space database: %w", err)
	}
	defer db.Close()

	// Enable foreign keys
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		return fmt.Errorf("failed to enable foreign keys: %w", err)
	}

	// Create schema
	schema := `
	CREATE TABLE IF NOT EXISTS space_metadata (
		key TEXT PRIMARY KEY,
		value TEXT NOT NULL
	);

	CREATE TABLE IF NOT EXISTS relevant_notes (
		id TEXT PRIMARY KEY,
		capture_id TEXT NOT NULL,
		note_path TEXT NOT NULL,
		linked_at INTEGER NOT NULL,
		context TEXT,
		tags TEXT,
		last_referenced INTEGER,
		metadata TEXT,
		UNIQUE(capture_id)
	);

	CREATE INDEX IF NOT EXISTS idx_relevant_notes_tags ON relevant_notes(tags);
	CREATE INDEX IF NOT EXISTS idx_relevant_notes_last_ref ON relevant_notes(last_referenced);
	CREATE INDEX IF NOT EXISTS idx_relevant_notes_linked_at ON relevant_notes(linked_at DESC);
	`

	if _, err := db.Exec(schema); err != nil {
		return fmt.Errorf("failed to create schema: %w", err)
	}

	// Insert/update metadata
	now := time.Now().Unix()

	// Check if space_id already exists
	var existingSpaceID string
	err = db.QueryRow("SELECT value FROM space_metadata WHERE key = 'space_id'").Scan(&existingSpaceID)
	if err == sql.ErrNoRows {
		// First time initialization
		_, err = db.Exec(`
			INSERT INTO space_metadata (key, value) VALUES
				('schema_version', '1'),
				('space_id', ?),
				('created_at', ?)
		`, spaceID, now)
		if err != nil {
			return fmt.Errorf("failed to insert metadata: %w", err)
		}
	} else if err != nil {
		return fmt.Errorf("failed to check metadata: %w", err)
	}
	// If space_id exists, we don't update it (preserve existing metadata)

	return nil
}

// LinkNote adds a capture to a space's relevant_notes
func (s *SpaceDatabaseService) LinkNote(spaceID, spacePath, captureID, notePath, context string, tags []string) error {
	dbPath := filepath.Join(spacePath, "space.sqlite")

	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return fmt.Errorf("failed to open space database: %w", err)
	}
	defer db.Close()

	// Marshal tags to JSON
	tagsJSON, err := json.Marshal(tags)
	if err != nil {
		return fmt.Errorf("failed to marshal tags: %w", err)
	}

	// Insert note link
	id := uuid.New().String()
	now := time.Now().Unix()

	_, err = db.Exec(`
		INSERT INTO relevant_notes (id, capture_id, note_path, linked_at, context, tags)
		VALUES (?, ?, ?, ?, ?, ?)
		ON CONFLICT(capture_id) DO UPDATE SET
			context = excluded.context,
			tags = excluded.tags
	`, id, captureID, notePath, now, context, string(tagsJSON))

	if err != nil {
		return fmt.Errorf("failed to link note: %w", err)
	}

	return nil
}

// GetRelevantNotes queries linked notes for a space
func (s *SpaceDatabaseService) GetRelevantNotes(spacePath string, filters NoteFilters) ([]RelevantNote, error) {
	dbPath := filepath.Join(spacePath, "space.sqlite")

	// Check if database exists
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		return []RelevantNote{}, nil // Return empty list if no database yet
	}

	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open space database: %w", err)
	}
	defer db.Close()

	// Build query
	query := "SELECT id, capture_id, note_path, linked_at, context, tags, last_referenced, metadata FROM relevant_notes WHERE 1=1"
	args := []interface{}{}

	// Add filters
	if len(filters.Tags) > 0 {
		// Simple tag filtering (contains any of the tags)
		// Note: For production, consider full-text search or JSON operators
		for _, tag := range filters.Tags {
			query += " AND tags LIKE ?"
			args = append(args, "%\""+tag+"\"%")
		}
	}

	if filters.StartDate != nil {
		query += " AND linked_at >= ?"
		args = append(args, filters.StartDate.Unix())
	}

	if filters.EndDate != nil {
		query += " AND linked_at <= ?"
		args = append(args, filters.EndDate.Unix())
	}

	// Order by most recently linked
	query += " ORDER BY linked_at DESC"

	// Pagination
	if filters.Limit > 0 {
		query += " LIMIT ?"
		args = append(args, filters.Limit)
	}
	if filters.Offset > 0 {
		query += " OFFSET ?"
		args = append(args, filters.Offset)
	}

	rows, err := db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query notes: %w", err)
	}
	defer rows.Close()

	notes := []RelevantNote{}
	for rows.Next() {
		var note RelevantNote
		var linkedAtUnix int64
		var lastRefUnix sql.NullInt64
		var tagsJSON, metadataJSON sql.NullString

		err := rows.Scan(
			&note.ID,
			&note.CaptureID,
			&note.NotePath,
			&linkedAtUnix,
			&note.Context,
			&tagsJSON,
			&lastRefUnix,
			&metadataJSON,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan note: %w", err)
		}

		note.LinkedAt = time.Unix(linkedAtUnix, 0)

		if lastRefUnix.Valid {
			lastRef := time.Unix(lastRefUnix.Int64, 0)
			note.LastReferenced = &lastRef
		}

		if tagsJSON.Valid {
			if err := json.Unmarshal([]byte(tagsJSON.String), &note.Tags); err != nil {
				note.Tags = []string{}
			}
		}

		if metadataJSON.Valid && metadataJSON.String != "" {
			if err := json.Unmarshal([]byte(metadataJSON.String), &note.Metadata); err != nil {
				note.Metadata = map[string]interface{}{}
			}
		}

		notes = append(notes, note)
	}

	return notes, nil
}

// UpdateNoteContext updates the space-specific context and/or tags for a note
func (s *SpaceDatabaseService) UpdateNoteContext(spacePath, captureID string, context *string, tags *[]string) error {
	dbPath := filepath.Join(spacePath, "space.sqlite")

	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return fmt.Errorf("failed to open space database: %w", err)
	}
	defer db.Close()

	// Build update query dynamically
	updates := []string{}
	args := []interface{}{}

	if context != nil {
		updates = append(updates, "context = ?")
		args = append(args, *context)
	}

	if tags != nil {
		tagsJSON, err := json.Marshal(*tags)
		if err != nil {
			return fmt.Errorf("failed to marshal tags: %w", err)
		}
		updates = append(updates, "tags = ?")
		args = append(args, string(tagsJSON))
	}

	if len(updates) == 0 {
		return nil // Nothing to update
	}

	query := fmt.Sprintf("UPDATE relevant_notes SET %s WHERE capture_id = ?",
		joinStrings(updates, ", "))
	args = append(args, captureID)

	result, err := db.Exec(query, args...)
	if err != nil {
		return fmt.Errorf("failed to update note context: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("note not found in space")
	}

	return nil
}

// UnlinkNote removes a note from a space's relevant_notes
func (s *SpaceDatabaseService) UnlinkNote(spacePath, captureID string) error {
	dbPath := filepath.Join(spacePath, "space.sqlite")

	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return fmt.Errorf("failed to open space database: %w", err)
	}
	defer db.Close()

	result, err := db.Exec("DELETE FROM relevant_notes WHERE capture_id = ?", captureID)
	if err != nil {
		return fmt.Errorf("failed to unlink note: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("note not found in space")
	}

	return nil
}

// TrackNoteReference updates the last_referenced timestamp for a note
func (s *SpaceDatabaseService) TrackNoteReference(spacePath, captureID string) error {
	dbPath := filepath.Join(spacePath, "space.sqlite")

	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return fmt.Errorf("failed to open space database: %w", err)
	}
	defer db.Close()

	now := time.Now().Unix()
	_, err = db.Exec("UPDATE relevant_notes SET last_referenced = ? WHERE capture_id = ?", now, captureID)
	if err != nil {
		return fmt.Errorf("failed to track note reference: %w", err)
	}

	return nil
}

// GetNoteByID retrieves a specific note from a space
func (s *SpaceDatabaseService) GetNoteByID(spacePath, captureID string) (*RelevantNote, error) {
	dbPath := filepath.Join(spacePath, "space.sqlite")

	// Check if database exists
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		return nil, fmt.Errorf("space database not found")
	}

	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open space database: %w", err)
	}
	defer db.Close()

	var note RelevantNote
	var linkedAtUnix int64
	var lastRefUnix sql.NullInt64
	var tagsJSON, metadataJSON sql.NullString

	err = db.QueryRow(`
		SELECT id, capture_id, note_path, linked_at, context, tags, last_referenced, metadata
		FROM relevant_notes WHERE capture_id = ?
	`, captureID).Scan(
		&note.ID,
		&note.CaptureID,
		&note.NotePath,
		&linkedAtUnix,
		&note.Context,
		&tagsJSON,
		&lastRefUnix,
		&metadataJSON,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("note not found in space")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to query note: %w", err)
	}

	note.LinkedAt = time.Unix(linkedAtUnix, 0)

	if lastRefUnix.Valid {
		lastRef := time.Unix(lastRefUnix.Int64, 0)
		note.LastReferenced = &lastRef
	}

	if tagsJSON.Valid {
		if err := json.Unmarshal([]byte(tagsJSON.String), &note.Tags); err != nil {
			note.Tags = []string{}
		}
	}

	if metadataJSON.Valid && metadataJSON.String != "" {
		if err := json.Unmarshal([]byte(metadataJSON.String), &note.Metadata); err != nil {
			note.Metadata = map[string]interface{}{}
		}
	}

	return &note, nil
}

// Helper function to join strings
func joinStrings(strs []string, sep string) string {
	if len(strs) == 0 {
		return ""
	}
	result := strs[0]
	for i := 1; i < len(strs); i++ {
		result += sep + strs[i]
	}
	return result
}

// SpaceDatabaseStats represents statistics about a space database
type SpaceDatabaseStats struct {
	SchemaVersion string            `json:"schema_version"`
	SpaceID       string            `json:"space_id"`
	CreatedAt     int64             `json:"created_at"`
	TotalNotes    int               `json:"total_notes"`
	AllTags       []string          `json:"all_tags"`
	RecentNotes   []RelevantNote    `json:"recent_notes"`
	Metadata      map[string]string `json:"metadata"`
	Tables        []string          `json:"tables"`
}

// GetDatabaseStats retrieves comprehensive statistics about a space database
func (s *SpaceDatabaseService) GetDatabaseStats(spacePath string) (*SpaceDatabaseStats, error) {
	dbPath := filepath.Join(spacePath, "space.sqlite")

	// Check if database exists
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		return nil, fmt.Errorf("space database not found")
	}

	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open space database: %w", err)
	}
	defer db.Close()

	stats := &SpaceDatabaseStats{
		Metadata: make(map[string]string),
	}

	// Get all metadata
	metaRows, err := db.Query("SELECT key, value FROM space_metadata")
	if err == nil {
		defer metaRows.Close()
		for metaRows.Next() {
			var key, value string
			if err := metaRows.Scan(&key, &value); err == nil {
				stats.Metadata[key] = value
				// Also populate specific fields
				switch key {
				case "schema_version":
					stats.SchemaVersion = value
				case "space_id":
					stats.SpaceID = value
				case "created_at":
					var createdAt int64
					fmt.Sscanf(value, "%d", &createdAt)
					stats.CreatedAt = createdAt
				}
			}
		}
	}

	// Get total notes count
	err = db.QueryRow("SELECT COUNT(*) FROM relevant_notes").Scan(&stats.TotalNotes)
	if err != nil {
		stats.TotalNotes = 0
	}

	// Get all unique tags
	tagMap := make(map[string]bool)
	tagRows, err := db.Query("SELECT tags FROM relevant_notes WHERE tags IS NOT NULL")
	if err == nil {
		defer tagRows.Close()
		for tagRows.Next() {
			var tagsJSON string
			if err := tagRows.Scan(&tagsJSON); err == nil {
				var tags []string
				if err := json.Unmarshal([]byte(tagsJSON), &tags); err == nil {
					for _, tag := range tags {
						tagMap[tag] = true
					}
				}
			}
		}
	}

	for tag := range tagMap {
		stats.AllTags = append(stats.AllTags, tag)
	}

	// Get recent notes (last 10)
	notes, err := s.GetRelevantNotes(spacePath, NoteFilters{Limit: 10})
	if err == nil {
		stats.RecentNotes = notes
	}

	// Get all table names
	tableRows, err := db.Query("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
	if err == nil {
		defer tableRows.Close()
		for tableRows.Next() {
			var tableName string
			if err := tableRows.Scan(&tableName); err == nil {
				stats.Tables = append(stats.Tables, tableName)
			}
		}
	}

	return stats, nil
}

// TableRow represents a row of data from a database table
type TableRow map[string]interface{}

// TableQueryResult represents the result of querying a table
type TableQueryResult struct {
	TableName string     `json:"table_name"`
	Columns   []string   `json:"columns"`
	Rows      []TableRow `json:"rows"`
	RowCount  int        `json:"row_count"`
}

// QueryTable retrieves all rows from a specific table in a space database
func (s *SpaceDatabaseService) QueryTable(spacePath, tableName string) (*TableQueryResult, error) {
	dbPath := filepath.Join(spacePath, "space.sqlite")

	// Check if database exists
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		return nil, fmt.Errorf("space database not found")
	}

	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open space database: %w", err)
	}
	defer db.Close()

	// Validate table name to prevent SQL injection
	// Only allow alphanumeric and underscore
	validTableName := true
	for _, char := range tableName {
		if !((char >= 'a' && char <= 'z') || (char >= 'A' && char <= 'Z') ||
			(char >= '0' && char <= '9') || char == '_') {
			validTableName = false
			break
		}
	}
	if !validTableName {
		return nil, fmt.Errorf("invalid table name")
	}

	// Verify table exists
	var exists int
	err = db.QueryRow("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?", tableName).Scan(&exists)
	if err != nil || exists == 0 {
		return nil, fmt.Errorf("table not found: %s", tableName)
	}

	result := &TableQueryResult{
		TableName: tableName,
		Rows:      []TableRow{},
	}

	// Get column information
	rows, err := db.Query(fmt.Sprintf("PRAGMA table_info(%s)", tableName))
	if err != nil {
		return nil, fmt.Errorf("failed to get table info: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var cid int
		var name, colType string
		var notNull, dfltValue, pk interface{}
		if err := rows.Scan(&cid, &name, &colType, &notNull, &dfltValue, &pk); err != nil {
			continue
		}
		result.Columns = append(result.Columns, name)
	}

	// Query all rows from the table
	dataRows, err := db.Query(fmt.Sprintf("SELECT * FROM %s", tableName))
	if err != nil {
		return nil, fmt.Errorf("failed to query table: %w", err)
	}
	defer dataRows.Close()

	// Get column types for proper scanning
	columnTypes, err := dataRows.ColumnTypes()
	if err != nil {
		return nil, fmt.Errorf("failed to get column types: %w", err)
	}

	for dataRows.Next() {
		// Create slice of interface{} to hold row values
		values := make([]interface{}, len(result.Columns))
		valuePtrs := make([]interface{}, len(result.Columns))
		for i := range values {
			valuePtrs[i] = &values[i]
		}

		if err := dataRows.Scan(valuePtrs...); err != nil {
			continue
		}

		// Convert to map
		row := make(TableRow)
		for i, col := range result.Columns {
			val := values[i]

			// Convert []byte to string for readability
			if b, ok := val.([]byte); ok {
				row[col] = string(b)
			} else {
				// Handle NULL values
				if val == nil {
					row[col] = nil
				} else {
					row[col] = val
				}
			}

			// Check if column type suggests JSON
			colType := columnTypes[i].DatabaseTypeName()
			if colType == "TEXT" && val != nil {
				if str, ok := row[col].(string); ok {
					// Try to parse as JSON for pretty display
					if len(str) > 0 && (str[0] == '[' || str[0] == '{') {
						var jsonData interface{}
						if err := json.Unmarshal([]byte(str), &jsonData); err == nil {
							row[col] = jsonData
						}
					}
				}
			}
		}

		result.Rows = append(result.Rows, row)
	}

	result.RowCount = len(result.Rows)
	return result, nil
}
