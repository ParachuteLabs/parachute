package sqlite

import (
	"database/sql"
	"fmt"
)

// Migration represents a database migration
type Migration struct {
	Version int
	Name    string
	SQL     string
}

// migrations is the list of all database migrations
var migrations = []Migration{
	{
		Version: 1,
		Name:    "initial_schema",
		SQL: `
-- Spaces table
CREATE TABLE IF NOT EXISTS spaces (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL DEFAULT 'default',
    name TEXT NOT NULL,
    path TEXT NOT NULL UNIQUE,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_spaces_user_id ON spaces(user_id);
CREATE INDEX IF NOT EXISTS idx_spaces_path ON spaces(path);

-- Conversations table
CREATE TABLE IF NOT EXISTS conversations (
    id TEXT PRIMARY KEY,
    space_id TEXT NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_conversations_space_id ON conversations(space_id);
CREATE INDEX IF NOT EXISTS idx_conversations_created_at ON conversations(created_at DESC);

-- Messages table
CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK(role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    metadata TEXT
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);

-- Sessions table (ACP session tracking)
CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    created_at INTEGER NOT NULL,
    last_used_at INTEGER NOT NULL,
    is_active INTEGER DEFAULT 1,
    UNIQUE(conversation_id)
);

CREATE INDEX IF NOT EXISTS idx_sessions_conversation_id ON sessions(conversation_id);
CREATE INDEX IF NOT EXISTS idx_sessions_is_active ON sessions(is_active);

-- Schema migrations table
CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    applied_at INTEGER NOT NULL
);
`,
	},
	{
		Version: 2,
		Name:    "add_space_icon_color",
		SQL: `
-- Add icon and color columns to spaces table
ALTER TABLE spaces ADD COLUMN icon TEXT DEFAULT '';
ALTER TABLE spaces ADD COLUMN color TEXT DEFAULT '';
`,
	},
	{
		Version: 3,
		Name:    "add_registry_tables",
		SQL: `
-- Registry: Captures table for tracking notes
CREATE TABLE IF NOT EXISTS captures (
    id TEXT PRIMARY KEY,
    base_name TEXT NOT NULL UNIQUE,
    title TEXT,
    created_at INTEGER NOT NULL,
    has_audio INTEGER DEFAULT 1,
    has_transcript INTEGER DEFAULT 1,
    metadata TEXT
);

CREATE INDEX IF NOT EXISTS idx_captures_base_name ON captures(base_name);
CREATE INDEX IF NOT EXISTS idx_captures_created_at ON captures(created_at DESC);

-- Registry: Settings table for global configuration
CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- Add default settings
INSERT OR IGNORE INTO settings (key, value) VALUES ('notes_folder', 'notes');
INSERT OR IGNORE INTO settings (key, value) VALUES ('spaces_folder', 'spaces');

-- Migrate spaces table to registry format
-- Add added_at column (copy from created_at)
ALTER TABLE spaces ADD COLUMN added_at INTEGER;
UPDATE spaces SET added_at = created_at WHERE added_at IS NULL;

-- Add last_accessed column
ALTER TABLE spaces ADD COLUMN last_accessed INTEGER;

-- Add config column
ALTER TABLE spaces ADD COLUMN config TEXT DEFAULT '';
`,
	},
}

// RunMigrations applies all pending migrations to the database
func RunMigrations(db *sql.DB) error {
	// Get current version
	currentVersion, err := getCurrentVersion(db)
	if err != nil {
		return fmt.Errorf("failed to get current version: %w", err)
	}

	// Apply pending migrations
	for _, migration := range migrations {
		if migration.Version > currentVersion {
			if err := applyMigration(db, migration); err != nil {
				return fmt.Errorf("failed to apply migration %d: %w", migration.Version, err)
			}
		}
	}

	return nil
}

// getCurrentVersion returns the current schema version
func getCurrentVersion(db *sql.DB) (int, error) {
	// Check if migrations table exists
	var count int
	err := db.QueryRow(`
		SELECT COUNT(*) FROM sqlite_master
		WHERE type='table' AND name='schema_migrations'
	`).Scan(&count)
	if err != nil {
		return 0, err
	}

	if count == 0 {
		// No migrations table yet, version is 0
		return 0, nil
	}

	// Get max version
	var version sql.NullInt64
	err = db.QueryRow("SELECT MAX(version) FROM schema_migrations").Scan(&version)
	if err != nil {
		return 0, err
	}

	if !version.Valid {
		return 0, nil
	}

	return int(version.Int64), nil
}

// applyMigration applies a single migration
func applyMigration(db *sql.DB, migration Migration) error {
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Execute migration SQL
	if _, err := tx.Exec(migration.SQL); err != nil {
		return err
	}

	// Record migration
	_, err = tx.Exec(`
		INSERT INTO schema_migrations (version, name, applied_at)
		VALUES (?, ?, ?)
	`, migration.Version, migration.Name, nowUnix())
	if err != nil {
		return err
	}

	return tx.Commit()
}
