# Parachute Recorder Merger Plan

**Goal**: Merge the standalone voice recorder app (~/Symbols/Codes/recorder) into the Parachute app as a unified Flutter application with bottom navigation between AI Chat and Voice Recorder features.

**Status**: Phase 1 - Planning
**Last Updated**: 2025-10-25

---

## Overview

This document outlines the plan to merge two Flutter applications:
- **Parachute** (`~/Symbols/Codes/parachute/app`) - AI chat interface with ACP backend integration
- **Recorder** (`~/Symbols/Codes/recorder`) - Voice recorder with Omi hardware support and local Whisper transcription

The merger will happen in phases:

### Phase 1: Basic Merge (THIS PHASE)
Copy recorder code into Parachute with minimal changes. Create bottom navigation to switch between AI Chat and Voice Recorder sections. Keep features completely separate with no integration.

### Phase 2: Visual Unification (FUTURE)
Harmonize themes, styles, and navigation to feel like one cohesive app.

### Phase 3: Backend Integration (FUTURE)
Connect recorder to Parachute backend for cloud storage, sync, and cross-device access.

---

## Phase 1: Basic Merge - Detailed Plan

### 1. Directory Structure

```
app/
├── lib/
│   ├── main.dart                          # NEW: Main entry with bottom nav
│   ├── core/                              # Existing Parachute core
│   │   ├── config/
│   │   ├── constants/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── router/
│   │   ├── services/
│   │   └── theme/
│   ├── features/
│   │   ├── auth/                          # Existing Parachute feature
│   │   ├── chat/                          # Existing Parachute feature
│   │   ├── conversations/                 # Existing Parachute feature
│   │   ├── settings/                      # Existing Parachute feature
│   │   ├── spaces/                        # Existing Parachute feature
│   │   └── recorder/                      # NEW: All recorder code
│   │       ├── models/
│   │       │   ├── recording.dart
│   │       │   ├── omi_device.dart
│   │       │   └── whisper_models.dart
│   │       ├── providers/
│   │       │   ├── omi_providers.dart
│   │       │   └── service_providers.dart
│   │       ├── repositories/
│   │       │   └── recording_repository.dart
│   │       ├── screens/
│   │       │   ├── home_screen.dart       # Recorder home
│   │       │   ├── recording_screen.dart
│   │       │   ├── post_recording_screen.dart
│   │       │   ├── recording_detail_screen.dart
│   │       │   ├── device_pairing_screen.dart
│   │       │   └── settings_screen.dart
│   │       ├── services/
│   │       │   ├── audio_service.dart
│   │       │   ├── notification_service.dart
│   │       │   ├── storage_service.dart
│   │       │   ├── whisper_service.dart
│   │       │   ├── whisper_local_service.dart
│   │       │   ├── whisper_model_manager.dart
│   │       │   └── omi/
│   │       │       ├── omi_connection.dart
│   │       │       ├── omi_bluetooth_service.dart
│   │       │       ├── device_connection.dart
│   │       │       └── omi_firmware_service.dart
│   │       ├── utils/
│   │       │   ├── platform_utils.dart
│   │       │   ├── validators.dart
│   │       │   └── audio/
│   │       │       └── wav_bytes_util.dart
│   │       └── widgets/
│   │           └── recording_tile.dart    # And any other widgets
│   └── shared/                            # Existing Parachute shared
│       ├── models/
│       ├── services/
│       └── widgets/
└── assets/
    └── firmware/                          # NEW: Omi firmware files
```

### 2. Package Name Strategy

**Current State:**
- Parachute app uses `package:app/...`
- Recorder app uses `package:parachute/...`

**Resolution:**
All recorder code will be updated to use `package:app/...` during the copy. This requires a find-and-replace operation on all imports within recorder files.

### 3. Main App Structure

Create new `main.dart` with bottom navigation:

```dart
// app/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/spaces/screens/space_list_screen.dart';
import 'features/recorder/screens/home_screen.dart' as recorder;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize recorder-specific services (Opus codec, etc.)
  // ... initialization code from recorder main.dart

  runApp(const ProviderScope(child: ParachuteApp()));
}

class ParachuteApp extends StatelessWidget {
  const ParachuteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parachute',
      theme: ThemeData(...), // Use Parachute's existing theme for now
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const SpaceListScreen(),        // Parachute AI Chat
    const recorder.HomeScreen(),    // Voice Recorder
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'AI Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mic),
            label: 'Recorder',
          ),
        ],
      ),
    );
  }
}
```

