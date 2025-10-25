import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:app/features/recorder/services/storage_service.dart';

/// Service for transcribing audio using OpenAI's Whisper API
///
/// Usage:
/// 1. Configure your API key in Settings (tap the gear icon in the app)
/// 2. Call transcribeAudio() with the path to your audio file
///
/// Cost: ~$0.006 per minute of audio
/// Supported formats: mp3, mp4, mpeg, mpga, m4a, wav, webm
class WhisperService {
  final StorageService _storageService;

  WhisperService(this._storageService);

  /// Transcribes an audio file using OpenAI's Whisper API
  ///
  /// [audioPath] - Absolute path to the audio file
  /// [language] - Optional ISO-639-1 language code (e.g., 'en', 'es', 'fr')
  ///              If not specified, Whisper will auto-detect the language
  /// [prompt] - Optional prompt to guide the transcription style
  ///
  /// Returns the transcribed text
  /// Throws [WhisperException] if transcription fails
  Future<String> transcribeAudio(
    String audioPath, {
    String? language,
    String? prompt,
  }) async {
    // Get API key from storage
    final apiKey = await _storageService.getOpenAIApiKey();

    // Validate API key
    if (apiKey == null || apiKey.isEmpty) {
      throw WhisperException(
        'OpenAI API key not configured. '
        'Please add your API key in Settings.',
      );
    }

    // Validate file exists
    final file = File(audioPath);
    if (!await file.exists()) {
      throw WhisperException('Audio file not found: $audioPath');
    }

    try {
      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
      );

      // Add headers
      request.headers['Authorization'] = 'Bearer $apiKey';

      // Add form fields
      request.fields['model'] = 'whisper-1';
      if (language != null) {
        request.fields['language'] = language;
      }
      if (prompt != null) {
        request.fields['prompt'] = prompt;
      }

      // Add audio file
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        audioPath,
      ));

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Check response status
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final text = jsonResponse['text'] as String? ?? '';
        return text;
      } else {
        // Parse error response
        try {
          final errorBody = jsonDecode(response.body);
          final errorMessage =
              errorBody['error']?['message'] ?? 'Unknown error';
          throw WhisperException(
            'Whisper API error (${response.statusCode}): $errorMessage',
          );
        } catch (e) {
          throw WhisperException(
            'Whisper API error (${response.statusCode}): Failed to parse error response',
          );
        }
      }
    } on SocketException {
      throw WhisperException(
        'Network error: Please check your internet connection',
      );
    } on FormatException {
      throw WhisperException(
        'Invalid response from Whisper API',
      );
    } catch (e) {
      if (e is WhisperException) rethrow;
      throw WhisperException('Unexpected error: ${e.toString()}');
    }
  }

  /// Check if the API key is configured
  Future<bool> isConfigured() async {
    return await _storageService.hasOpenAIApiKey();
  }
}

/// Custom exception for Whisper API errors
class WhisperException implements Exception {
  final String message;

  WhisperException(this.message);

  @override
  String toString() => message;
}
