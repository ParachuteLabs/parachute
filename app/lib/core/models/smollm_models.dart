/// Available SmolLM2 models for title generation
enum SmolLMModelType {
  /// SmolLM2-135M (smallest, fastest)
  smol135m,

  /// SmolLM2-360M (balanced, recommended)
  smol360m,

  /// SmolLM2-1.7B (largest, best quality)
  smol1_7b,
}

extension SmolLMModelTypeExtension on SmolLMModelType {
  /// Display name for UI
  String get displayName {
    switch (this) {
      case SmolLMModelType.smol135m:
        return 'SmolLM2-135M (Tiny)';
      case SmolLMModelType.smol360m:
        return 'SmolLM2-360M (Base)';
      case SmolLMModelType.smol1_7b:
        return 'SmolLM2-1.7B (Large)';
    }
  }

  /// Model description
  String get description {
    switch (this) {
      case SmolLMModelType.smol135m:
        return 'Smallest model, fastest inference (~1s per title)';
      case SmolLMModelType.smol360m:
        return 'Balanced model, good quality and speed (~2s per title)';
      case SmolLMModelType.smol1_7b:
        return 'Best quality, slower inference (~5s per title)';
    }
  }

  /// Approximate size in MB
  int get sizeInMB {
    switch (this) {
      case SmolLMModelType.smol135m:
        return 85;
      case SmolLMModelType.smol360m:
        return 210;
      case SmolLMModelType.smol1_7b:
        return 1000;
    }
  }

  /// Download URL for the model
  String get downloadUrl {
    // Use HuggingFace CDN which doesn't require authentication
    const baseUrl = 'https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF/resolve/main';

    switch (this) {
      case SmolLMModelType.smol135m:
        return 'https://huggingface.co/bartowski/SmolLM2-135M-Instruct-GGUF/resolve/main/SmolLM2-135M-Instruct-Q4_K_M.gguf';
      case SmolLMModelType.smol360m:
        return 'https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF/resolve/main/SmolLM2-360M-Instruct-Q4_K_M.gguf';
      case SmolLMModelType.smol1_7b:
        return 'https://huggingface.co/bartowski/SmolLM2-1.7B-Instruct-GGUF/resolve/main/SmolLM2-1.7B-Instruct-Q4_K_M.gguf';
    }
  }

  /// Filename for local storage
  String get filename {
    switch (this) {
      case SmolLMModelType.smol135m:
        return 'smollm2-135m-instruct-q4_k_m.gguf';
      case SmolLMModelType.smol360m:
        return 'smollm2-360m-instruct-q4_k_m.gguf';
      case SmolLMModelType.smol1_7b:
        return 'smollm2-1.7b-instruct-q4_k_m.gguf';
    }
  }

  /// Recommended for most users
  bool get isRecommended => this == SmolLMModelType.smol360m;
}

/// Download state for model management
enum ModelDownloadState {
  notDownloaded,
  downloading,
  downloaded,
  failed,
}

/// Progress information for model downloads
class SmolLMDownloadProgress {
  final SmolLMModelType model;
  final ModelDownloadState state;
  final double progress; // 0.0 to 1.0
  final String? error;

  SmolLMDownloadProgress({
    required this.model,
    required this.state,
    required this.progress,
    this.error,
  });
}
