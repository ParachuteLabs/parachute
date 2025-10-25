import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import 'package:app/features/recorder/models/whisper_models.dart';

/// Manages Whisper model downloads and lifecycle
///
/// Handles:
/// - Model downloads with progress tracking
/// - Model storage and cleanup
/// - Model availability checking
class WhisperModelManager {
  final WhisperController _whisperController = WhisperController();

  // Cache of model download states
  final Map<WhisperModelType, ModelDownloadProgress> _downloadStates = {};

  // Stream controller for download progress
  final _progressController =
      StreamController<ModelDownloadProgress>.broadcast();

  Stream<ModelDownloadProgress> get progressStream =>
      _progressController.stream;

  /// Check if a model is already downloaded
  Future<bool> isModelDownloaded(WhisperModelType modelType) async {
    try {
      final modelPath = await _getModelPath(modelType);
      final file = File(modelPath);
      return await file.exists();
    } catch (e) {
      debugPrint('Error checking model: $e');
      return false;
    }
  }

  /// Get the file path for a model
  Future<String> _getModelPath(WhisperModelType modelType) async {
    // Use the whisper controller's getPath method
    final whisperModel = _convertToWhisperModel(modelType);
    return await _whisperController.getPath(whisperModel);
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

  /// Download a model with progress tracking
  ///
  /// Note: whisper_ggml doesn't provide built-in progress callbacks,
  /// so we'll simulate progress based on time estimates
  Future<void> downloadModel(WhisperModelType modelType) async {
    // Check if already downloaded
    if (await isModelDownloaded(modelType)) {
      _updateProgress(modelType, ModelDownloadState.downloaded, 1.0);
      return;
    }

    try {
      // Start download
      _updateProgress(modelType, ModelDownloadState.downloading, 0.0);

      final whisperModel = _convertToWhisperModel(modelType);

      // Start a timer to simulate progress (since whisper_ggml doesn't provide callbacks)
      final progressTimer = _startProgressSimulation(modelType);

      try {
        // Download the model
        await _whisperController.downloadModel(whisperModel);

        // Cancel the progress timer
        progressTimer.cancel();

        // Mark as downloaded
        _updateProgress(modelType, ModelDownloadState.downloaded, 1.0);
      } catch (e) {
        progressTimer.cancel();
        throw e;
      }
    } catch (e) {
      debugPrint('Model download failed: $e');
      _updateProgress(
        modelType,
        ModelDownloadState.failed,
        0.0,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Simulate download progress based on model size
  ///
  /// Since whisper_ggml doesn't provide progress callbacks, we estimate
  /// based on typical download speeds and model sizes.
  Timer _startProgressSimulation(WhisperModelType modelType) {
    const updateIntervalMs = 500;
    final estimatedSeconds = _estimateDownloadTime(modelType);
    final progressIncrement =
        1.0 / (estimatedSeconds * 1000 / updateIntervalMs);

    var currentProgress = 0.05; // Start at 5%

    return Timer.periodic(
      const Duration(milliseconds: updateIntervalMs),
      (timer) {
        currentProgress += progressIncrement;

        // Cap at 95% until actual download completes
        if (currentProgress >= 0.95) {
          currentProgress = 0.95;
          timer.cancel();
        }

        _updateProgress(
            modelType, ModelDownloadState.downloading, currentProgress);
      },
    );
  }

  /// Estimate download time in seconds based on model size
  /// Assumes ~5 MB/s download speed
  int _estimateDownloadTime(WhisperModelType modelType) {
    const mbPerSecond = 5.0;
    return (modelType.sizeInMB / mbPerSecond).ceil();
  }

  /// Update and broadcast download progress
  void _updateProgress(
    WhisperModelType modelType,
    ModelDownloadState state,
    double progress, {
    String? error,
  }) {
    final progressData = ModelDownloadProgress(
      model: modelType,
      state: state,
      progress: progress.clamp(0.0, 1.0),
      error: error,
    );

    _downloadStates[modelType] = progressData;
    _progressController.add(progressData);
  }

  /// Delete a downloaded model to free up space
  Future<bool> deleteModel(WhisperModelType modelType) async {
    try {
      final modelPath = await _getModelPath(modelType);
      final file = File(modelPath);

      if (await file.exists()) {
        await file.delete();
        _updateProgress(modelType, ModelDownloadState.notDownloaded, 0.0);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error deleting model: $e');
      return false;
    }
  }

  /// Get current download state for a model
  ModelDownloadProgress? getDownloadState(WhisperModelType modelType) {
    return _downloadStates[modelType];
  }

  /// Get all downloaded models
  Future<List<WhisperModelType>> getDownloadedModels() async {
    final downloaded = <WhisperModelType>[];

    for (final modelType in WhisperModelType.values) {
      if (await isModelDownloaded(modelType)) {
        downloaded.add(modelType);
      }
    }

    return downloaded;
  }

  /// Calculate total storage used by downloaded models
  Future<int> getTotalStorageUsedMB() async {
    var totalMB = 0;

    for (final modelType in WhisperModelType.values) {
      if (await isModelDownloaded(modelType)) {
        totalMB += modelType.sizeInMB;
      }
    }

    return totalMB;
  }

  /// Get storage info as formatted string
  Future<String> getStorageInfo() async {
    final totalMB = await getTotalStorageUsedMB();

    if (totalMB < 1000) {
      return '$totalMB MB used';
    } else {
      final totalGB = totalMB / 1000;
      return '${totalGB.toStringAsFixed(1)} GB used';
    }
  }

  void dispose() {
    _progressController.close();
  }
}