### 4. Dependencies Merger

**Strategy**: Merge both `pubspec.yaml` files, resolving version conflicts by choosing the newer version.

**New Dependencies to Add (from recorder):**
```yaml
dependencies:
  # Audio & Recording
  record: ^6.1.2
  just_audio: ^0.9.42

  # Permissions
  permission_handler: ^12.0.0

  # Omi Device Integration
  flutter_blue_plus: ^1.33.6
  flutter_local_notifications: ^17.0.0

  # Audio Codecs (for Omi)
  opus_dart: ^3.0.1
  opus_flutter: ^3.0.3

  # Local Whisper Transcription
  whisper_ggml: ^1.7.0

  # OTA Firmware Updates
  nordic_dfu: ^6.1.4

  # Utilities (check versions)
  collection: ^1.18.0
  google_fonts: ^6.1.0
  file_picker: ^8.0.0+1
  url_launcher: ^6.3.0

assets:
  flutter:
    assets:
      - assets/firmware/
```

**Version Conflicts to Resolve:**
- `uuid`: Parachute uses ^4.0.0, Recorder uses ^4.4.0 → Use ^4.4.0
- `flutter_riverpod`: Parachute uses ^2.5.0, Recorder uses ^2.6.1 → Use ^2.6.1
- `riverpod_annotation`: Parachute uses ^2.3.5, Recorder uses ^2.6.1 → Use ^2.6.1
- `riverpod_generator`: Parachute uses ^2.4.0, Recorder uses ^2.6.2 → Use ^2.6.2

### 5. Import Rewriting Strategy

All files copied from recorder need their imports updated:
- `package:parachute/` → `package:app/features/recorder/`
- Internal recorder imports need path adjustments

**Example:**
```dart
// OLD (recorder)
import 'package:parachute/models/recording.dart';
import 'package:parachute/services/audio_service.dart';

// NEW (merged parachute)
import 'package:app/features/recorder/models/recording.dart';
import 'package:app/features/recorder/services/audio_service.dart';
```

### 6. Theme Handling

**Phase 1 Approach**: Keep both themes separate initially.

- Parachute uses Material3 with ColorScheme.fromSeed (light blue)
- Recorder uses custom theme with Google Fonts (forest green/nature theme)

**Implementation:**
- Copy `recorder/lib/theme.dart` → `app/lib/features/recorder/theme.dart`
- Recorder screens will reference their own theme when needed
- Main app uses Parachute theme
- Phase 2 will harmonize these

### 7. Assets Migration

Copy recorder assets:
```bash
cp -r ~/Symbols/Codes/recorder/assets/firmware ~/Symbols/Codes/parachute/app/assets/
```

Update `pubspec.yaml` to include firmware assets.

### 8. Platform-Specific Configuration

Recorder requires additional permissions and configurations:

**iOS (Info.plist additions):**
- Microphone permissions
- Bluetooth permissions
- Background audio modes
- Local network permissions (for Omi)

**Android (AndroidManifest.xml additions):**
- RECORD_AUDIO
- BLUETOOTH permissions
- WAKE_LOCK
- FOREGROUND_SERVICE

**macOS:**
- Microphone entitlements
- Bluetooth entitlements

These will need to be merged into Parachute's existing platform configs.

### 9. Navigation Integration

**Parachute's Current Navigation:**
- Uses simple route-based navigation
- Routes: `/`, `/conversations`, `/chat`

**Recorder's Current Navigation:**
- Direct Navigator.push calls
- No named routes

**Phase 1 Solution:**
- Keep recorder's navigation style within recorder feature
- Recorder screens remain accessible via Navigator.push
- Bottom nav handles top-level switching only

### 10. State Management Coexistence

Both apps use Riverpod but with different provider patterns:

**Parachute**: Uses generated providers with riverpod_annotation
**Recorder**: Uses manual providers

**Phase 1 Approach**: Both patterns coexist without conflict. All recorder providers stay scoped to `features/recorder/providers/`.

