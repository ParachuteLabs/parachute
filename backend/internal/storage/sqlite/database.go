package sqlite

import (
	"database/sql"
	"fmt"
	"time"

	_ "modernc.org/sqlite" // SQLite driver
)

// Database wraps the SQL database connection
type Database struct {
	DB *sql.DB
}

// NewDatabase creates a new database connection and runs migrations
func NewDatabase(path string) (*Database, error) {
	// Open database
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	// Configure connection pool
	// SQLite works best with a single writer
	db.SetMaxOpenConns(1)
	db.SetMaxIdleConns(1)

	// Enable WAL mode for better concurrency
	if _, err := db.Exec("PRAGMA journal_mode=WAL"); err != nil {
		db.Close()
		return nil, fmt.Errorf("failed to enable WAL mode: %w", err)
	}

	// Enable foreign keys
	if _, err := db.Exec("PRAGMA foreign_keys=ON"); err != nil {
		db.Close()
		return nil, fmt.Errorf("failed to enable foreign keys: %w", err)
	}

	// Run migrations
	if err := RunMigrations(db); err != nil {
		db.Close()
		return nil, fmt.Errorf("failed to run migrations: %w", err)
	}

	return &Database{DB: db}, nil
}

// Close closes the database connection
func (d *Database) Close() error {
	return d.DB.Close()
}

// nowUnix returns the current Unix timestamp
func nowUnix() int64 {
	return time.Now().Unix()
}
