import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// File sync service for communicating with Go backend
///
/// Handles uploading recordings, fetching lists, and downloading files
/// from the backend's ~/Parachute/ folder structure.
class FileSyncService {
  final String baseUrl;
  final http.Client _client;

  FileSyncService({this.baseUrl = 'http://localhost:8080', http.Client? client})
    : _client = client ?? http.Client();

  /// Upload a recording to the backend
  Future<CaptureUploadResponse> uploadRecording({
    required File audioFile,
    required DateTime timestamp,
    required String source,
    double? duration,
    String? deviceId,
  }) async {
    debugPrint('[FileSyncService] Uploading recording: ${audioFile.path}');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/captures/upload'),
    );

    // Add audio file
    request.files.add(
      await http.MultipartFile.fromPath('audio', audioFile.path),
    );

    // Add form fields
    request.fields['timestamp'] = timestamp.toUtc().toIso8601String();
    request.fields['source'] = source;
    if (duration != null) {
      request.fields['duration'] = duration.toString();
    }
    if (deviceId != null) {
      request.fields['deviceId'] = deviceId;
    }

    final response = await _client.send(request);
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 201) {
      throw Exception(
        'Failed to upload recording: ${response.statusCode} - $responseBody',
      );
    }

    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    debugPrint('[FileSyncService] Upload successful: ${data['id']}');

    return CaptureUploadResponse.fromJson(data);
  }

  /// Upload a transcript for an existing recording
  Future<void> uploadTranscript({
    required String filename,
    required String transcript,
    required String transcriptionMode,
    String? title,
    String? modelUsed,
  }) async {
    debugPrint('[FileSyncService] Uploading transcript for: $filename');

    final response = await _client.post(
      Uri.parse('$baseUrl/api/captures/$filename/transcript'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'transcript': transcript,
        'transcriptionMode': transcriptionMode,
        if (title != null && title.isNotEmpty) 'title': title,
        if (modelUsed != null) 'modelUsed': modelUsed,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to upload transcript: ${response.statusCode} - ${response.body}',
      );
    }

    debugPrint('[FileSyncService] Transcript uploaded successfully');
  }

  /// List all captures from the backend
  Future<CaptureListResponse> listCaptures({
    int limit = 50,
    int offset = 0,
  }) async {
    debugPrint(
      '[FileSyncService] Fetching captures (limit: $limit, offset: $offset)',
    );

    final response = await _client.get(
      Uri.parse('$baseUrl/api/captures?limit=$limit&offset=$offset'),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to list captures: ${response.statusCode} - ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return CaptureListResponse.fromJson(data);
  }

  /// Download a capture to local cache
  Future<String> downloadCapture(String filename) async {
    // Check if already cached
    final cachePath = await _getCachePath(filename);
    if (await File(cachePath).exists()) {
      debugPrint('[FileSyncService] Using cached file: $filename');
      return cachePath;
    }

    debugPrint('[FileSyncService] Downloading capture: $filename');

    final response = await _client.get(
      Uri.parse('$baseUrl/api/captures/$filename'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to download capture: ${response.statusCode}');
    }

    // Save to cache
    await File(cachePath).writeAsBytes(response.bodyBytes);
    debugPrint('[FileSyncService] Cached to: $cachePath');

    return cachePath;
  }

  /// Download a transcript
  Future<String> downloadTranscript(String filename) async {
    debugPrint('[FileSyncService] Downloading transcript for: $filename');

    final response = await _client.get(
      Uri.parse('$baseUrl/api/captures/$filename/transcript'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to download transcript: ${response.statusCode}');
    }

    return response.body;
  }

  /// Delete a capture from the backend
  Future<void> deleteCapture(String filename) async {
    debugPrint('[FileSyncService] Deleting capture: $filename');

    final response = await _client.delete(
      Uri.parse('$baseUrl/api/captures/$filename'),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to delete capture: ${response.statusCode} - ${response.body}',
      );
    }

    // Also delete from cache if exists
    final cachePath = await _getCachePath(filename);
    if (await File(cachePath).exists()) {
      await File(cachePath).delete();
      debugPrint('[FileSyncService] Deleted from cache');
    }

    debugPrint('[FileSyncService] Delete successful');
  }

  /// Get cache directory path
  Future<String> _getCachePath(String filename) async {
    final cacheDir = await getCacheDir();
    return '$cacheDir/$filename';
  }

  /// Get cache directory (public for cleaning up)
  Future<String> getCacheDir() async {
    final appDocs = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDocs.path}/cache/captures');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir.path;
  }

  /// Clear all cached files
  Future<void> clearCache() async {
    debugPrint('[FileSyncService] Clearing cache');
    final cacheDir = await getCacheDir();
    if (await Directory(cacheDir).exists()) {
      await Directory(cacheDir).delete(recursive: true);
    }
  }

  void dispose() {
    _client.close();
  }
}

/// Response from uploading a capture
class CaptureUploadResponse {
  final String id;
  final String path;
  final String url;
  final DateTime createdAt;

  CaptureUploadResponse({
    required this.id,
    required this.path,
    required this.url,
    required this.createdAt,
  });

  factory CaptureUploadResponse.fromJson(Map<String, dynamic> json) {
    return CaptureUploadResponse(
      id: json['id'] as String,
      path: json['path'] as String,
      url: json['url'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Response from listing captures
class CaptureListResponse {
  final List<CaptureInfo> captures;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  CaptureListResponse({
    required this.captures,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  factory CaptureListResponse.fromJson(Map<String, dynamic> json) {
    return CaptureListResponse(
      captures: (json['captures'] as List)
          .map((c) => CaptureInfo.fromJson(c as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
      hasMore: json['hasMore'] as bool,
    );
  }
}

/// Information about a capture
class CaptureInfo {
  final String id;
  final String filename;
  final String? title; // Title from markdown frontmatter
  final DateTime timestamp;
  final double? duration;
  final String? source;
  final int size;
  final bool hasTranscript;
  final String audioUrl;
  final String? transcriptUrl;
  final String? transcript;
  final String? deviceId;
  final int? buttonTapCount;

  CaptureInfo({
    required this.id,
    required this.filename,
    this.title,
    required this.timestamp,
    this.duration,
    this.source,
    required this.size,
    required this.hasTranscript,
    required this.audioUrl,
    this.transcriptUrl,
    this.transcript,
    this.deviceId,
    this.buttonTapCount,
  });

  factory CaptureInfo.fromJson(Map<String, dynamic> json) {
    return CaptureInfo(
      id: json['id'] as String? ?? json['filename'] as String,
      filename: json['filename'] as String,
      title: json['title'] as String?, // Get title from backend
      timestamp: DateTime.parse(json['timestamp'] as String),
      duration: (json['duration'] as num?)?.toDouble(),
      source: json['source'] as String?,
      size: json['size'] as int,
      hasTranscript: json['hasTranscript'] as bool,
      audioUrl: json['audioUrl'] as String,
      transcriptUrl: json['transcriptUrl'] as String?,
      transcript: json['transcript'] as String?,
      deviceId: json['deviceId'] as String?,
      buttonTapCount: json['buttonTapCount'] as int?,
    );
  }
}
