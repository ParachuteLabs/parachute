# Flutter On-Device LLM Package Comparison

**Purpose**: Evaluate alternative Flutter packages for on-device LLM inference to replace problematic `llama_cpp_dart` integration.

**Context**: Parachute needs to run SmolLM2 models (135M-1.7B params) locally for title generation and future AI features. Current `llama_cpp_dart` implementation requires manual native library bundling, code signing, and causes app crashes.

**Date**: October 31, 2025

---

## TL;DR Recommendation

**Primary Recommendation: `flutter_llama` v1.1.2**
- ✅ Auto-builds native libraries during Flutter build (no manual bundling)
- ✅ Full Metal GPU acceleration for macOS (3-10x faster)
- ✅ Active development (updated 3 days ago)
- ✅ Native GGUF support via llama.cpp
- ✅ Supports Android, iOS, macOS
- ✅ Streaming and blocking generation APIs
- ⚠️ Newer package, smaller community

**Alternative: `fllama` by Telosnex**
- ✅ Commercial support available
- ✅ Multi-platform including web
- ✅ Metal GPU support
- ✅ OpenAI-compatible API
- ⚠️ Git dependency (not pub.dev)
- ⚠️ Native bundling approach unclear

---

## Detailed Package Comparison

### 1. flutter_llama

**Version**: 1.1.2 (published 3 days ago)

**Platform Support**:
- ✅ Android (Vulkan GPU: 4-8x faster)
- ✅ iOS (Metal GPU: 3-10x faster)
- ✅ macOS (Metal GPU: 3-10x faster)

**Native Library Bundling**: **Auto-builds during Flutter build**
- iOS framework builds automatically when building Flutter app
- Android native library builds automatically using CMake/NDK
- **This solves our primary pain point with llama_cpp_dart**

**GGUF Model Support**: ✅ Yes, via llama.cpp

**Metal Acceleration**: ✅ Full Metal support for iOS/macOS
```dart
LlamaConfig(
  modelPath: modelPath,
  nGpuLayers: -1,      // Auto-detect GPU
  useGpu: true,        // Enable Metal
  nThreads: 4,
  nCtx: 2048,
)
```

**API Design**:
```dart
// Load model
await FlutterLlama.loadModel(config);

// Blocking generation
final result = await FlutterLlama.generate(
  prompt: "Generate a title: $transcript",
  maxTokens: 20,
);

// Streaming generation
await for (final token in FlutterLlama.generateStream(prompt)) {
  print(token);
}
```

**Memory Efficiency**: Returns token count and generation speed metrics

**Recommended Models**: "braindler" from Ollama (72MB-256MB)

**Installation**:
```yaml
dependencies:
  flutter_llama: ^1.1.2
```

**Pros**:
- ✅ Auto-builds native libraries (no manual bundling!)
- ✅ Very recent updates (actively maintained)
- ✅ Full Metal GPU acceleration
- ✅ Clean, simple API
- ✅ Performance metrics included
- ✅ Streaming support for future chat features

**Cons**:
- ⚠️ Newer package (less battle-tested)
- ⚠️ Smaller community vs llama_cpp_dart
- ⚠️ Documentation could be more extensive

**SmolLM2 Compatibility**: Should work perfectly - uses standard llama.cpp backend

---

### 2. fllama (by Telosnex)

**Version**: Git main branch (no stable pub.dev release)

**Platform Support**:
- ✅ Web (via WASM)
- ✅ iOS (Metal)
- ✅ macOS (Metal)
- ✅ Android
- ✅ Windows
- ✅ Linux

**Native Library Bundling**: **Unclear - requires investigation**
- Platform-specific directories exist (macos/, ios/, etc.)
- Documentation doesn't specify if auto-bundled
- May require manual setup similar to llama_cpp_dart

**GGUF Model Support**: ✅ Yes, "Any model compatible with llama.cpp"

**Metal Acceleration**: ✅ Yes, explicitly mentioned

**API Design**: OpenAI-compatible chat API
```dart
fllamaChat(request, (response, done) {
  setState(() {
    latestResult = response;
  });
});
```

**Advanced Features**:
- Function calling support
- Multimodal image support (LLaVa models)
- Web support via WASM compilation

**Installation**:
```yaml
dependencies:
  fllama:
    git:
      url: https://github.com/Telosnex/fllama.git
      ref: main
```

