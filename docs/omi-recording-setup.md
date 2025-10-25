# Omi Device Recording Setup

**Status:** ✅ Working (as of 2025-10-25)

This document describes how Omi device recordings with Opus codec support are configured in the Parachute macOS app.

## Overview

Omi devices use the Opus audio codec (ID 20) for efficient voice recording. The Opus codec requires native library support, which presents challenges on macOS due to sandbox restrictions.

## Solution

We bundle the Opus dynamic library (`libopus.dylib`) with the macOS app to enable Opus decoding.

## Components

### 1. Opus Library Bundle

**Location:** `app/macos/Frameworks/libopus.dylib`

- Source: Homebrew Opus installation (`/opt/homebrew/opt/opus/lib/libopus.0.dylib`)
- Version: libopus 1.5.2
- Size: ~349KB
- Copied from Homebrew installation

### 2. Automated Build Process

**File:** `app/macos/Podfile`

The Podfile's `post_install` hook adds a shell script build phase to the Runner target that automatically copies the Opus library to the app bundle on every build:

```ruby
post_install do |installer|
  # ... other code ...

  # Add build phase to copy Opus library to app bundle
  opus_lib_source = File.join(File.dirname(__FILE__), 'Frameworks', 'libopus.dylib')
  if File.exist?(opus_lib_source)
    # Adds "Copy Opus Library" build phase to Runner target
    # Copies libopus.dylib to app bundle's Frameworks directory
  end
end
```

**Build Phase Script:**
```bash
#!/bin/bash
OPUS_SOURCE="${SRCROOT}/Frameworks/libopus.dylib"
OPUS_DEST="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/libopus.dylib"

if [ -f "$OPUS_SOURCE" ]; then
    mkdir -p "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
    cp "$OPUS_SOURCE" "$OPUS_DEST"
    echo "✅ Opus library copied successfully"
fi
```

### 3. Runtime Loading

**File:** `app/lib/main.dart`

The app loads the Opus library at startup using platform-specific logic:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Opus codec for audio decoding
  try {
    DynamicLibrary library;

    if (Platform.isMacOS) {
      // Load from bundled library (opus_flutter doesn't support macOS)
      library = DynamicLibrary.open('@executable_path/../Frameworks/libopus.dylib');
    } else {
      // Use opus_flutter for Android/iOS/Windows
      library = await opus_flutter.load() as DynamicLibrary;
    }

    opus_dart.initOpus(library);
    debugPrint('[Main] ✅ Opus codec initialized successfully');
  } catch (e) {
    debugPrint('[Main] ❌ Failed to initialize Opus codec: $e');
  }

  runApp(const ProviderScope(child: ParachuteApp()));
}
```

### 4. Opus Decoding

**File:** `app/lib/features/recorder/utils/audio/wav_bytes_util.dart`

When an Omi recording uses Opus codec:

1. `WavBytesUtil` constructor creates a `SimpleOpusDecoder` (requires global `opus` object to be initialized)
2. Audio frames are collected from BLE packets
3. `_processOpus()` decodes Opus frames to PCM samples
4. WAV file is built with decoded PCM data

## Why This Approach?

### Problem: Sandbox Restrictions

macOS sandboxed apps cannot access system libraries outside their container:

```
dlopen(/opt/homebrew/opt/opus/lib/libopus.dylib, 0x0001):
  tried: '/opt/homebrew/opt/opus/lib/libopus.dylib' (file system sandbox blocked open())
```

### Solution: Bundle with App

By bundling the library and loading it from `@executable_path/../Frameworks/`, we:

- Stay within the app sandbox
- Avoid dependency on system Homebrew installation
- Ensure consistent Opus version across deployments
- Enable Opus decoding without additional user setup

## Setup Instructions

### Initial Setup (Already Done)

1. **Copy Opus library to project:**
   ```bash
   mkdir -p app/macos/Frameworks
   cp /opt/homebrew/opt/opus/lib/libopus.0.dylib app/macos/Frameworks/libopus.dylib
   ```

2. **Run pod install to add build phase:**
   ```bash
   cd app/macos
   pod install
   ```

3. **Verify build phase was added:**
   ```bash
   # Should see: "Adding 'Copy Opus Library' build phase to Runner target"
   ```

### Updating Opus Library

If you need to update the bundled Opus library:

```bash
# Update Homebrew Opus
brew upgrade opus

# Copy new version to project
cp /opt/homebrew/opt/opus/lib/libopus.0.dylib app/macos/Frameworks/libopus.dylib

# Rebuild
flutter clean
flutter build macos --debug
```

## Verification

### Check Library is Bundled

After build:
```bash
ls -lh app/build/macos/Build/Products/Debug/app.app/Contents/Frameworks/libopus.dylib
# Should show: -r--r--r-- 1 user staff 349K <date> libopus.dylib
```

### Check Runtime Initialization

App logs should show:
```
[Main] Loading Opus library...
[Main] Platform: macOS - loading Opus library manually
[Main] Trying to load Opus from: @executable_path/../Frameworks/libopus.dylib
[Main] ✅ Successfully loaded Opus from: @executable_path/../Frameworks/libopus.dylib
[Main] ✅ Opus codec initialized successfully
[Main] Opus version: libopus 1.5.2
```

### Test Recording

1. Connect Omi device
2. Press button to start recording
3. Speak for a few seconds
4. Press button to stop

Expected logs:
```
[OmiCaptureService] Audio codec: opus
[WavBytesUtil] Creating with codec: opus
[WavBytesUtil] Creating Opus decoder...
[WavBytesUtil] ✅ Opus decoder created successfully
[WavBytesUtil] Recording started successfully
...
[WavBytesUtil] Decoded 1107 Opus frames to 177120 samples
[WavBytesUtil] Built WAV file: 354284 bytes, 1107 frames, 16000 Hz
[OmiCaptureService] Recording saved: <id>
```

## Troubleshooting

### Library Not Found

**Error:**
```
Failed to load from @executable_path/../Frameworks/libopus.dylib
```

**Solution:**
1. Verify library exists in `app/macos/Frameworks/libopus.dylib`
2. Run `pod install` in `app/macos/`
3. Clean and rebuild: `flutter clean && flutter build macos --debug`

### Opus Not Initialized

**Error:**
```
LateInitializationError: Field 'opus' has not been initialized
```

**Solution:**
- Check app logs for Opus initialization at startup
- Verify `opus_dart.initOpus()` was called successfully
- Ensure library loaded before creating `SimpleOpusDecoder`

### Recording Fails

**Error:**
```
[OmiCaptureService] Error starting recording: <error>
```

**Check:**
1. Opus initialization logs (see Verification section)
2. Device codec: should be `opus` (ID 20)
3. WavBytesUtil logs for decoder creation

## Related Files

- `app/lib/main.dart` - Opus initialization
- `app/lib/features/recorder/utils/audio/wav_bytes_util.dart` - Opus decoding
- `app/lib/features/recorder/services/omi/omi_capture_service.dart` - Recording flow
- `app/macos/Podfile` - Automated library copy
- `app/macos/Frameworks/libopus.dylib` - Bundled library

## Dependencies

- **opus_dart** (^3.0.1): Dart bindings for Opus codec
- **opus_flutter** (^3.0.3): Platform-specific library loading (Android/iOS/Windows only)
- **Homebrew opus**: Source for bundled library

## Notes

- The `opus_flutter` package does **not** support macOS, requiring manual library loading
- The bundled library is committed to git to ensure consistent builds
- Build phase runs on every build (not dependency-based) to ensure library is always present
- Auto-transcribe feature may cause harmless widget disposal errors (fixed in code)
