# What's Next After Phase 1

**Phase 1 Status**: ✅ COMPLETE (Committed: e959865)

---

## Immediate Tasks (Optional)

### 1. Test Omi Integration
Since you mentioned you haven't fully tested Omi yet:
- [ ] Pair Omi device via recorder settings
- [ ] Test background recording from pendant
- [ ] Verify audio streams to app correctly
- [ ] Test firmware update (if available)

### 2. Test Other Platforms
Currently only macOS tested:
- [ ] Test on iOS (requires adding permissions to iOS Info.plist)
- [ ] Test on Android (requires adding permissions to AndroidManifest.xml)
- [ ] Test on Web (may have limited functionality)

### 3. Use the App!
Best way to find issues and prioritize Phase 2 features:
- Use AI Chat for your normal workflows
- Record voice notes regularly
- Identify pain points in the UX
- Note any features you wish worked together

---

## Phase 2: Visual Unification (When Ready)

**Goal**: Make it feel like one cohesive app instead of two separate features bolted together.

**Priority**: Medium (not urgent, do after using Phase 1 for a while)

### Theme Harmonization
**Current State:**
- AI Chat: Material3 with light blue seed color
- Recorder: Custom theme with Google Fonts and forest green

**Options:**
1. **Keep Parachute theme everywhere** (simplest)
   - Change recorder to use Parachute's theme
   - Quick win, less design work

2. **Create unified new theme** (better)
   - Design cohesive color palette
   - Choose one font system (Google Fonts or system)
   - Apply consistently across both features

3. **Recorder inherits but customizes** (middle ground)
   - Recorder uses Parachute base theme
   - Add custom accent colors for recorder context

### Settings Unification
**Current State:**
- Two separate settings screens (AI Chat settings / Recorder settings)
- No central settings

**Proposal:**
- Create main settings screen with sections:
  - Account / Auth
  - AI Chat settings
  - Recorder settings (Whisper models, Omi device, etc.)
  - Appearance (theme, dark mode, etc.)
  - About

### Navigation Improvements
**Current State:**
- Bottom nav works but is basic
- No visual indication of active feature
- Generic icons

**Enhancements:**
- Better icons (custom or themed)
- Active tab highlighting
- Smooth transitions
- Consider adding badges (e.g., "3 new recordings")

### Polish & Consistency
- Consistent spacing and padding
- Unified empty states
- Consistent loading indicators
- Smooth transitions between screens
- Consistent error handling UI

---

## Phase 3: Backend Integration (Future)

**Goal**: Connect recorder to Parachute backend for cloud storage and AI integration.

**Priority**: High impact, but requires backend work first

### Backend Architecture Needed

**1. Database Schema**
```sql
CREATE TABLE recordings (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  timestamp TIMESTAMP NOT NULL,
  duration_millis INTEGER NOT NULL,
  file_path TEXT NOT NULL,  -- S3/storage path
  file_size INTEGER NOT NULL,
  transcription TEXT,
  source TEXT,  -- 'phone' or 'omi'
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**2. Storage Service**
- S3 or similar for audio files
- Signed URLs for upload/download
- Automatic cleanup of old files

**3. API Endpoints**
```
POST   /api/recordings                 - Create recording metadata
POST   /api/recordings/:id/upload      - Get signed upload URL
GET    /api/recordings                 - List user's recordings
GET    /api/recordings/:id             - Get recording details
GET    /api/recordings/:id/download    - Get signed download URL
DELETE /api/recordings/:id             - Delete recording
POST   /api/recordings/:id/transcribe  - Trigger cloud transcription
```

**4. WebSocket Events**
```
recording.created
recording.uploaded
recording.transcribed
recording.deleted
```

### Frontend Changes

**1. Storage Service Abstraction**
Create interface for storage (already planned):
```dart
abstract class RecordingStorageService {
  Future<List<Recording>> getRecordings();
  Future<Recording> getRecording(String id);
  Future<void> saveRecording(Recording recording);
  Future<void> deleteRecording(String id);
  Future<String> getAudioFilePath(String id);
}
```

**2. Implementations**
```dart
// Current (local)
class LocalRecordingStorageService implements RecordingStorageService {
  // Uses SharedPreferences + local file system
}

