# llama.cpp Integration Plan for Parachute

> **⚠️ NOTE**: This document describes the challenges with `llama_cpp_dart`. See [flutter-llm-package-comparison.md](./flutter-llm-package-comparison.md) for alternative Flutter LLM packages that may solve these issues.

## Current Status

**Goal**: Run SmolLM2 models on-device for intelligent title generation (and future features)

**Current State**: Infrastructure exists but LLM loading is disabled due to native library bundling complexity.

**What Works**:

- ✅ SmolLM2 model download UI and management
- ✅ Model file storage and tracking
- ✅ Fallback title generation (first 6 words)
- ✅ Service architecture for title generation

**What Doesn't Work**:

- ❌ Loading llama.cpp native libraries at runtime
- ❌ Initializing Llama model from .gguf files
- ❌ Actual on-device inference

---

## Root Cause Analysis

### The Problem

`llama_cpp_dart` package includes pre-built native libraries (`.dylib` files) but doesn't automatically bundle them with the Flutter app. When we try to load them:

1. **Development Mode**: Libraries exist in `~/.pub-cache/` but aren't accessible to running app
2. **Security**: macOS requires code-signed libraries loaded from app bundle
3. **Entitlements**: App needs proper entitlements to load dynamic libraries
4. **Linking**: Libraries have interdependencies that need proper `@rpath` resolution

### Error We Hit

```
LateInitializationError: Field 'context' has not been initialized.
```

This occurs because:

- `Llama()` constructor tries to initialize but can't find/load native library
- Early initialization failure leaves `context` field uninitialized
- App crashes or generates error when trying to use the uninitialized instance

---

## Solution Approaches (Ranked by Complexity)

### Option 1: Use Cloud API for Title Generation ⭐ **RECOMMENDED SHORT-TERM**

**Pros**:

- Works immediately, no native library complexity
- Better quality than small on-device models
- Already have OpenAI API key infrastructure
- Can use Claude API via Anthropic (even better for titles)

**Cons**:

- Requires internet connection
- API costs (minimal for titles: ~$0.0001 per title)
- Privacy concerns (though transcripts already go to OpenAI for transcription)

**Implementation**:

```dart
// Use existing API infrastructure
Future<String?> generateTitleWithAPI(String transcript) async {
  final response = await anthropicClient.messages.create(
    model: 'claude-3-haiku-20240307',
    maxTokens: 20,
    messages: [{
      role: 'user',
      content: 'Generate a 5-8 word title for: "$transcript"'
    }]
  );
  return response.content.first.text;
}
```

**Effort**: 1-2 hours

---

### Option 2: Try Different Flutter LLM Package ⭐ **RECOMMENDED MID-TERM**

> **📄 See detailed comparison**: [flutter-llm-package-comparison.md](./flutter-llm-package-comparison.md)

Several alternatives exist that might have better Flutter integration:

#### A) `flutter_llama` v1.1.2 ⭐ **PRIMARY RECOMMENDATION**

- **Auto-builds native libraries during Flutter build** (solves our main problem!)
- Full Metal GPU acceleration for macOS (3-10x faster)
- Updated 3 days ago (very active)
- Clean streaming and blocking APIs
- Native GGUF support

#### B) `fllama` by Telosnex

- Multi-platform including web
- Metal GPU support
- Commercial support available
- OpenAI-compatible API
- Native bundling approach unclear (needs testing)

#### C) `llm_toolkit`

- Multi-engine support (Llama GGUF, Gemma TFLite)
- RAG capabilities for future features
- Very early stage (v0.0.4)
- Depends on llama_cpp_dart (may inherit same issues)

**Effort**: 4-8 hours of research + implementation

---

### Option 3: Proper Native Library Integration ⭐ **RECOMMENDED LONG-TERM**

Full solution for production app with on-device LLM.

#### Step 1: Xcode Build Phase Integration

Add build phase to automatically copy and process libraries:

**File**: `app/macos/Runner.xcodeproj/project.pbxproj`

Add new shell script phase:

```bash
# Copy llama.cpp Libraries
SOURCE_DIR="${SRCROOT}/Runner/Resources/Frameworks"
DEST_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Frameworks"

mkdir -p "$DEST_DIR"

# Copy libraries
cp -f "${SOURCE_DIR}"/*.dylib "$DEST_DIR/"

# Fix install names and code sign
cd "$DEST_DIR"
for lib in libllama.dylib libggml*.dylib libmtmd.dylib; do
    # Update install name
    install_name_tool -id "@rpath/$lib" "$lib"

    # Update dependencies
    for dep in libggml.dylib libggml-base.dylib libggml-cpu.dylib libggml-blas.dylib libggml-metal.dylib; do
        install_name_tool -change "$dep" "@rpath/$dep" "$lib" 2>/dev/null || true
    done

    # Code sign with app identity
    codesign --force --sign - --timestamp --preserve-metadata=identifier,entitlements "$lib"
done
```

#### Step 2: Update Entitlements

**File**: `app/macos/Runner/DebugProfile.entitlements` and `Release.entitlements`

Add:

```xml
<key>com.apple.security.cs.allow-dyld-environment-variables</key>
<true/>
<key>com.apple.security.cs.disable-library-validation</key>
<true/>
```

**Note**: For App Store, you'll need to justify `disable-library-validation` or package libraries differently.

#### Step 3: Update Info.plist

**File**: `app/macos/Runner/Info.plist`

Add:

