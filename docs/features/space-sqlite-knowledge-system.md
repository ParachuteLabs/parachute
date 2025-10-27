# Space SQLite Knowledge System

**Status**: 🚧 In Development
**Priority**: P0 - Current Focus
**Started**: October 27, 2025

---

## Vision

Enable spaces to have structured knowledge management while keeping notes canonical and cross-pollinating between contexts. Each space gets its own SQLite database to track relationships, context, and metadata without duplicating the source files.

### Core Principle
**"One folder, one file system that organizes your data to enable it to be open and interoperable"**

---

## Problem Statement

Currently:
- Recordings are saved to `~/Parachute/captures/` as canonical files
- Spaces exist in `~/Parachute/spaces/` with their own directories
- No structured way to link captures to spaces
- No space-specific contextualization of notes
- Notes can't effectively "cross-pollinate" between spaces

**We need:**
- Link notes to multiple spaces with different context per space
- Query and filter notes within a space
- Track relationships without duplicating files
- Enable each space to have custom structure as needed

---

## Solution Architecture

### File Structure
```
~/Parachute/
├── captures/                           # SOURCE OF TRUTH
│   ├── 2025-10-26_00-00-17.md        # Canonical note content
│   ├── 2025-10-26_00-00-17.wav       # Audio recording
│   └── 2025-10-26_00-00-17.json      # Recording metadata
│
└── spaces/
    ├── regen-hub/
    │   ├── CLAUDE.md                  # System prompt for this space
    │   ├── space.sqlite               # 🆕 Space-specific database
    │   └── files/                     # Space-specific files
    │
    └── personal/
        ├── CLAUDE.md
        ├── space.sqlite               # 🆕 Different context for same notes
        └── files/
```

### Space SQLite Schema

Every space has a `space.sqlite` database with this base schema:

```sql
-- Metadata about the space database itself
CREATE TABLE space_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

INSERT INTO space_metadata VALUES
    ('schema_version', '1'),
    ('space_id', '<uuid-from-backend>'),
    ('created_at', '<unix-timestamp>');

-- Core table: Links captures with space-specific context
CREATE TABLE relevant_notes (
    id TEXT PRIMARY KEY,                      -- UUID for this link
    capture_id TEXT NOT NULL,                 -- Links to capture's JSON id
    note_path TEXT NOT NULL,                  -- Relative: captures/YYYY-MM-DD_HH-MM-SS.md
    linked_at INTEGER NOT NULL,               -- Unix timestamp
    context TEXT,                             -- Space-specific interpretation
    tags TEXT,                                -- JSON array: ["regeneration", "farming"]
    last_referenced INTEGER,                  -- Track when used in conversation
    metadata TEXT,                            -- JSON: extensible per-space
    UNIQUE(capture_id)                        -- One entry per capture per space
);

-- Indexes for performance
CREATE INDEX idx_relevant_notes_tags ON relevant_notes(tags);
CREATE INDEX idx_relevant_notes_last_ref ON relevant_notes(last_referenced);
CREATE INDEX idx_relevant_notes_linked_at ON relevant_notes(linked_at DESC);

-- Optional: Custom tables for specific space types
-- These could be added via templates or dynamically

-- Example: Project-focused space
CREATE TABLE IF NOT EXISTS projects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    status TEXT CHECK(status IN ('active', 'paused', 'completed')),
    related_notes TEXT,                       -- JSON array of capture_ids
    created_at INTEGER NOT NULL
);

-- Example: People-focused space
CREATE TABLE IF NOT EXISTS people (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    role TEXT,
    related_notes TEXT,                       -- JSON array of capture_ids
    created_at INTEGER NOT NULL
);
```

---

## Data Flow

### 1. Recording a Voice Note
```
User records → Saves to ~/Parachute/captures/
                ├── .wav (audio)
                ├── .json (metadata)
                └── .md (transcript)
```

### 2. Linking Note to Space(s)
```
User: "Link this capture to Regen Hub and Personal spaces"

Frontend: Shows dialog
  - Select spaces (multi-select)
  - For each space:
    ├── Add context (text)
    └── Add tags (chips)

Backend: For each selected space
  1. Open ~/Parachute/spaces/<space-name>/space.sqlite
  2. INSERT INTO relevant_notes (...)
  3. Close database
```