**Pros**:
- ✅ Most comprehensive platform support (including web)
- ✅ Commercial support available (info@telosnex.com)
- ✅ OpenAI-compatible API
- ✅ Advanced features (function calling, multimodal)
- ✅ Metal GPU support

**Cons**:
- ⚠️ Git dependency (not on pub.dev)
- ⚠️ Native bundling approach unclear
- ⚠️ More complex setup for C++ binding updates
- ⚠️ Web support requires emscripten SDK
- ⚠️ May have same bundling issues as llama_cpp_dart

**SmolLM2 Compatibility**: Should work (uses llama.cpp)

---

### 3. llm_toolkit

**Version**: 0.0.4 (published 3 months ago)

**Platform Support**:
- ✅ Android
- ✅ iOS
- ✅ Windows
- ✅ macOS
- ✅ Linux

**Native Library Bundling**: **Unknown**
- Dependencies include `llama_cpp_dart: ^0.0.9`
- May inherit same bundling issues

**GGUF Model Support**: ✅ Via Llama engine

**Multi-Engine Support**:
- Llama (GGUF files)
- Gemma (TFLite)
- Generic TFLite models

**Advanced Features**:
- Model discovery and download from Hugging Face
- RAG (Retrieval-Augmented Generation)
- Speech recognition with Whisper
- Streaming generation

**API Design**:
```dart
await LLMToolkit.instance.loadModel(
  '/path/to/model.gguf',
  config: InferenceConfig.mobile(),
);

await for (final chunk in LLMToolkit.instance.generateStream(prompt)) {
  // Process chunks
}
```

**Installation**:
```yaml
dependencies:
  llm_toolkit: ^0.0.4
```

**Pros**:
- ✅ Multi-engine support (flexible)
- ✅ RAG capabilities for future knowledge features
- ✅ Hugging Face integration
- ✅ Whisper support (voice-to-text)

**Cons**:
- ⚠️ Very early stage (v0.0.4)
- ⚠️ Low adoption (110 downloads, 5 likes)
- ⚠️ Depends on llama_cpp_dart (may have same issues)
- ⚠️ Last updated 3 months ago
- ⚠️ Memory optimization required for mobile

**SmolLM2 Compatibility**: Should work via Llama engine

---

### 4. flutter_gemma

**Version**: 0.11.8 (published 9 days ago)

**Platform Support**:
- ✅ Android
- ✅ iOS
- ✅ Web

**GGUF Model Support**: ❌ **No** - This is a deal-breaker

**Supported Models**:
- Gemma (2B, 7B), Gemma-2, Gemma-3
- TinyLlama, Llama 3.2, Phi series
- DeepSeek, Qwen2.5
- Requires `.task`, `.litertlm`, or `.bin/.tflite` files

**API Design**: MediaPipe GenAI-based

**Pros**:
- ✅ Very active development (updated 9 days ago)
- ✅ Built on MediaPipe (optimized for mobile)
- ✅ Web support

**Cons**:
- ❌ No GGUF support
- ❌ Cannot use SmolLM2 models directly
- ❌ Requires model conversion to TFLite

**SmolLM2 Compatibility**: ❌ No - would require converting to TFLite

---

### 5. llama_cpp_dart (Current)

**Version**: 0.0.9

**Platform Support**: Dart/Flutter (all platforms theoretically)

**Native Library Bundling**: ❌ **Manual** - This is our current problem

**Issues Encountered**:
1. Libraries not auto-bundled in app
2. Need manual copying to app Resources/Frameworks
3. Requires `install_name_tool` to fix library paths
4. Code signing issues
5. App crashes on launch
6. Security entitlements needed

**GGUF Model Support**: ✅ Yes, direct llama.cpp bindings

**Pros**:
- ✅ Direct llama.cpp bindings (most control)
- ✅ GGUF support
- ✅ Documentation available

**Cons**:
- ❌ Manual native library bundling required
- ❌ Complex macOS setup
- ❌ No auto-build of native libraries
- ❌ Code signing challenges
- ❌ Caused app crashes in Parachute

---

## Decision Matrix

