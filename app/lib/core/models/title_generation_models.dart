/// Title generation model definitions
library;

/// Title generation mode: API vs Local
enum TitleModelMode {
  api('Gemini API', 'Cloud-based, requires internet'),
  local('Local (Offline)', 'On-device, private and free');

  const TitleModelMode(this.displayName, this.description);

  final String displayName;
  final String description;

  static TitleModelMode? fromString(String value) {
    final normalized = value.toLowerCase();
    for (final mode in TitleModelMode.values) {
      if (mode.name.toLowerCase() == normalized) {
        return mode;
      }
    }
    return null;
  }
}

/// Gemma model types for local title generation
///
/// Models are ordered by size and performance characteristics.
/// Smaller models are faster but may be less accurate for complex titles.
///
/// Models are downloaded from HuggingFace litert-community (requires license acceptance).
enum GemmaModelType {
  gemma1b(
    'gemma-3-1b-int4',
    555,
    'Fast and efficient on-device model',
    'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task',
    'https://huggingface.co/litert-community/Gemma3-1B-IT',
  );

  const GemmaModelType(
    this.modelName,
    this.sizeInMB,
    this.description,
    this.downloadUrl,
    this.huggingFaceUrl,
  );

  final String modelName;
  final int sizeInMB;
  final String description;
  final String downloadUrl;
  final String huggingFaceUrl;

  /// Get formatted size string (e.g., "300 MB", "1.2 GB")
  String get formattedSize {
    if (sizeInMB < 1000) {
      return '$sizeInMB MB';
    } else {
      final sizeInGB = sizeInMB / 1000;
      return '${sizeInGB.toStringAsFixed(1)} GB';
    }
  }

  /// Get display name for UI
  String get displayName {
    // "gemma-3-1b" -> "GEMMA 3 1B"
    return modelName.toUpperCase();
  }

  /// Get full display text with size
  String get fullDisplayName {
    return '$displayName ($formattedSize)';
  }

  /// Convert string to enum (case-insensitive)
  static GemmaModelType? fromString(String value) {
    final normalized = value.toLowerCase();
    for (final model in GemmaModelType.values) {
      if (model.modelName == normalized ||
          model.name.toLowerCase() == normalized) {
        return model;
      }
    }
    return null;
  }
}

/// Model download state
enum ModelDownloadState { notDownloaded, downloading, downloaded, failed }

/// Model download progress data
class GemmaModelDownloadProgress {
  final GemmaModelType model;
  final ModelDownloadState state;
  final double progress; // 0.0 to 1.0
  final String? error;

  const GemmaModelDownloadProgress({
    required this.model,
    required this.state,
    this.progress = 0.0,
    this.error,
  });

  GemmaModelDownloadProgress copyWith({
    GemmaModelType? model,
    ModelDownloadState? state,
    double? progress,
    String? error,
  }) {
    return GemmaModelDownloadProgress(
      model: model ?? this.model,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }

  /// Get formatted progress percentage
  String get progressPercentage {
    return '${(progress * 100).toStringAsFixed(0)}%';
  }

  bool get isDownloaded => state == ModelDownloadState.downloaded;
  bool get isDownloading => state == ModelDownloadState.downloading;
  bool get hasFailed => state == ModelDownloadState.failed;
}
