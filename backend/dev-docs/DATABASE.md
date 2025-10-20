# Database Documentation

**Status:** To be implemented in Phase 3

---

## Overview

Parachute uses SQLite as its database. This document describes the schema, migrations, and query patterns.

---

## Why SQLite?

- ✅ Embedded (no separate server)
- ✅ Single file (easy backups)
- ✅ Works everywhere (mobile, desktop, server)
- ✅ Perfect for single-user applications
- ✅ Migration path to PostgreSQL later

**Using:** `modernc.org/sqlite` (pure Go, no CGO required)

---

## Schema

### Spaces

Represents a cognitive context (directory with CLAUDE.md).

```sql
CREATE TABLE spaces (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,              -- Future: FK to users table
    name TEXT NOT NULL,
    path TEXT NOT NULL UNIQUE,          -- Absolute file system path
    created_at INTEGER NOT NULL,        -- Unix timestamp
    updated_at INTEGER NOT NULL         -- Unix timestamp
);

CREATE INDEX idx_spaces_user_id ON spaces(user_id);
CREATE INDEX idx_spaces_path ON spaces(path);
```

### Conversations

Represents a chat conversation within a Space.

```sql
CREATE TABLE conversations (
    id TEXT PRIMARY KEY,
    space_id TEXT NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    title TEXT NOT NULL,                -- Auto-generated or user-set
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE INDEX idx_conversations_space_id ON conversations(space_id);
CREATE INDEX idx_conversations_created_at ON conversations(created_at DESC);
```

### Messages

Individual messages in a conversation.

```sql
CREATE TABLE messages (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK(role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    metadata TEXT                       -- JSON: tool calls, permissions, etc.
);

CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);
```

**Metadata JSON Example:**
```json
{
  "tool_calls": [
    {
      "name": "read_file",
      "status": "approved",
      "result": "..."
    }
  ]
}
```

### Sessions

Tracks ACP session state for each conversation.

```sql
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,                -- ACP session_id
    conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    created_at INTEGER NOT NULL,
    last_used_at INTEGER NOT NULL,
    is_active INTEGER DEFAULT 1,        -- Boolean: 1=active, 0=inactive
    UNIQUE(conversation_id)             -- One active session per conversation
);

CREATE INDEX idx_sessions_conversation_id ON sessions(conversation_id);
CREATE INDEX idx_sessions_is_active ON sessions(is_active);
```

---

## Migrations

### Migration System

Migrations are SQL files in `internal/storage/sqlite/migrations/`:

```
migrations/
├── 001_initial_schema.sql
├── 002_add_sessions.sql
└── 003_add_metadata_to_messages.sql
```

### Migration Runner

```go
func RunMigrations(db *sql.DB) error {
    // Create migrations table if not exists
    _, err := db.Exec(`
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version INTEGER PRIMARY KEY,
            applied_at INTEGER NOT NULL
        )
    `)

    // Get current version
    currentVersion := getCurrentVersion(db)

    // Apply pending migrations
    for version, migration := range migrations {
        if version > currentVersion {
            if err := applyMigration(db, version, migration); err != nil {
                return err
            }
        }
    }

    return nil
}
```

---

## Query Patterns

### Repository Pattern

Each entity has a repository interface:

```go
type SpaceRepository interface {
    Create(space *Space) error
    GetByID(id string) (*Space, error)
    GetByPath(path string) (*Space, error)
    List(userID string) ([]*Space, error)
    Update(space *Space) error
    Delete(id string) error
}
```

### Example Implementation

```go
type SQLiteSpaceRepository struct {
    db *sql.DB
}

func (r *SQLiteSpaceRepository) Create(space *Space) error {
    query := `
        INSERT INTO spaces (id, user_id, name, path, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
    `

    _, err := r.db.Exec(query,
        space.ID,
        space.UserID,
        space.Name,
        space.Path,
        space.CreatedAt,
        space.UpdatedAt,
    )

    return err
}

func (r *SQLiteSpaceRepository) GetByID(id string) (*Space, error) {
    query := `
        SELECT id, user_id, name, path, created_at, updated_at
        FROM spaces
        WHERE id = ?
    `

    var space Space
    err := r.db.QueryRow(query, id).Scan(
        &space.ID,
        &space.UserID,
        &space.Name,
        &space.Path,
        &space.CreatedAt,
        &space.UpdatedAt,
    )

    if err == sql.ErrNoRows {
        return nil, ErrNotFound
    }

    return &space, err
}
```

---

## Common Queries

### Get Conversation History

```sql
SELECT id, role, content, created_at, metadata
FROM messages
WHERE conversation_id = ?
ORDER BY created_at ASC;
```

### Get Recent Conversations in Space

```sql
SELECT c.id, c.title, c.created_at, c.updated_at,
       COUNT(m.id) as message_count
FROM conversations c
LEFT JOIN messages m ON m.conversation_id = c.id
WHERE c.space_id = ?
GROUP BY c.id
ORDER BY c.updated_at DESC
LIMIT 20;
```

### Get Active Session for Conversation

```sql
SELECT id, created_at, last_used_at
FROM sessions
WHERE conversation_id = ? AND is_active = 1
LIMIT 1;
```

---

## Database File Location

Default: `./data/parachute.db`

Configurable via `DATABASE_PATH` environment variable.

---

## Backup Strategy

SQLite is a single file, making backups simple:

```bash
# Copy database file
cp data/parachute.db data/backups/parachute-$(date +%Y%m%d).db

# Or use SQLite backup command
sqlite3 data/parachute.db ".backup data/backups/parachute-$(date +%Y%m%d).db"
```

---

## Performance Considerations

### Indexes

All foreign keys have indexes for join performance.

### Connection Pool

SQLite works best with a single writer:

```go
db.SetMaxOpenConns(1) // Single writer
db.SetMaxIdleConns(1)
```

### WAL Mode

Enable Write-Ahead Logging for better concurrency:

```sql
PRAGMA journal_mode = WAL;
```

---

## Testing

Use in-memory database for tests:

```go
db, _ := sql.Open("sqlite", ":memory:")
```

---

## References

- SQLite Docs: https://www.sqlite.org/docs.html
- modernc.org/sqlite: https://pkg.go.dev/modernc.org/sqlite

---

**Last Updated:** October 20, 2025
**Status:** Schema defined, ready for Phase 3 implementation
