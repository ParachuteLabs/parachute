import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:app/features/recorder/models/recording.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// File-based storage service for local-first sync-friendly architecture
///
/// Each recording consists of:
/// - An audio file (.m4a)
/// - A markdown metadata file (.md) with frontmatter + transcription
///
/// Files are stored in a user-configurable sync folder for use with
/// iCloud, Syncthing, Google Drive, etc.
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _syncFolderPathKey = 'sync_folder_path';
  static const String _hasInitializedKey = 'has_initialized';
  static const String _openaiApiKeyKey = 'openai_api_key';
  static const String _transcriptionModeKey = 'transcription_mode';
  static const String _preferredWhisperModelKey = 'preferred_whisper_model';
  static const String _autoTranscribeKey = 'auto_transcribe';

  String? _syncFolderPath;
  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  /// Initialize the storage service and ensure sync folder is set up
  Future<void> initialize() async {
    // If already initialized, return immediately
    if (_isInitialized) return;

    // If initialization is in progress, wait for it to complete
    if (_initializationFuture != null) {
      return _initializationFuture;
    }

    // Start initialization and store the future
    _initializationFuture = _doInitialize();
    await _initializationFuture;
  }

  Future<void> _doInitialize() async {
    try {
      debugPrint('StorageService: Starting initialization...');
      final prefs = await SharedPreferences.getInstance();
      debugPrint('StorageService: Got SharedPreferences');

      _syncFolderPath = prefs.getString(_syncFolderPathKey);
      debugPrint('StorageService: Sync folder path: $_syncFolderPath');

      // If no sync folder is set, use default app documents directory
      if (_syncFolderPath == null) {
        debugPrint('StorageService: Getting app documents directory...');
        final appDir = await getApplicationDocumentsDirectory();
        _syncFolderPath = '${appDir.path}/parachute_recordings';
        debugPrint('StorageService: Set default sync folder: $_syncFolderPath');
        await prefs.setString(_syncFolderPathKey, _syncFolderPath!);
      }

      // Ensure recordings directory exists
      debugPrint('StorageService: Ensuring recordings directory exists...');
      await _ensureRecordingsDirectory();

      // Create sample recordings on first launch
      final hasInitialized = prefs.getBool(_hasInitializedKey) ?? false;
      debugPrint('StorageService: Has initialized: $hasInitialized');
      if (!hasInitialized) {
        debugPrint('StorageService: Creating sample recordings...');
        await _createSampleRecordings();
        await prefs.setBool(_hasInitializedKey, true);
      }

      _isInitialized = true;
      _initializationFuture = null;
      debugPrint('StorageService: Initialization complete');
    } catch (e, stackTrace) {
      debugPrint('StorageService: Error during initialization: $e');
      debugPrint('StorageService: Stack trace: $stackTrace');
      _initializationFuture = null;
      rethrow;
    }
  }

  /// Get the current sync folder path
  Future<String> getSyncFolderPath() async {
    await initialize();
    return _syncFolderPath!;
  }

  /// Set a new sync folder path (for user configuration)
  Future<bool> setSyncFolderPath(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      _syncFolderPath = path;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_syncFolderPathKey, path);

      await _ensureRecordingsDirectory();
      return true;
    } catch (e) {
      debugPrint('Error setting sync folder path: $e');
      return false;
    }
  }

  Future<void> _ensureRecordingsDirectory() async {
    final recordingsDir = Directory(_syncFolderPath!);
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
      debugPrint('Created recordings directory: ${recordingsDir.path}');
    }
  }

  /// Get the path for a recording's audio file
  String _getAudioPath(String recordingId, DateTime timestamp) {
    final dateStr = _formatDateForFilename(timestamp);
    return '$_syncFolderPath/$dateStr-$recordingId.m4a';
  }

  /// Get the path for a recording's metadata markdown file
  String _getMetadataPath(String recordingId, DateTime timestamp) {
    final dateStr = _formatDateForFilename(timestamp);
    return '$_syncFolderPath/$dateStr-$recordingId.md';
  }

  String _formatDateForFilename(DateTime timestamp) {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
  }

  /// Load all recordings from the sync folder
  Future<List<Recording>> getRecordings() async {
    await initialize();

    try {
      final dir = Directory(_syncFolderPath!);
      final recordings = <Recording>[];

      if (!await dir.exists()) {
        return recordings;
      }

      // Find all .md files
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.md')) {
          try {
            final recording = await _loadRecordingFromMarkdown(entity);
            if (recording != null) {
              recordings.add(recording);
            }
          } catch (e) {
            debugPrint('Error loading recording from ${entity.path}: $e');
          }
        }
      }

      // Sort by timestamp, newest first
      recordings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return recordings;
    } catch (e) {
      debugPrint('Error getting recordings: $e');
      return [];
    }
  }

  /// Load a recording from its markdown file
  Future<Recording?> _loadRecordingFromMarkdown(File mdFile) async {
    final content = await mdFile.readAsString();

    // Parse frontmatter and content
    final parts = content.split('---');
    if (parts.length < 3) {
      debugPrint('Invalid markdown format in ${mdFile.path}');
      return null;
    }

    // Parse YAML frontmatter
    final frontmatter = _parseYamlFrontmatter(parts[1]);
    final bodyContent = parts.sublist(2).join('---').trim();

    // Determine file extension based on source
    final source = frontmatter['source']?.toString() ?? 'phone';
    final isOmiDevice = source.toLowerCase() == 'omidevice';
    final audioPath =
        mdFile.path.replaceAll('.md', isOmiDevice ? '.wav' : '.m4a');

    return Recording(
      id: frontmatter['id']?.toString() ?? '',
      title: frontmatter['title']?.toString() ?? 'Untitled',
      filePath: audioPath,
      timestamp: DateTime.parse(frontmatter['created']?.toString() ??
          DateTime.now().toIso8601String()),
      duration: Duration(seconds: frontmatter['duration'] ?? 0),
      tags: (frontmatter['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      transcript: bodyContent,
      fileSizeKB: (frontmatter['fileSize'] ?? 0).toDouble(),
      source: isOmiDevice ? RecordingSource.omiDevice : RecordingSource.phone,
      deviceId: frontmatter['deviceId']?.toString(),
      buttonTapCount: frontmatter['buttonTapCount'] as int?,
    );
  }

  /// Simple YAML frontmatter parser
  Map<String, dynamic> _parseYamlFrontmatter(String yaml) {
    final result = <String, dynamic>{};
    final lines = yaml.trim().split('\n');

    String? currentKey;
    List<String>? currentList;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('- ')) {
        // List item
        if (currentList != null && currentKey != null) {
          currentList.add(trimmed.substring(2));
        }
      } else if (trimmed.endsWith(':')) {
        // Key with list value
        currentKey = trimmed.substring(0, trimmed.length - 1);
        currentList = [];
        result[currentKey] = currentList;
      } else if (trimmed.contains(':')) {
        // Key-value pair
        final parts = trimmed.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join(':').trim();

          // Try to parse as number
          if (int.tryParse(value) != null) {
            result[key] = int.parse(value);
          } else if (double.tryParse(value) != null) {
            result[key] = double.parse(value);
          } else {
            result[key] = value;
          }

          currentKey = null;
          currentList = null;
        }
      }
    }

    return result;
  }

  /// Save a recording to disk (audio file + markdown metadata)
  Future<bool> saveRecording(Recording recording) async {
    // Only initialize if not already initialized or initializing
    if (!_isInitialized && _initializationFuture == null) {
      await initialize();
    }

    try {
      // Save markdown metadata file
      final mdPath = _getMetadataPath(recording.id, recording.timestamp);
      final mdFile = File(mdPath);

      final markdown = _generateMarkdown(recording);
      await mdFile.writeAsString(markdown);

      debugPrint('Saved recording metadata: $mdPath');
      return true;
    } catch (e) {
      debugPrint('Error saving recording: $e');
      return false;
    }
  }

  /// Generate markdown content from recording
  String _generateMarkdown(Recording recording) {
    final buffer = StringBuffer();

    // Frontmatter
    buffer.writeln('---');
    buffer.writeln('id: ${recording.id}');
    buffer.writeln('title: ${recording.title}');
    buffer.writeln('created: ${recording.timestamp.toIso8601String()}');
    buffer.writeln('duration: ${recording.duration.inSeconds}');
    buffer.writeln('fileSize: ${recording.fileSizeKB}');
    buffer.writeln('source: ${recording.source}');

    if (recording.deviceId != null) {
      buffer.writeln('deviceId: ${recording.deviceId}');
    }

    if (recording.buttonTapCount != null) {
      buffer.writeln('buttonTapCount: ${recording.buttonTapCount}');
    }

    if (recording.tags.isNotEmpty) {
      buffer.writeln('tags:');
      for (final tag in recording.tags) {
        buffer.writeln('  - $tag');
      }
    }

    buffer.writeln('---');
    buffer.writeln();

    // Content
    buffer.writeln('# ${recording.title}');
    buffer.writeln();

    if (recording.transcript.isNotEmpty) {
      buffer.writeln('## Transcription');
      buffer.writeln();
      buffer.writeln(recording.transcript);
    }

    return buffer.toString();
  }

  /// Update an existing recording
  Future<bool> updateRecording(Recording updatedRecording) async {
    // For file-based system, updating is the same as saving
    return await saveRecording(updatedRecording);
  }

  /// Delete a recording (both audio and metadata files)
  Future<bool> deleteRecording(String recordingId) async {
    try {
      final recordings = await getRecordings();
      final recording = recordings.firstWhere(
        (r) => r.id == recordingId,
        orElse: () => throw Exception('Recording not found'),
      );

      // Delete audio file
      final audioFile = File(recording.filePath);
      if (await audioFile.exists()) {
        await audioFile.delete();
        debugPrint('Deleted audio file: ${recording.filePath}');
      }

      // Delete metadata file
      final mdPath = _getMetadataPath(recording.id, recording.timestamp);
      final mdFile = File(mdPath);
      if (await mdFile.exists()) {
        await mdFile.delete();
        debugPrint('Deleted metadata file: $mdPath');
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting recording: $e');
      return false;
    }
  }

  /// Get a single recording by ID
  Future<Recording?> getRecording(String recordingId) async {
    final recordings = await getRecordings();
    try {
      return recordings.firstWhere((r) => r.id == recordingId);
    } catch (e) {
      return null;
    }
  }

  /// Create sample recordings for demo purposes
  Future<void> _createSampleRecordings() async {
    final now = DateTime.now();
    final sampleRecordings = [
      Recording(
        id: 'sample_1',
        title: 'Welcome to Parachute',
        filePath:
            _getAudioPath('sample_1', now.subtract(const Duration(hours: 2))),
        timestamp: now.subtract(const Duration(hours: 2)),
        duration: const Duration(minutes: 1, seconds: 30),
        tags: ['welcome', 'tutorial'],
        transcript:
            'Welcome to Parachute, your personal voice recording assistant. '
            'This app helps you capture thoughts, ideas, and important moments with ease.',
        fileSizeKB: 450,
      ),
      Recording(
        id: 'sample_2',
        title: 'Meeting Notes',
        filePath:
            _getAudioPath('sample_2', now.subtract(const Duration(days: 1))),
        timestamp: now.subtract(const Duration(days: 1)),
        duration: const Duration(minutes: 15, seconds: 45),
        tags: ['work', 'meeting', 'project-alpha'],
        transcript: 'Today we discussed the new features for Project Alpha. '
            'Key decisions: 1) Move deadline to next quarter, 2) Add two more developers to the team, '
            '3) Focus on mobile-first approach.',
        fileSizeKB: 2340,
      ),
      Recording(
        id: 'sample_3',
        title: 'Quick Reminder',
        filePath:
            _getAudioPath('sample_3', now.subtract(const Duration(days: 3))),
        timestamp: now.subtract(const Duration(days: 3)),
        duration: const Duration(seconds: 45),
        tags: ['personal', 'reminder'],
        transcript:
            'Remember to call the dentist tomorrow morning to schedule the appointment. '
            'Also, pick up groceries on the way home.',
        fileSizeKB: 180,
      ),
    ];

    for (final recording in sampleRecordings) {
      await saveRecording(recording);

      // Create empty placeholder audio files
      final audioFile = File(recording.filePath);
      if (!await audioFile.exists()) {
        await audioFile.create(recursive: true);
      }
    }
  }

  /// Clear all recordings
  Future<void> clearAllRecordings() async {
    final recordings = await getRecordings();
    for (final recording in recordings) {
      await deleteRecording(recording.id);
    }
  }

  // OpenAI API Key Management (kept in SharedPreferences as it's config, not data)
  Future<String?> getOpenAIApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_openaiApiKeyKey);
    } catch (e) {
      debugPrint('Error getting OpenAI API key: $e');
      return null;
    }
  }

  Future<bool> saveOpenAIApiKey(String apiKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_openaiApiKeyKey, apiKey.trim());
    } catch (e) {
      debugPrint('Error saving OpenAI API key: $e');
      return false;
    }
  }

  Future<bool> deleteOpenAIApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_openaiApiKeyKey);
    } catch (e) {
      debugPrint('Error deleting OpenAI API key: $e');
      return false;
    }
  }

  Future<bool> hasOpenAIApiKey() async {
    final apiKey = await getOpenAIApiKey();
    return apiKey != null && apiKey.isNotEmpty;
  }

  // Local Whisper Configuration

  /// Get transcription mode (api or local)
  Future<String> getTranscriptionMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_transcriptionModeKey) ?? 'api';
    } catch (e) {
      debugPrint('Error getting transcription mode: $e');
      return 'api';
    }
  }

  /// Set transcription mode
  Future<bool> setTranscriptionMode(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_transcriptionModeKey, mode);
    } catch (e) {
      debugPrint('Error setting transcription mode: $e');
      return false;
    }
  }

  /// Get preferred Whisper model
  Future<String?> getPreferredWhisperModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_preferredWhisperModelKey);
    } catch (e) {
      debugPrint('Error getting preferred Whisper model: $e');
      return null;
    }
  }

  /// Set preferred Whisper model
  Future<bool> setPreferredWhisperModel(String modelName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_preferredWhisperModelKey, modelName);
    } catch (e) {
      debugPrint('Error setting preferred Whisper model: $e');
      return false;
    }
  }

  /// Get auto-transcribe setting
  Future<bool> getAutoTranscribe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_autoTranscribeKey) ?? false;
    } catch (e) {
      debugPrint('Error getting auto-transcribe setting: $e');
      return false;
    }
  }

  /// Set auto-transcribe setting
  Future<bool> setAutoTranscribe(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(_autoTranscribeKey, enabled);
    } catch (e) {
      debugPrint('Error setting auto-transcribe: $e');
      return false;
    }
  }
}
