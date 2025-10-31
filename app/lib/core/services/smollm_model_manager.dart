import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../models/smollm_models.dart';

/// Manages SmolLM2 model downloads with progress tracking
class SmolLMModelManager {
  final Map<SmolLMModelType, SmolLMDownloadProgress> _downloadStates = {};
  final _progressController = StreamController<SmolLMDownloadProgress>.broadcast();

  Stream<SmolLMDownloadProgress> get progressStream => _progressController.stream;

  /// Check if a model is downloaded
  Future<bool> isModelDownloaded(SmolLMModelType modelType) async {
    try {
      final modelPath = await getModelPath(modelType);
      return await File(modelPath).exists();
    } catch (e) {
      debugPrint('Error checking model: $e');
      return false;
    }
  }

  /// Get the local file path for a model
  Future<String> getModelPath(SmolLMModelType modelType) async {
    final appDir = await getApplicationSupportDirectory();
    return '${appDir.path}/models/${modelType.filename}';
  }

  /// Download a model with real progress tracking
  Future<void> downloadModel(SmolLMModelType modelType) async {
    if (await isModelDownloaded(modelType)) {
      _updateProgress(modelType, ModelDownloadState.downloaded, 1.0);
      return;
    }

    try {
      _updateProgress(modelType, ModelDownloadState.downloading, 0.0);

      final modelPath = await getModelPath(modelType);
      final modelFile = File(modelPath);

      // Create directory if needed
      await modelFile.parent.create(recursive: true);

      // Download with progress
      final request = http.Request('GET', Uri.parse(modelType.downloadUrl));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('Failed to download: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      var downloadedBytes = 0;

      final sink = modelFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        if (contentLength > 0) {
          final progress = downloadedBytes / contentLength;
          _updateProgress(modelType, ModelDownloadState.downloading, progress);
        }
      }

      await sink.close();
      _updateProgress(modelType, ModelDownloadState.downloaded, 1.0);

    } catch (e) {
      debugPrint('Download failed: $e');
      _updateProgress(modelType, ModelDownloadState.failed, 0.0, error: e.toString());
      rethrow;
    }
  }

  /// Delete a model
  Future<bool> deleteModel(SmolLMModelType modelType) async {
    try {
      final modelPath = await getModelPath(modelType);
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

  void _updateProgress(SmolLMModelType modelType, ModelDownloadState state, double progress, {String? error}) {
    final progressData = SmolLMDownloadProgress(
      model: modelType,
      state: state,
      progress: progress.clamp(0.0, 1.0),
      error: error,
    );
    _downloadStates[modelType] = progressData;
    _progressController.add(progressData);
  }

  SmolLMDownloadProgress? getDownloadState(SmolLMModelType modelType) {
    return _downloadStates[modelType];
  }

  Future<List<SmolLMModelType>> getDownloadedModels() async {
    final downloaded = <SmolLMModelType>[];
    for (final modelType in SmolLMModelType.values) {
      if (await isModelDownloaded(modelType)) {
        downloaded.add(modelType);
      }
    }
    return downloaded;
  }

  Future<int> getTotalStorageUsedMB() async {
    var totalMB = 0;
    for (final modelType in SmolLMModelType.values) {
      if (await isModelDownloaded(modelType)) {
        totalMB += modelType.sizeInMB;
      }
    }
    return totalMB;
  }

  /// Get storage info string for display
  Future<String> getStorageInfo() async {
    final totalMB = await getTotalStorageUsedMB();
    if (totalMB >= 1000) {
      final totalGB = (totalMB / 1000.0).toStringAsFixed(2);
      return '$totalGB GB used';
    }
    return '$totalMB MB used';
  }

  void dispose() {
    _progressController.close();
  }
}
