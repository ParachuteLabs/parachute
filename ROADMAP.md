# Parachute Development Roadmap

**Last Updated**: November 1, 2025

---

## Current Focus: Space SQLite Knowledge System

**Status**: 🚧 In Active Development
**Priority**: P0
**Timeline**: Nov 2025

Enable spaces to have structured knowledge management with SQLite databases that link to canonical notes in `{vault}/{captures}/` while allowing cross-pollination between spaces.

**See**: [docs/features/space-sqlite-knowledge-system.md](docs/features/space-sqlite-knowledge-system.md)

---

## Development Phases

### ✅ Completed (Oct 2025)

#### Foundation Phase

- [x] Backend architecture (Go + Fiber + SQLite)
- [x] Frontend architecture (Flutter + Riverpod)
- [x] ACP integration with Claude
- [x] WebSocket streaming for conversations
- [x] Basic space and conversation management

#### Recorder Integration

- [x] **Phase 1**: Basic merge of recorder into main app
- [x] **Phase 2**: Visual unification
- [x] **Phase 3a**: Local file system foundation (`~/Parachute/`)
- [x] **Phase 3b**: File browser with markdown preview
- [x] Omi device integration with firmware updates
- [x] Local Whisper transcription (on-device models)
- [x] Gemma 2B title generation with HuggingFace integration
- [x] Transcript display and editing

#### Vault System (Nov 2025)

- [x] Configurable vault location (platform-specific defaults)
- [x] Configurable subfolder names (captures/, spaces/)
- [x] Obsidian/Logseq compatibility
- [x] FileSystemService architecture for path management
- [x] 4-step onboarding flow
- [x] Model download management (Whisper + Gemma)
- [x] HuggingFace token integration
- [x] Background downloads with progress persistence
- [x] Storage calculation and display

---

## Active Development

### 🚧 Space SQLite Knowledge System (Current Sprint)

**Goal**: Link captures to spaces with space-specific context while keeping notes canonical.

#### Phase 1: Backend Foundation (In Progress)

- [ ] Create `SpaceDatabaseService` in Go
- [ ] API endpoints for note linking
- [ ] Migration for existing spaces to add space.sqlite
- [ ] Unit tests for database operations

#### Phase 2: Frontend - Note Linking UI

- [ ] `LinkCaptureToSpaceScreen` with multi-select
- [ ] Enhance recording detail screen with link button
- [ ] Models and API client integration

#### Phase 3: Frontend - Space Note Browser

- [ ] "Linked Notes" section in space browser
- [ ] Note cards with context/tags
- [ ] Filter and sort capabilities

#### Phase 4: Chat Integration

- [ ] "Reference Note" button in conversations
- [ ] Backend includes relevant notes in ACP context
- [ ] Track note usage (last_referenced)

#### Phase 5: CLAUDE.md Integration

- [ ] System prompt template variables ({{note_count}}, etc.)
- [ ] Dynamic context injection
- [ ] Documentation for effective system prompts

**Target Completion**: Mid-November 2025

---

## Near-Term Roadmap (Q4 2025)

### 🔜 Multi-Device Sync

**Priority**: P1
**Status**: Planning

- Backend cloud service (optional, privacy-first)
- E2E encryption for synced data
- Conflict resolution for conversations and notes
- Mobile app support (iOS/Android)

**Why**: Enable using Parachute across devices while maintaining privacy

### 🔜 Smart Note Management

**Priority**: P1
**Status**: Backlog

- Auto-suggest spaces when saving recordings
- Tag suggestions based on content
- Automatic context generation using Claude
- "Similar notes" recommendations

**Why**: Reduce manual work, improve knowledge organization

---

## Medium-Term Roadmap (Q1 2026)

### Knowledge Graph Visualization

**Priority**: P2
**Status**: Concept

- Visual map of notes, spaces, and relationships
- "What connects these two spaces?"
- Timeline view of knowledge evolution
- Cluster detection (similar notes)

**Why**: Enable visual discovery and pattern recognition

### Custom Space Templates

**Priority**: P2
**Status**: Concept

Create templates for common space types:

- Project spaces (tasks, milestones, issues)
- Research spaces (papers, citations, hypotheses)
- Personal spaces (habits, reflections, goals)
- Creative spaces (ideas, drafts, inspirations)

**Why**: Jumpstart space setup, encourage best practices

### Advanced Search & Query

**Priority**: P2
**Status**: Concept

- Natural language queries ("farming notes from last month")
- Semantic search using embeddings
- Cross-space queries
- Export query results

**Why**: Find information faster, discover connections

---

## Long-Term Vision (2026+)

### Collaborative Spaces

**Priority**: P3
**Status**: Vision

- Share spaces with team members
- Permissions per space
- Sync while maintaining privacy for personal notes
- Comments and discussions

**Why**: Enable team knowledge management

### Mobile-First Recorder

**Priority**: P2
**Status**: Vision

- Native mobile app with better recording
- Background recording with Omi
- Offline-first sync
- Widget for quick capture

**Why**: Most voice notes are captured on mobile

### Plugin System

**Priority**: P3
**Status**: Vision

