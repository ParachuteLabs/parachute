import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:whisper_ggml/whisper_ggml.dart';
import 'package:app/features/recorder/models/whisper_models.dart';
import 'package:app/features/recorder/services/whisper_model_manager.dart';
import 'package:app/features/recorder/services/storage_service.dart';

/// Local Whisper transcription service using on-device models
///
/// Provides offline transcription with progress tracking.
/// Uses whisper_ggml for local inference.
class WhisperLocalService {
  final WhisperModelManager _modelManager;
  final StorageService _storageService;
  final WhisperController _whisperController = WhisperController();

  // Stream controller for transcription progress
  final _transcriptionProgressController =
      StreamController<TranscriptionProgress>.broadcast();

  Stream<TranscriptionProgress> get transcriptionProgressStream =>
      _transcriptionProgressController.stream;

  WhisperLocalService(this._modelManager, this._storageService);

  /// Transcribe an audio file using local Whisper model
  ///
  /// [audioPath] - Absolute path to the audio file
  /// [modelType] - Model to use (if null, uses preferred model from settings)
  /// [language] - Optional ISO-639-1 language code (e.g., 'en', 'es', 'fr')
  ///              If not specified, Whisper will auto-detect the language
  /// [onProgress] - Optional callback for progress updates
  ///
  /// Returns the transcribed text
  /// Throws [WhisperLocalException] if transcription fails
  Future<String> transcribeAudio(
    String audioPath, {
    WhisperModelType? modelType,
    String? language,
    Function(TranscriptionProgress)? onProgress,
  }) async {
    // Get model to use
    final model = modelType ?? await getPreferredModel();

    // Check if model is downloaded
    final isDownloaded = await _modelManager.isModelDownloaded(model);
    if (!isDownloaded) {
      throw WhisperLocalException(
        'Model ${model.displayName} is not downloaded. '
        'Please download it in Settings first.',
      );
    }

    // Validate file exists
    final file = File(audioPath);
    if (!await file.exists()) {
      throw WhisperLocalException('Audio file not found: $audioPath');
    }

    try {
      // Start progress tracking
      _updateProgress(0.0, 'Initializing transcription...', onProgress);

      // Get file duration for progress estimation
      final fileStat = await file.stat();
      final fileSizeKB = fileStat.size / 1024;

      // Estimate processing time based on model and file size
      final estimatedSeconds = _estimateProcessingTime(model, fileSizeKB);

      // Start progress simulation
      final progressTimer = _startTranscriptionProgressSimulation(
        estimatedSeconds,
        onProgress,
      );

      try {
        // Convert our model to whisper_ggml model
        final whisperModel = _convertToWhisperModel(model);

        // Perform transcription
        final result = await _whisperController.transcribe(
          model: whisperModel,
          audioPath: audioPath,
          lang: language ?? 'auto',
        );

        // Cancel progress timer
        progressTimer.cancel();

        // Update to 100%
        _updateProgress(1.0, 'Transcription complete!', onProgress,
            isComplete: true);

        // Extract transcription text
        final text = result?.transcription.text ?? '';

        if (text.isEmpty) {
          throw WhisperLocalException('Transcription returned empty text');
        }

        return text;
      } catch (e) {
        progressTimer.cancel();
        throw e;
      }
    } on SocketException {
      throw WhisperLocalException(
        'Network error during model initialization. '
        'Please ensure the model is fully downloaded.',
      );
    } catch (e) {
      if (e is WhisperLocalException) rethrow;
      throw WhisperLocalException('Transcription failed: ${e.toString()}');
    }
  }

  /// Convert our model type to whisper_ggml's model type
  WhisperModel _convertToWhisperModel(WhisperModelType modelType) {
    switch (modelType) {
      case WhisperModelType.tiny:
        return WhisperModel.tiny;
      case WhisperModelType.base:
        return WhisperModel.base;
      case WhisperModelType.small:
        return WhisperModel.small;
      case WhisperModelType.medium:
        return WhisperModel.medium;
      case WhisperModelType.large:
        return WhisperModel.large;
    }
  }