| Feature | flutter_llama | fllama | llm_toolkit | flutter_gemma | llama_cpp_dart |
|---------|---------------|--------|-------------|---------------|----------------|
| **Auto-bundles native libs** | ✅ Yes | ❓ Unknown | ❓ Unknown | ✅ Yes | ❌ No |
| **GGUF support** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **macOS support** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Metal GPU acceleration** | ✅ Yes | ✅ Yes | ❓ Unknown | ✅ Yes | ✅ Yes |
| **Active development** | ✅ 3 days ago | ✅ Active | ⚠️ 3 months | ✅ 9 days | ⚠️ Older |
| **Streaming API** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **Pub.dev release** | ✅ Yes | ❌ Git only | ✅ Yes | ✅ Yes | ✅ Yes |
| **SmolLM2 compatible** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No | ✅ Yes |
| **Ease of setup** | ✅ Easy | ❓ Unknown | ⚠️ Complex | ✅ Easy | ❌ Hard |
| **Community size** | ⚠️ Small | ⚠️ Small | ⚠️ Very small | ✅ Medium | ✅ Medium |

---

## Recommended Implementation Plan

### Phase 1: Quick Test (1-2 hours)

1. **Create test Flutter app with `flutter_llama`**
   ```bash
   flutter create llama_test
   cd llama_test
   ```

2. **Add dependency to `pubspec.yaml`**
   ```yaml
   dependencies:
     flutter_llama: ^1.1.2
   ```

3. **Test with SmolLM2-360M model**
   - Download from bartowski's repo
   - Test model loading
   - Test title generation
   - Verify Metal GPU acceleration
   - Check app bundle size

4. **Success criteria**:
   - ✅ App builds without manual library copying
   - ✅ Model loads successfully
   - ✅ Generation works
   - ✅ No crashes
   - ✅ Reasonable performance

### Phase 2: Integration into Parachute (2-3 hours)

1. **Replace `llama_cpp_dart` dependency**
   ```yaml
   # Remove:
   # llama_cpp_dart: ^0.0.9

   # Add:
   flutter_llama: ^1.1.2
   ```

2. **Update `TitleGenerationService`**
   - Replace llama_cpp_dart imports with flutter_llama
   - Update model loading code
   - Update generation code
   - Add Metal GPU configuration

3. **Update `SmolLMModelManager`**
   - Keep download functionality
   - Update model path handling for flutter_llama

4. **Test thoroughly before user testing**
   - Clean build
   - Model download
   - Title generation
   - Multiple recordings
   - App restart with model loaded

### Phase 3: Fallback Strategy (if flutter_llama fails)

**Option A**: Try `fllama`
- Similar approach
- More features but less clear on bundling
- Commercial support available

**Option B**: Cloud API interim solution
- Use Claude API for title generation
- Fast, reliable, no local setup
- Replace with on-device later

**Option C**: Hybrid approach
- Cloud API when network available
- Local fallback (first 6 words) when offline
- Best user experience

---

## Expected Outcomes

### Best Case (flutter_llama works)
- ✅ On-device title generation working
- ✅ No manual library bundling needed
- ✅ Metal GPU acceleration (fast)
- ✅ Foundation for future AI features
- ✅ User owns their data (local inference)

### Worst Case (flutter_llama fails)
- ⚠️ Same bundling issues as llama_cpp_dart
- ⚠️ Need to try fllama or cloud API
- ⚠️ More research required

### Most Likely Case
- ✅ flutter_llama works but requires some tweaking
- ✅ Better than llama_cpp_dart but not perfect
- ✅ Enables on-device LLM with reasonable effort

---

## Next Steps

1. **User Decision**: Choose approach
   - **Recommended**: Test flutter_llama (Phase 1)
   - **Alternative**: Try fllama
   - **Pragmatic**: Cloud API interim + local later

2. **If testing flutter_llama**:
   - Create minimal test app
   - Verify auto-bundling works
   - Test SmolLM2 models
   - Report findings before Parachute integration

3. **If cloud API interim**:
   - Quick implementation with Claude API
   - Works immediately
   - Defer on-device to future when better solutions emerge

---

## References

- flutter_llama: https://pub.dev/packages/flutter_llama
- fllama: https://github.com/Telosnex/fllama
- llm_toolkit: https://pub.dev/packages/llm_toolkit
- flutter_gemma: https://pub.dev/packages/flutter_gemma
- Maid (reference app): https://github.com/Mobile-Artificial-Intelligence/maid
- SmolLM2 models: https://huggingface.co/bartowski (GGUF quantized versions)

---

**Last Updated**: October 31, 2025