- Space plugins for custom functionality
- Custom visualizations
- Integration with external tools (Obsidian, Notion, etc.)
- API for third-party apps

**Why**: Extensibility without bloat

### AI-Powered Insights

**Priority**: P3
**Status**: Vision

- Weekly/monthly summaries of notes
- Pattern detection across spaces
- Proactive suggestions ("You haven't reviewed farming notes in 2 weeks")
- Automated tagging and categorization

**Why**: Surface insights user might miss

---

## Feature Request Queue

### Small Enhancements

- [ ] Export conversation as markdown
- [ ] Duplicate space (with or without content)
- [ ] Archive old conversations
- [ ] Bulk operations (move, delete, tag)
- [ ] Keyboard shortcuts
- [ ] Dark mode refinements
- [ ] Custom color schemes per space
- [ ] Note version history

### Recorder Improvements

- [ ] Audio bookmarks during recording
- [ ] Real-time transcription preview
- [ ] Speaker diarization (multiple speakers)
- [ ] Export formats (MP3, FLAC)
- [ ] Noise reduction preprocessing
- [ ] Variable playback speed

### Integration Requests

- [ ] Import from Apple Notes
- [ ] Import from Voice Memos
- [ ] Export to Obsidian
- [ ] Zapier/IFTTT webhooks
- [ ] Calendar integration
- [ ] Email-to-Parachute

---

## Technical Debt & Infrastructure

### High Priority

- [ ] Improve error handling and user feedback
- [ ] Add comprehensive logging
- [ ] Performance optimization (large conversations)
- [ ] Memory usage profiling
- [ ] Implement rate limiting
- [ ] Add request validation middleware

### Medium Priority

- [ ] Increase test coverage (target: 80%)
- [ ] E2E testing framework
- [ ] CI/CD pipeline
- [ ] Automated backup system
- [ ] Database migration tooling
- [ ] API versioning strategy

### Low Priority

- [ ] Code documentation (GoDoc)
- [ ] API documentation (OpenAPI/Swagger)
- [ ] Contributing guidelines
- [ ] Architectural decision records (ADRs)

---

## Research & Exploration

### Active Research

- [ ] Optimal embedding models for semantic search
- [ ] Local LLM integration (Llama, Mistral)
- [ ] Graph database alternatives (SQLite vs Neo4j)
- [ ] Differential sync algorithms

### Future Exploration

- [ ] Real-time collaboration (CRDT)
- [ ] Homomorphic encryption for cloud sync
- [ ] Federated learning for privacy-preserving insights
- [ ] Progressive web app (PWA) version

---

## Non-Goals

Things we've explicitly decided **not** to pursue:

- ❌ Social features (likes, followers, feeds)
- ❌ Ads or attention-harvesting mechanics
- ❌ Required cloud sync (always local-first)
- ❌ Lock-in formats (use markdown, standard SQLite)
- ❌ Cryptocurrency/blockchain integration
- ❌ AI training on user data without explicit consent

---

## Decision Log

### November 2025

- ✅ Vault-based architecture with configurable location (supports Obsidian/Logseq)
- ✅ Configurable subfolder names for flexibility
- ✅ Platform-specific storage defaults (macOS, Android, iOS)
- ✅ HuggingFace token integration for gated models
- ✅ Background download support with progress persistence

### October 2025

- ✅ Decided on space.sqlite approach over centralized knowledge graph
- ✅ Chose to keep notes canonical in captures/ (not duplicate)
- ✅ Adopted vault folder as single root for all data
- ✅ Prioritized local-first over cloud-first architecture

### September 2025

- ✅ Selected Go + Fiber for backend (over Node.js/Python)
- ✅ Selected Flutter for frontend (over React Native/Swift)
- ✅ Chose ACP protocol for Claude integration
- ✅ Decided on SQLite for MVP (PostgreSQL for later)

---

## How to Contribute Ideas

Have an idea for Parachute? Here's how to propose it:

1. **Check existing docs** - Review this roadmap and feature docs
2. **Open an issue** - Describe the problem and proposed solution
3. **Discuss trade-offs** - What's gained? What's the cost?
4. **Prototype if possible** - Code speaks louder than words
5. **Iterate** - Feedback shapes the best features

---

## Roadmap Principles

1. **Local-First**: User owns their data, always
2. **Privacy by Default**: No tracking, no ads, no surveillance
3. **Open & Interoperable**: Use standard formats, enable export
4. **Thoughtful AI**: Enhance thinking, don't replace it
5. **Sustainable Pace**: Quality over speed, avoid burnout
6. **User-Driven**: Build what users need, not what's trendy

---

## Related Documents

- [docs/features/space-sqlite-knowledge-system.md](docs/features/space-sqlite-knowledge-system.md) - Current feature in development
- [ARCHITECTURE.md](ARCHITECTURE.md) - System design and technical decisions
- [CLAUDE.md](CLAUDE.md) - Developer guidance for working with this codebase
- [docs/merger-plan.md](docs/merger-plan.md) - Historical: How we merged recorder into main app

---

**Next Update**: After completing Space SQLite Knowledge System Phase 1

**Feedback**: Open an issue or discussion on GitHub