// Future (cloud)
class CloudRecordingStorageService implements RecordingStorageService {
  // Uses backend API + downloads files as needed
}
```

**3. Upload Flow**
```
1. User stops recording
2. Save locally first (for immediate playback)
3. Background upload to cloud
4. Show upload progress
5. Mark as synced when complete
6. Keep local copy for offline access
```

**4. Sync Strategy**
- Upload new recordings automatically (when on WiFi)
- Download metadata for all recordings
- Lazy-load audio files (download on play)
- Conflict resolution (local vs cloud)

### AI Integration Features

**1. "Transcribe and Send to Chat"**
- Button on recording detail screen
- Sends transcription to current conversation
- Creates new message with recording context

**2. "Ask About Recording"**
- AI can reference recording transcriptions
- "What did I record about X?"
- Search recordings via AI

**3. Automatic Context**
- Recent recordings automatically available to AI
- "Based on your voice notes from today..."
- Temporal context for conversations

### Advanced Features (Phase 3+)

**1. Shared Recordings**
- Share recording links with others
- Public/private permissions
- Embed recordings in conversations

**2. Recording Collections**
- Organize recordings into albums/projects
- Bulk transcription
- Export collections

**3. Voice Commands**
- "Record a note about..."
- "Play my recording from yesterday"
- Hands-free recording control

**4. Smart Transcription**
- Speaker diarization (who said what)
- Punctuation and formatting
- Automatic summaries

---

## Decision Points

### 1. When to Start Phase 2?
**Recommendation**: After 1-2 weeks of using Phase 1
- Gives time to identify real UX pain points
- Prioritize changes based on actual usage
- Don't optimize prematurely

### 2. When to Start Phase 3?
**Prerequisites:**
- Backend team available for API work
- Clear requirements for recording storage
- Decision on storage provider (S3, etc.)
- Authentication/authorization strategy

**Recommendation**: Can start planning now, implement after Phase 2

### 3. Should Phases Overlap?
**Option A**: Sequential (Phase 1 → 2 → 3)
- Pros: Clean, focused work
- Cons: Slower overall progress

**Option B**: Parallel (Phase 2 frontend + Phase 3 backend together)
- Pros: Faster time to full integration
- Cons: More complex, requires coordination

**Recommendation**: Start Phase 2 frontend while backend team works on Phase 3 backend

---

## Alternative/Experimental Ideas

### 1. Recording Templates
- Pre-defined recording types (meeting, idea, journal)
- Custom templates with prompts
- Automatic tagging and categorization

### 2. AI-Powered Recording Features
- Real-time transcription during recording
- Live translation
- Automatic meeting minutes
- Action item extraction

### 3. Collaboration Features
- Shared spaces with team recordings
- Comments on recordings
- Recording annotations and timestamps

### 4. Integration with Other Tools
- Export to Notion, Obsidian, etc.
- Calendar integration (recording linked to events)
- Email recordings as attachments

---

## Questions to Consider

### For Phase 2:
1. Do you want a single unified theme or keep some visual distinction?
2. Should recorder settings merge into main settings or stay separate?
3. Any specific UI/UX issues you've noticed while testing?
4. What's your priority: Polish vs. New features?

### For Phase 3:
1. How important is cross-device sync? (affects storage strategy)
2. Do you want real-time or batch upload?
3. Should local storage be permanent or cache-only?
4. What's your cloud storage preference? (S3, Google Cloud, etc.)

### For AI Integration:
1. Should AI have automatic access to recordings or opt-in?
2. Privacy concerns about cloud transcription?
3. Which AI features are most valuable to you?
4. Should recordings be searchable via AI chat?

---

## Recommended Next Steps

### This Week:
1. ✅ Complete Phase 1 (DONE!)
2. Use the merged app for daily work
3. Test Omi integration thoroughly
4. Make note of any bugs or UX issues
5. Think about which Phase 2 features matter most

### Next Week:
1. Review Phase 2 scope based on usage
2. Decide on theme direction
3. Start planning backend API (if doing Phase 3)
4. Consider adding storage interface abstraction now (low effort, high future value)

### Next Month:
1. Begin Phase 2 implementation (if desired)
2. Start backend work for Phase 3 (if ready)
3. Consider testing on additional platforms

---

## Storage Interface - Quick Win

**Recommendation**: Add storage interface NOW (low effort, big future benefit)

**Why?**
- Makes Phase 3 much easier
- No behavior changes, just abstraction
- Already planned in original merger plan
- Takes ~1 hour of work

**How?**
```dart
// 1. Create interface
abstract class IRecordingStorage {
  Future<List<Recording>> getRecordings();
  Future<Recording> getRecording(String id);
  Future<void> saveRecording(Recording recording);
  Future<void> deleteRecording(String id);
  Future<String> getAudioFilePath(String id);
}

// 2. Rename current StorageService to LocalRecordingStorage
class LocalRecordingStorage implements IRecordingStorage {
  // existing implementation
}

// 3. Update providers to use interface
final storageServiceProvider = Provider<IRecordingStorage>((ref) {
  return LocalRecordingStorage();
});
```

This one change makes Phase 3 backend integration trivial - just swap the implementation!

---

**Summary**: Phase 1 is done and working! Take time to use it before diving into Phase 2. The storage interface abstraction is a quick win worth doing soon.