### 3. Browsing Space Notes
```
User opens Regen Hub space

Frontend:
  ├── Shows space files (files/ directory)
  └── Shows "Linked Notes" section

API: GET /api/spaces/{id}/notes
  1. Open space.sqlite
  2. SELECT * FROM relevant_notes
     ORDER BY linked_at DESC
  3. For each row:
     ├── Read note content from ~/Parachute/captures/
     └── Combine with space-specific context
  4. Return enriched notes
```

### 4. Conversation References Note
```
User in chat: "Tell me about that farming insight"

Backend:
  1. Load space.sqlite for current space
  2. Query relevant_notes (possibly by tag or search)
  3. Read note content from captures/
  4. Include in Claude context with space-specific context
  5. UPDATE relevant_notes
     SET last_referenced = <now>
     WHERE capture_id = '...'
```

---

## Implementation Plan

### Phase 1: Backend Foundation
**Goal**: Space database initialization and basic CRUD

- [ ] Create `SpaceDatabaseService` in Go
  - [ ] `InitializeSpaceDatabase(spacePath)` - Creates space.sqlite
  - [ ] `LinkNote(spaceID, captureID, notePath, context, tags)` - Links capture
  - [ ] `GetRelevantNotes(spaceID, filters)` - Queries linked notes
  - [ ] `UpdateNoteContext(spaceID, captureID, newContext)` - Updates context
  - [ ] `UnlinkNote(spaceID, captureID)` - Removes link
  - [ ] `TrackNoteReference(spaceID, captureID)` - Updates last_referenced

- [ ] Add migration for existing spaces
  - [ ] Auto-create space.sqlite in each space directory
  - [ ] Handle spaces created before this feature

- [ ] Add API endpoints
  - [ ] `GET /api/spaces/:id/notes` - List linked notes with filters
  - [ ] `POST /api/spaces/:id/notes` - Link capture to space
  - [ ] `PUT /api/spaces/:id/notes/:capture_id` - Update context/tags
  - [ ] `DELETE /api/spaces/:id/notes/:capture_id` - Unlink note
  - [ ] `GET /api/spaces/:id/notes/:capture_id/content` - Get note with context

### Phase 2: Frontend - Note Linking UI
**Goal**: User can link recordings to spaces

- [ ] Create `LinkCaptureToSpaceScreen`
  - [ ] Multi-select space picker
  - [ ] For each space: context text field + tag chips
  - [ ] Visual indicator of already-linked spaces
  - [ ] Save button → calls POST /api/spaces/:id/notes

- [ ] Enhance `RecordingDetailScreen`
  - [ ] Add "Link to Space" button
  - [ ] Show which spaces note is linked to (badges/chips)
  - [ ] Quick-link buttons for recent/favorite spaces

- [ ] Create models
  - [ ] `RelevantNote` model
  - [ ] `NoteLinkRequest` model
  - [ ] Update API client with new endpoints

### Phase 3: Frontend - Space Note Browser
**Goal**: Browse and manage linked notes within a space

- [ ] Enhance `SpaceFilesWidget`
  - [ ] Add "Linked Notes" tab/section
  - [ ] Query and display relevant_notes from API
  - [ ] Show note cards with:
    - Title, preview
    - Space-specific context
    - Tags (chips)
    - Last referenced timestamp
  - [ ] Tap to open note with space context overlay

- [ ] Create `NoteWithSpaceContextScreen`
  - [ ] Display markdown note content
  - [ ] Overlay space context at top
  - [ ] Show tags for this space
  - [ ] "Edit Context" button → UpdateNoteContext
  - [ ] "Unlink from Space" button

- [ ] Add filtering/sorting
  - [ ] Filter by tags
  - [ ] Sort by: linked date, last referenced, alphabetical
  - [ ] Search within space notes

### Phase 4: Chat Integration
**Goal**: Reference notes in conversations intelligently

- [ ] Add "Reference Note" button in chat
  - [ ] Browse relevant_notes for current space
  - [ ] Search/filter notes
  - [ ] Select note → inserts into conversation

