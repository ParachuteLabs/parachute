/// Whisper model definitions for local transcription
library;

/// Models are ordered by size and performance characteristics.
/// Smaller models are faster but less accurate.
enum WhisperModelType {
  tiny('tiny', 75, 'Fast, good for real-time'),
  base('base', 142, 'Balanced speed and accuracy'),
  small('small', 466, 'Better accuracy, slower'),
  medium('medium', 1500, 'High accuracy, much slower'),
  large('large-v1', 2900, 'Best quality, very slow');

  const WhisperModelType(this.modelName, this.sizeInMB, this.description);

  final String modelName;
  final int sizeInMB;
  final String description;

  /// Get formatted size string (e.g., "75 MB", "1.5 GB")
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
    return modelName.split('-').first.toUpperCase();
  }

  /// Get full display text with size
  String get fullDisplayName {
    return '$displayName ($formattedSize)';
  }

  /// Convert string to enum (case-insensitive)
  static WhisperModelType? fromString(String value) {
    final normalized = value.toLowerCase();
    for (final model in WhisperModelType.values) {
      if (model.modelName == normalized ||
          model.name.toLowerCase() == normalized) {
        return model;
      }
    }
    return null;
  }
}

/// Transcription mode: API vs Local
enum TranscriptionMode {
  api('OpenAI API', 'Cloud-based, requires internet'),
  local('Local (Offline)', 'On-device, private and free');

  const TranscriptionMode(this.displayName, this.description);

  final String displayName;
  final String description;

  static TranscriptionMode? fromString(String value) {
    final normalized = value.toLowerCase();
    for (final mode in TranscriptionMode.values) {
      if (mode.name.toLowerCase() == normalized) {
        return mode;
      }
    }
    return null;
  }
}

/// Model download state
enum ModelDownloadState {
  notDownloaded,
  downloading,
  downloaded,
  failed,
}

/// Model download progress data
class ModelDownloadProgress {
  final WhisperModelType model;
  final ModelDownloadState state;
  final double progress; // 0.0 to 1.0
  final String? error;

  const ModelDownloadProgress({
    required this.model,
    required this.state,
    this.progress = 0.0,
    this.error,
  });

  ModelDownloadProgress copyWith({
    WhisperModelType? model,
    ModelDownloadState? state,
    double? progress,
    String? error,
  }) {
    return ModelDownloadProgress(
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

/// Transcription progress data
class TranscriptionProgress {
  final double progress; // 0.0 to 1.0
  final String status;
  final bool isComplete;

  const TranscriptionProgress({
    required this.progress,
    required this.status,
    this.isComplete = false,
  });

  /// Get formatted progress percentage
  String get progressPercentage {
    return '${(progress * 100).toStringAsFixed(0)}%';
  }
}