```xml
<key>LSMinimumSystemVersion</key>
<string>10.15</string>
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

#### Step 4: Service Implementation

**File**: `app/lib/core/services/title_generation_service.dart`

```dart
Future<void> _ensureModelLoaded(SmolLMModelType? preferredModel) async {
  if (_llama != null && _loadedModel == preferredModel) return;

  final modelToLoad = /* select model logic */;
  final modelPath = await _modelManager.getModelPath(modelToLoad);

  // Set library path - will use bundled libraries
  if (Platform.isMacOS) {
    final executable = Platform.resolvedExecutable;
    final appDir = executable.substring(0, executable.lastIndexOf('/Contents/MacOS/'));
    final libPath = '$appDir/Contents/Frameworks/libllama.dylib';

    if (!await File(libPath).exists()) {
      throw Exception('Native library not found at: $libPath');
    }

    Llama.libraryPath = libPath;
    debugPrint('Using llama library: $libPath');
  }

  // Initialize with proper parameters
  try {
    _llama = Llama(
      modelPath,
      ModelParams(),
      ContextParams(),
      SamplerParams(),
      false, // not verbose in production
    );

    _loadedModel = modelToLoad;
  } catch (e) {
    debugPrint('Failed to load model: $e');
    _llama = null;
    _loadedModel = null;
    rethrow;
  }
}
```

#### Step 5: Testing Checklist

- [ ] Libraries copied to app bundle on build
- [ ] Libraries properly code-signed
- [ ] App launches without crash
- [ ] `Llama.libraryPath` points to valid file
- [ ] Model file (.gguf) is accessible
- [ ] Model initializes without `LateInitializationError`
- [ ] Can generate text from model
- [ ] Title generation works end-to-end

**Effort**: 1-2 days of focused work

---

### Option 4: Flutter Web Assembly Approach

For truly universal deployment, compile llama.cpp to WebAssembly:

**Pros**:

- Works across all platforms (macOS, iOS, Linux, Web)
- No native library bundling issues
- Sandboxed and secure

**Cons**:

- Performance hit (~2-3x slower than native)
- Requires significant WASM expertise
- Not many ready-made solutions

**Effort**: 1-2 weeks

---

## Recommended Roadmap

### Phase 1: Short-term (This Week)

**Goal**: Get intelligent title generation working

**Approach**: Option 1 - Cloud API

- Use Claude 3 Haiku for title generation
- Fast, cheap ($0.25 per million input tokens)
- High quality titles
- ~2 hours implementation

### Phase 2: Mid-term (Next Month)

**Goal**: Evaluate on-device feasibility

**Research Tasks**:

1. Test Option 2B: Try `flutter_llama` or similar packages
2. Prototype Option 3: Xcode integration with test app
3. Benchmark: Is SmolLM-360M fast enough on Apple Silicon?
4. Decision: Cloud vs. on-device based on results

### Phase 3: Long-term (Future Release)

**Goal**: Production-ready on-device LLM

**If on-device makes sense**:

- Implement Option 3 fully with proper signing
- Add App Store-compatible entitlements
- Support multiple model sizes
- Add model caching and optimization

**If cloud makes more sense**:

- Optimize API calls (batch, cache common patterns)
- Add offline fallback (simple title generation)
- Consider self-hosted LLM for privacy option

---

## Decision Matrix

| Factor              | Cloud API  | flutter_llama | Native Integration | WASM       |
| ------------------- | ---------- | ------------- | ------------------ | ---------- |
| **Time to working** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐        | ⭐⭐               | ⭐         |
| **Code complexity** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐      | ⭐⭐               | ⭐         |
| **Title quality**   | ⭐⭐⭐⭐⭐ | ⭐⭐⭐        | ⭐⭐⭐             | ⭐⭐⭐     |
| **Speed**           | ⭐⭐⭐     | ⭐⭐⭐⭐      | ⭐⭐⭐⭐⭐         | ⭐⭐⭐     |
| **Privacy**         | ⭐⭐       | ⭐⭐⭐⭐⭐    | ⭐⭐⭐⭐⭐         | ⭐⭐⭐⭐⭐ |
| **Cost**            | ⭐⭐⭐⭐   | ⭐⭐⭐⭐⭐    | ⭐⭐⭐⭐⭐         | ⭐⭐⭐⭐⭐ |
| **Cross-platform**  | ⭐⭐⭐⭐⭐ | ⭐⭐⭐        | ⭐⭐               | ⭐⭐⭐⭐⭐ |
| **Offline support** | ⭐         | ⭐⭐⭐⭐⭐    | ⭐⭐⭐⭐⭐         | ⭐⭐⭐⭐⭐ |

---

## Next Steps

**Immediate** (You're here):

1. ✅ Commit current work with fallback title generation
2. ✅ Create this plan document
3. ⬜ Decide: Cloud API vs. continue on-device work

**If choosing Cloud API**:

1. Add Anthropic SDK dependency
2. Implement title generation with Claude Haiku
3. Test and polish
4. Ship feature

**If choosing on-device**:

1. Create minimal test app with just llama_cpp_dart
2. Get "Hello World" inference working
3. Document exact steps that worked
4. Apply to Parachute app
5. Complete Phase 3 checklist above

---

## Resources

- [llama_cpp_dart GitHub](https://github.com/netdur/llama_cpp_dart)
- [llama.cpp Documentation](https://github.com/ggerganov/llama.cpp)
- [Flutter FFI Plugin Guide](https://docs.flutter.dev/platform-integration/macos/c-interop)
- [macOS Code Signing Guide](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code)
- [SmolLM2 Model Cards](https://huggingface.co/collections/HuggingFaceTB/smollm2-6723884218bcda64b34d7db9)

---

**Last Updated**: October 31, 2025
**Status**: Plan created, awaiting decision on approach