- [ ] Backend: Include relevant notes in ACP context
  - [ ] When building conversation context, query space.sqlite
  - [ ] Include top N recently referenced notes
  - [ ] Include notes matching conversation topic (future: semantic search)

- [ ] Show linked notes sidebar during chat
  - [ ] "Relevant to this space" section
  - [ ] Smart suggestions based on conversation

- [ ] Track note usage
  - [ ] When Claude references a note, update last_referenced
  - [ ] Analytics: most useful notes per space

### Phase 5: CLAUDE.md Integration
**Goal**: System prompts can reference space-specific knowledge

- [ ] Update CLAUDE.md template documentation
  - [ ] How to reference linked notes in system prompts
  - [ ] Variables available (note count, recent notes, etc.)

- [ ] Backend: Inject note metadata into CLAUDE.md context
  - [ ] When loading space context, include note summary
  - [ ] "This space has 23 linked notes about: farming, soil health, ..."

- [ ] Dynamic context injection
  - [ ] If CLAUDE.md mentions {{relevant_notes}}, replace with summary
  - [ ] If mentions {{recent_notes}}, include last 5 referenced

---

## CLAUDE.md System Prompt Strategy

### Core Philosophy
Each space's `CLAUDE.md` serves as a **persistent system prompt** that shapes Claude's behavior within that context. With the space.sqlite system, we enhance this with structured knowledge.

### System Prompt Patterns

#### 1. Basic Space Context
```markdown
# Regen Hub Space

You are assisting with regenerative agriculture research and planning.

## Context
This space tracks projects, insights, and research related to ecological restoration and sustainable farming.

## Available Knowledge
- Linked Notes: {{note_count}} voice recordings and written notes
- Recent Topics: {{recent_tags}}
- Active Projects: {{active_projects}}

## Guidelines
- Reference linked notes when relevant to the conversation
- Track new insights as potential notes to link
- Connect ideas across different recordings
```

#### 2. Project-Focused Space
```markdown
# Software Project: Parachute

## Project Structure
{{project_structure}}

## Linked Documentation
- Architecture decisions: {{notes_tagged:architecture}}
- Meeting notes: {{notes_tagged:meetings}}
- Feature discussions: {{notes_tagged:features}}

## When discussing features:
1. Check if there are existing linked notes about the topic
2. Reference previous decisions and context
3. Suggest linking new insights to this space
```

#### 3. Personal Journaling Space
```markdown
# Personal Journal

You are a thoughtful companion for reflection and personal growth.

## Context
This space contains personal voice notes, reflections, and thoughts.

## Recent Themes
{{recent_tags}}

## Approach
- Help identify patterns across recordings
- Suggest connections between past and present reflections
- Maintain continuity of thought over time
- Respect privacy and personal nature of content
```

### Dynamic Variables

Backend will support these template variables:

- `{{note_count}}` - Number of linked notes
- `{{recent_tags}}` - Top 5 most used tags (last 30 days)
- `{{recent_notes}}` - Last 5 referenced notes (title + date)
- `{{notes_tagged:X}}` - Count of notes with specific tag
- `{{active_projects}}` - List of projects with status=active
- `{{custom_query:SQL}}` - Advanced: Run custom SQLite query

### Best Practices

1. **Make Context Explicit** - Tell Claude what kind of space this is
2. **Reference Available Knowledge** - Show what notes/data exist
3. **Set Expectations** - Define how Claude should use linked notes
4. **Enable Discovery** - Encourage Claude to suggest connections
5. **Maintain Continuity** - Use last_referenced to maintain conversational memory

---

## Benefits

### 1. Notes Stay Canonical
- One `.md` file in `captures/`, never duplicated
- Audio and metadata stay with note
- Easy to backup, sync, version control

### 2. Polyvalent Context
- Same note has different meanings in different spaces
- `context` field allows space-specific interpretation
- Tags can differ per space

### 3. Cross-Pollination
- Notes aren't trapped in one space
- Ideas flow between projects/contexts
- Discover connections across domains

### 4. Structured Querying
- SQL enables powerful filtering
- "Show me farming notes from Q4 2025"
- "Which notes are linked to both Regen Hub and Personal?"

### 5. Extensible
- Spaces can add custom tables (projects, people, etc.)
- Templates for common space types
- Future: plugins/extensions per space

