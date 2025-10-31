# Phase 3A: Local File System Foundation

**Status:** 🚧 In Progress
**Date:** 2025-10-25

---

## Overview

Phase 3A implements the local file system foundation for the unified Parachute architecture where all data lives in a simple, syncable folder structure.

---

## Objectives

### ✅ Completed

1. **Unified File System Architecture Design**
   - Created comprehensive architecture document
   - Defined folder structure: `~/Parachute/captures/` and `~/Parachute/spaces/`
   - File-first philosophy: Files are source of truth, databases are indexes

2. **Core FileSystemService**
   - Created `app/lib/core/services/file_system_service.dart`
   - Manages root Parachute folder initialization
   - Provides path helpers for captures and spaces
   - Cross-platform support (macOS, Linux, mobile)

3. **Recorder Storage Migration**
   - Updated `StorageService` to use `FileSystemService`
   - Recordings now save to `~/Parachute/captures/`
   - New filename format: `2025-10-25_14-30-22.wav`
   - Transcript files: `2025-10-25_14-30-22.md`
   - Metadata files: `2025-10-25_14-30-22.json` (planned)

### 🚧 In Progress

1. **Testing**
   - Build verification
   - Manual testing of recorder with new structure

### 📋 Pending

1. **Spaces Migration**
   - Update spaces to use `~/Parachute/spaces/` structure
   - Implement space folder creation
   - Migrate existing spaces data

2. **Backend Integration**
   - Add file upload/download endpoints
   - Implement sync service
   - WebSocket notifications for changes

---

## File System Structure

### Captures Folder
```
~/Parachute/captures/
├── 2025-10-25_14-30-22.wav      # Audio file
├── 2025-10-25_14-30-22.md       # Transcript (markdown)
└── 2025-10-25_14-30-22.json     # Metadata (for indexing)
```

### Spaces Folder (Planned)
```
~/Parachute/spaces/
├── work/
│   ├── CLAUDE.md                # AI context
│   ├── .space.json              # Space metadata
│   ├── files/                   # Space files
│   └── conversations/           # Conversation markdown
│       └── 2025-10-25_project-planning.md
└── personal/
    └── ...
```

---

## Technical Changes

### Files Created
1. `app/lib/core/services/file_system_service.dart` - Unified file system manager
2. `docs/architecture/unified-file-system.md` - Architecture documentation
3. `docs/phase3a-local-file-system.md` - This document

### Files Modified
1. `app/lib/features/recorder/services/storage_service.dart`
   - Integrated `FileSystemService`
   - Updated path methods to use captures folder
   - Fixed async/await for path methods
   - Uses new timestamp format

---

## Key Features

### FileSystemService

**Initialization:**
- Auto-detects platform (macOS: `~/Parachute`, mobile: app documents)
- Creates folder structure on first run
- Configurable root path via settings

**Path Management:**
```dart
// Get captures folder
final capturesPath = await fileSystem.getCapturesPath();

// Get space folder
final spacePath = await fileSystem.getSpacePath('work');

// Get conversations folder
final conversationsPath = await fileSystem.getSpaceConversationsPath('work');
```

**Timestamp Format:**
```dart
// Filesystem-safe format: 2025-10-25_14-30-22
final timestamp = FileSystemService.formatTimestampForFilename(DateTime.now());

// Parse from filename
final dateTime = FileSystemService.parseTimestampFromFilename(filename);
```

---

## Migration Strategy

### Recorder
- ✅ New recordings save to new location automatically
- 📋 TODO: Migrate existing recordings from old location
- 📋 TODO: Show migration progress to user

### Spaces
- 📋 TODO: Create space folders on first access
- 📋 TODO: Migrate existing conversations from database to markdown
- 📋 TODO: Export CLAUDE.md from current space data

---

## Testing Checklist

- [x] FileSystemService initializes correctly
- [x] Captures folder is created
- [x] Spaces folder is created
- [ ] Recorder saves to new location
- [ ] Recorder loads from new location
- [ ] Sample recordings work
- [ ] Path formatting is correct
- [ ] Cross-platform paths work
- [ ] Settings allow changing root folder

---

## Benefits