  /// Estimate processing time based on model and file size
  ///
  /// Processing speed varies by model:
  /// - tiny: ~10x realtime (1 min audio = 6 sec processing)
  /// - base: ~5x realtime (1 min audio = 12 sec processing)
  /// - small: ~2x realtime (1 min audio = 30 sec processing)
  /// - medium: ~1x realtime (1 min audio = 60 sec processing)
  /// - large: ~0.5x realtime (1 min audio = 120 sec processing)
  ///
  /// Note: These are rough estimates and vary by device
  int _estimateProcessingTime(WhisperModelType model, double fileSizeKB) {
    // Rough estimate: 1 MB = ~1 minute of m4a audio
    final estimatedMinutes = fileSizeKB / 1024;

    final realtimeMultiplier = switch (model) {
      WhisperModelType.tiny => 0.1,
      WhisperModelType.base => 0.2,
      WhisperModelType.small => 0.5,
      WhisperModelType.medium => 1.0,
      WhisperModelType.large => 2.0,
    };

    // In debug mode, processing is ~5x slower
    final debugMultiplier = kDebugMode ? 5.0 : 1.0;

    return (estimatedMinutes * 60 * realtimeMultiplier * debugMultiplier)
        .ceil();
  }

  /// Start simulated progress tracking for transcription
  ///
  /// Since whisper_ggml doesn't provide progress callbacks, we simulate
  /// progress based on estimated processing time.
  Timer _startTranscriptionProgressSimulation(
    int estimatedSeconds,
    Function(TranscriptionProgress)? onProgress,
  ) {
    const updateIntervalMs = 500;
    final progressIncrement =
        1.0 / (estimatedSeconds * 1000 / updateIntervalMs);

    var currentProgress = 0.05; // Start at 5%

    return Timer.periodic(
      const Duration(milliseconds: updateIntervalMs),
      (timer) {
        currentProgress += progressIncrement;

        // Cap at 95% until actual transcription completes
        if (currentProgress >= 0.95) {
          currentProgress = 0.95;
          timer.cancel();
        }

        _updateProgress(currentProgress, 'Transcribing...', onProgress);
      },
    );
  }

  /// Update and broadcast transcription progress
  void _updateProgress(
    double progress,
    String status,
    Function(TranscriptionProgress)? onProgress, {
    bool isComplete = false,
  }) {
    final progressData = TranscriptionProgress(
      progress: progress.clamp(0.0, 1.0),
      status: status,
      isComplete: isComplete,
    );

    _transcriptionProgressController.add(progressData);
    onProgress?.call(progressData);
  }

  /// Get the preferred model from settings
  Future<WhisperModelType> getPreferredModel() async {
    final preferredModelName = await _storageService.getPreferredWhisperModel();

    if (preferredModelName != null) {
      final model = WhisperModelType.fromString(preferredModelName);
      if (model != null) return model;
    }

    // Default to base model (good balance)
    return WhisperModelType.base;
  }

  /// Set the preferred model
  Future<void> setPreferredModel(WhisperModelType model) async {
    await _storageService.setPreferredWhisperModel(model.modelName);
  }

  /// Check if local transcription is ready to use
  Future<bool> isReady() async {
    try {
      final preferredModel = await getPreferredModel();
      return await _modelManager.isModelDownloaded(preferredModel);
    } catch (e) {
      return false;
    }
  }

  /// Get list of available (downloaded) models
  Future<List<WhisperModelType>> getAvailableModels() async {
    return await _modelManager.getDownloadedModels();
  }

  void dispose() {
    _transcriptionProgressController.close();
  }
}

/// Custom exception for local Whisper errors
class WhisperLocalException implements Exception {
  final String message;

  WhisperLocalException(this.message);

  @override
  String toString() => message;
}