### 6. Knowledge Graph Ready
- Foundation for visualizing relationships
- "What connects these two spaces?"
- Timeline view of note evolution

### 7. Local-First
- Everything in `~/Parachute/`
- Portable, private, user-controlled
- No cloud lock-in

---

## Future Enhancements

### Smart Linking (Phase 6)
- Auto-suggest spaces based on note content
- ML-based tag suggestions
- Automatic context generation using Claude
- "Similar notes" recommendations

### Knowledge Graph Visualization (Phase 7)
- Visual map of notes and spaces
- "Notes that connect these two spaces"
- Timeline view of knowledge evolution
- Cluster similar notes

### Custom Space Templates (Phase 8)
```bash
~/Parachute/templates/
├── project-space.sql       # Tables: projects, tasks, milestones
├── research-space.sql      # Tables: papers, citations, hypotheses
├── personal-space.sql      # Tables: habits, reflections, goals
└── creative-space.sql      # Tables: ideas, drafts, inspirations
```

User selects template when creating space → backend applies schema

### Advanced Querying (Phase 9)
- Natural language queries: "Show me all farming notes from last month"
- Semantic search using embeddings
- Cross-space queries: "What's common between Regen Hub and Personal?"

### Collaborative Spaces (Phase 10)
- Share space with others
- Permissions per space.sqlite
- Sync notes while maintaining privacy

---

## Migration Strategy

### For Existing Spaces

1. **Auto-Initialize** - Backend migration creates `space.sqlite` in each space
2. **No Breaking Changes** - Spaces work exactly as before
3. **Opt-In Linking** - Notes don't auto-link, user chooses when to link
4. **Incremental Adoption** - Link notes as you go, no need to backfill

### For New Spaces

1. **Auto-Create** - `space.sqlite` created when space is created
2. **Optional Template** - User can select space type/template
3. **Guided Setup** - Wizard suggests initial structure

---

## Success Metrics

- [ ] Spaces can link to multiple captures
- [ ] Same capture can exist in multiple spaces with different context
- [ ] Users can browse space-specific notes easily
- [ ] Conversations can reference linked notes
- [ ] Note usage tracked (last_referenced)
- [ ] System prompts can leverage space knowledge
- [ ] No performance degradation with 100+ notes per space

---

## Technical Considerations

### Performance
- SQLite is fast for local queries
- Index on tags, last_referenced for common queries
- Batch operations when linking multiple notes

### Data Integrity
- Foreign key to capture_id (but capture lives in file system)
- Validation: ensure note_path exists before linking
- Handle deleted captures gracefully

### Backup & Sync
- `space.sqlite` files are small, easy to backup
- Could sync via Git, Dropbox, etc.
- Future: Built-in sync service

### Testing
- Unit tests for SpaceDatabaseService
- Integration tests for API endpoints
- E2E tests for linking workflow
- Test with many notes (performance)

---

## Dependencies

### Backend
- `database/sql` (stdlib)
- `modernc.org/sqlite` (already used)
- No new dependencies needed

### Frontend
- No new dependencies (uses existing API client)
- Consider adding search/filter UI library if needed

---

## Documentation Needed

- [ ] User guide: How to link notes to spaces
- [ ] CLAUDE.md guide: Writing effective system prompts
- [ ] API documentation: Space notes endpoints
- [ ] Developer guide: Working with space.sqlite
- [ ] Migration guide: Upgrading existing installations

---

## Open Questions

- [ ] Should we support note templates per space?
- [ ] How to handle bulk linking (e.g., "link all farming notes to Regen Hub")?
- [ ] Should spaces be able to "subscribe" to notes by tag?
- [ ] What's the UX for discovering notes that should be linked?
- [ ] Should we support note hierarchies/collections within spaces?

---

## Related Documents

- [ARCHITECTURE.md](../ARCHITECTURE.md) - Overall system design
- [ROADMAP.md](../ROADMAP.md) - Future features queue
- [CLAUDE.md](../CLAUDE.md) - Developer guidance
- [docs/recorder/](../recorder/) - Voice recording implementation

---

**Last Updated**: October 27, 2025
**Next Review**: After Phase 1 completion