### User Benefits
1. **Transparency** - Can see and access all their data as files
2. **Portability** - Easy backup, export, and migration
3. **Flexibility** - Can use external sync tools (Syncthing, iCloud, etc.)
4. **Control** - Own their data in standard formats

### Developer Benefits
1. **Simplicity** - Files are easier to debug than databases
2. **Reliability** - File corruption is less catastrophic
3. **Flexibility** - Easy to add new file types
4. **Testing** - Can manually inspect and create test data

---

## Next Steps

### Immediate (Phase 3A Completion)
1. ✅ Fix compilation errors
2. 🚧 Test macOS build
3. Test recorder functionality with new file system
4. Migrate existing recordings (if any)
5. Update spaces to use new structure

### Near Term (Phase 3B)
1. Add backend file storage tables
2. Implement file upload/download endpoints
3. Create file hash tracking
4. Add sync state management

### Future (Phase 3C)
1. Implement sync service in Flutter
2. Real-time sync via WebSocket
3. Conflict resolution
4. Offline queue

---

## Known Issues

1. **Sample recordings** - Currently create placeholder files
   - Need to handle missing audio files gracefully
   - Should skip samples in production builds

2. **Migration** - No migration tool yet for existing data
   - Users with existing recordings need manual migration
   - Or: Auto-detect and migrate on first run

3. **File watching** - Not implemented yet
   - Changes made outside app won't be detected
   - Need file system watcher for auto-sync

---

## Architecture Decisions

### Why File-First?

**Pros:**
- Human-readable and inspectable
- Works with standard tools
- Easy backup and export
- No vendor lock-in
- Survives database corruption

**Cons:**
- Slower for some queries (solved with database index)
- No transactions (solved with careful write ordering)
- File system limits (not an issue for typical usage)

**Decision:** Pros outweigh cons for this use case

### Why Markdown for Transcripts?

**Pros:**
- Human-readable
- Easy to edit manually
- Works with all text editors
- Git-friendly
- Supports frontmatter for metadata

**Cons:**
- Parsing overhead (minimal)
- Not as compact as binary (acceptable)

**Decision:** Readability and portability win

### Why Separate JSON Metadata?

**Pros:**
- Fast indexing without parsing markdown
- Clean separation of concerns
- Easy to query

**Cons:**
- Duplicate data
- Can get out of sync

**Decision:** Optional optimization, markdown is source of truth

---

## Code Examples

### Creating a Recording

```dart
// Get captures path
final capturesPath = await fileSystem.getCapturesPath();

// Generate filename
final timestamp = DateTime.now();
final filename = FileSystemService.formatTimestampForFilename(timestamp);

// Save audio
final audioPath = '$capturesPath/$filename.wav';
await File(audioPath).writeAsBytes(audioData);

// Save transcript
final transcriptPath = '$capturesPath/$filename.md';
await File(transcriptPath).writeAsString(markdownContent);
```

### Creating a Space

```dart
// Create space folder
await fileSystem.createSpace('work');

// Creates:
// ~/Parachute/spaces/work/
// ~/Parachute/spaces/work/CLAUDE.md
// ~/Parachute/spaces/work/.space.json
// ~/Parachute/spaces/work/conversations/
// ~/Parachute/spaces/work/files/
```

---

## Performance Considerations

### File System Operations
- **Fast:** Reading/writing individual files
- **Slow:** Scanning entire folder for recordings
- **Solution:** Database index for queries, files for storage

### Sync Efficiency
- **Challenge:** Many small files = many HTTP requests
- **Solution:** Batch uploads, delta sync, compression

### Mobile Considerations
- **Storage:** Limited space on mobile
- **Solution:** Selective sync, cloud-only mode
- **Battery:** File watching can drain battery
- **Solution:** Smart wake-up, batch processing

---

## Documentation Links

- [Unified File System Architecture](architecture/unified-file-system.md)
- [Phase 2 Visual Unification](phase2-visual-unification.md)
- [Merger Plan](merger-plan.md)

---

**Status:** 🚧 Phase 3A in progress - Local file system foundation
**Last Updated:** 2025-10-25
**Next Phase:** Phase 3B - Backend Integration