---

## Implementation Steps

### Step 1: Prepare Parachute Repository
- [ ] Create `app/lib/features/recorder/` directory structure
- [ ] Backup current `main.dart` as `main.dart.backup`
- [ ] Create `docs/merger-plan.md` (this file)

### Step 2: Copy Recorder Code
- [ ] Copy all recorder `lib/` contents to `app/lib/features/recorder/`
- [ ] Copy recorder `assets/firmware/` to `app/assets/firmware/`
- [ ] Copy recorder firmware documentation if needed

### Step 3: Update Imports
- [ ] Run find-and-replace on all copied files: `package:parachute/` → `package:app/features/recorder/`
- [ ] Verify import correctness with static analysis
- [ ] Fix any remaining import issues manually

### Step 4: Merge Dependencies
- [ ] Update `app/pubspec.yaml` with recorder dependencies
- [ ] Resolve version conflicts (use newer versions)
- [ ] Add assets configuration for firmware files
- [ ] Run `flutter pub get`
- [ ] Verify no dependency conflicts

### Step 5: Create Main Navigation
- [ ] Write new `main.dart` with bottom navigation
- [ ] Import both SpaceListScreen and recorder.HomeScreen
- [ ] Add initialization code from recorder's main (Opus codec, error handling)
- [ ] Test navigation between tabs

### Step 6: Platform Configuration
- [ ] Merge iOS Info.plist entries (permissions)
- [ ] Merge Android manifest entries (permissions)
- [ ] Merge macOS entitlements
- [ ] Update any build configuration files

### Step 7: Testing
- [ ] Test Parachute features (AI chat, spaces, conversations)
- [ ] Test recorder features (record, playback, Omi pairing)
- [ ] Test navigation between sections
- [ ] Test on macOS (primary platform)
- [ ] Test on iOS if possible
- [ ] Test on Android if possible

### Step 8: Documentation
- [ ] Update main README.md to reflect merged app
- [ ] Update ARCHITECTURE.md with recorder feature
- [ ] Create CLAUDE.md in `features/recorder/` with specific context
- [ ] Document known issues or limitations

### Step 9: Cleanup
- [ ] Remove `.bak` files from recorder code (e.g., recording_screen.dart.bak)
- [ ] Verify no unused imports or dead code
- [ ] Run `flutter analyze` and fix warnings
- [ ] Run `flutter test` to ensure existing tests pass

### Step 10: User Validation
- [ ] Ask user to test AI chat functionality
- [ ] Ask user to test recorder functionality
- [ ] Address any issues found
- [ ] Get user approval before committing

### Step 11: Git Commit
- [ ] Stage all changes
- [ ] Create detailed commit message explaining merger
- [ ] Push to repository
- [ ] Consider tagging as `v1.0.0-merged` or similar

---

## Known Challenges & Mitigations

### Challenge 1: Import Path Complexity
**Issue**: Recorder has many internal cross-references that need updating.
**Mitigation**: Use careful find-and-replace with verification. Test incrementally.

### Challenge 2: Theme Conflicts
**Issue**: Two different theme systems might cause visual inconsistency.
**Mitigation**: Accept inconsistency in Phase 1. Resolve in Phase 2.

### Challenge 3: Provider Naming Conflicts
**Issue**: Both apps might have providers with similar names.
**Mitigation**: Recorder providers stay in `features/recorder/providers/` namespace. Use explicit imports if needed.

### Challenge 4: Build Time Increase
**Issue**: Adding Whisper, Opus, and other heavy dependencies increases build time.
**Mitigation**: Accept this trade-off. Consider lazy loading in future phases.

### Challenge 5: Platform Permission Conflicts
**Issue**: Merging permission requests might cause issues.
**Mitigation**: Carefully merge platform config files. Test permission flows on each platform.

### Challenge 6: Riverpod Version Update
**Issue**: Upgrading Riverpod might break existing Parachute providers.
**Mitigation**: Test all Parachute features after dependency update. Fix any breaking changes.

---

## Phase 2 Preview: Visual Unification (Future)

**Goals:**
- Harmonize color schemes between AI chat and recorder
- Create unified theme that works for both features
- Improve bottom navigation with better icons and styling
- Unify settings screens (merge recorder settings into Parachute settings)
- Create consistent navigation patterns throughout app
- Polish transitions and animations

