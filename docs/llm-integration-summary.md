# LLM Integration Research Summary

**Date**: October 31, 2025
**Context**: Research into Flutter packages for on-device LLM inference to replace problematic `llama_cpp_dart`

---

## The Problem

Parachute needs on-device title generation using SmolLM2 models. Current `llama_cpp_dart` implementation fails due to:

1. ❌ Native libraries not auto-bundled in Flutter app
2. ❌ Manual library copying and code signing required
3. ❌ App crashes on launch when attempting to load models
4. ❌ Complex macOS security entitlements needed

---

## The Solution: `flutter_llama` v1.1.2

**Recommendation**: Test `flutter_llama` as primary candidate

### Why This Package?

✅ **Auto-builds native libraries** during Flutter build (solves our main issue!)
✅ **Active development** - updated 3 days ago
✅ **Full Metal GPU acceleration** for macOS (3-10x faster)
✅ **Native GGUF support** via llama.cpp
✅ **Clean API** - simple streaming and blocking generation
✅ **Cross-platform** - Android, iOS, macOS
✅ **On pub.dev** - stable package management

### Quick Start

```yaml
# pubspec.yaml
dependencies:
  flutter_llama: ^1.1.2
```

```dart
// Load model
await FlutterLlama.loadModel(LlamaConfig(
  modelPath: modelPath,
  nGpuLayers: -1,      // Auto-detect Metal GPU
  useGpu: true,        // Enable acceleration
  nThreads: 4,
  nCtx: 2048,
));

// Generate title
final result = await FlutterLlama.generate(
  prompt: "Generate a concise title: $transcript",
  maxTokens: 20,
);
```

---

## Alternative Options

### 1. `fllama` by Telosnex
- Multi-platform including web
- Commercial support available
- Native bundling approach unclear (needs testing)
- Git dependency only (not on pub.dev)

### 2. Cloud API (Interim Solution)
- Use Claude Haiku for title generation
- Works immediately (~2 hours implementation)
- High quality, minimal cost ($0.0001 per title)
- Requires internet connection

### 3. `llm_toolkit`
- Multi-engine support (GGUF + TFLite)
- Very early stage (v0.0.4)
- Depends on llama_cpp_dart (may have same issues)

---

## Recommended Next Steps

### Phase 1: Quick Test (1-2 hours)

1. Create minimal Flutter test app
2. Add `flutter_llama: ^1.1.2` dependency
3. Test with SmolLM2-360M model
4. Verify auto-bundling works on macOS
5. Check Metal GPU acceleration

**Success Criteria**:
- ✅ App builds without manual library copying
- ✅ Model loads successfully
- ✅ Title generation works
- ✅ No crashes

### Phase 2: Integration (2-3 hours)

If Phase 1 succeeds:
1. Replace `llama_cpp_dart` with `flutter_llama` in Parachute
2. Update `TitleGenerationService`
3. Update model loading in `SmolLMModelManager`
4. Test thoroughly before user testing

### Phase 3: Fallback Plan

If `flutter_llama` fails:
- **Option A**: Try `fllama` package
- **Option B**: Implement cloud API interim solution
- **Option C**: Hybrid (cloud + fallback when offline)

---

## References

- **Detailed Comparison**: [flutter-llm-package-comparison.md](./flutter-llm-package-comparison.md)
- **llama_cpp_dart Issues**: [llama-cpp-integration-plan.md](./llama-cpp-integration-plan.md)
- **flutter_llama Package**: https://pub.dev/packages/flutter_llama
- **SmolLM2 Models**: https://huggingface.co/bartowski (GGUF quantized)

---

## Decision Point

**Question for user**: Which approach to take?

1. ⭐ **Test flutter_llama** (recommended - likely solves our problem)
2. **Cloud API interim** (pragmatic - works immediately)
3. **Try fllama** (alternative if flutter_llama fails)

All research is complete. Ready to implement chosen approach.