**Out of Scope for Phase 1**

---

## Phase 3 Preview: Backend Integration (Future)

**Goals:**
- Upload recordings to Parachute backend
- Store recordings in backend database
- Enable cross-device sync of recordings
- Allow AI chat to reference recordings
- Implement cloud transcription using backend
- Create APIs for recording management

**Backend Changes Needed:**
- New database tables for recordings
- File storage service (S3 or similar)
- Recording upload/download endpoints
- Transcription integration with Claude or Whisper API
- WebSocket updates for recording status

**Out of Scope for Phase 1**

---

## Testing Checklist

### Parachute Features (Regression Testing)
- [ ] Can create new space
- [ ] Can view space list
- [ ] Can create conversation in space
- [ ] Can send messages in chat
- [ ] Can receive streaming responses from Claude
- [ ] WebSocket connection works
- [ ] Settings screen accessible and functional

### Recorder Features (New Functionality)
- [ ] Can start new recording
- [ ] Can stop recording and save
- [ ] Can play back recordings
- [ ] Can view recording list
- [ ] Can delete recordings
- [ ] Can pair with Omi device (if hardware available)
- [ ] Can download Whisper models
- [ ] Can transcribe recordings locally
- [ ] Settings screen works

### Integration Testing
- [ ] Bottom navigation switches between AI Chat and Recorder
- [ ] State persists when switching tabs
- [ ] App doesn't crash when rapidly switching tabs
- [ ] Both features can run simultaneously (e.g., recording while chat is open)
- [ ] Permissions are granted correctly for both features

---

## Success Criteria

Phase 1 is complete when:
1. All recorder code is copied into Parachute repository
2. App builds and runs without errors
3. Bottom navigation allows switching between AI Chat and Recorder
4. All existing Parachute features work correctly
5. All recorder features work correctly
6. No major visual bugs or crashes
7. User has tested and approved functionality
8. Changes are committed to git

---

## Next Steps After Phase 1

1. Use the merged app for a while to identify pain points
2. Gather user feedback on the dual-feature experience
3. Plan Phase 2 (visual unification) based on usage patterns
4. Start designing backend API for recording storage
5. Consider additional features that benefit from integration (e.g., "transcribe and send to AI chat")

---

## Questions / Decisions Needed

### Resolved:
- ✅ App name: Parachute
- ✅ Navigation: Bottom navigation bar (Option A)
- ✅ Package name: Use `app` for merged codebase
- ✅ Directory structure: `features/recorder/` pattern
- ✅ Asset management: Copy firmware assets as-is

### Open Questions:
- ✅ Backend integration separation points: YES - Create abstract interfaces for storage service to make Phase 3 easier
- Platform priority: Which platform should we test most thoroughly? (macOS assumed, but confirm)
- Recorder theme: Should we make ANY theme adjustments in Phase 1, or strictly keep everything separate?

---

## Appendix: File Mapping

Complete mapping of recorder files to their new locations:

| Recorder Path | New Parachute Path |
|---------------|-------------------|
| `lib/main.dart` | (Logic merged into new `app/lib/main.dart`) |
| `lib/theme.dart` | `app/lib/features/recorder/theme.dart` |
| `lib/models/*.dart` | `app/lib/features/recorder/models/*.dart` |
| `lib/providers/*.dart` | `app/lib/features/recorder/providers/*.dart` |
| `lib/repositories/*.dart` | `app/lib/features/recorder/repositories/*.dart` |
| `lib/screens/*.dart` | `app/lib/features/recorder/screens/*.dart` |
| `lib/services/*.dart` | `app/lib/features/recorder/services/*.dart` |
| `lib/services/omi/*.dart` | `app/lib/features/recorder/services/omi/*.dart` |
| `lib/utils/*.dart` | `app/lib/features/recorder/utils/*.dart` |
| `lib/utils/audio/*.dart` | `app/lib/features/recorder/utils/audio/*.dart` |
| `lib/widgets/*.dart` | `app/lib/features/recorder/widgets/*.dart` |
| `assets/firmware/` | `app/assets/firmware/` |

---

**End of Plan**
