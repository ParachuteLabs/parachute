import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service for generating semantic titles from transcripts
///
/// Uses Google Gemini 2.5 Flash Lite API for intelligent title generation.
/// Falls back to simple extraction (first 6 words) if API fails or no key.
class TitleGenerationService {
  final Future<String?> Function() _getApiKey;

  TitleGenerationService(this._getApiKey);

  /// Generate a concise title from a transcript
  ///
  /// Attempts to use Gemini API for intelligent title generation.
  /// Falls back to simple extraction (first 6 words) if API fails.
  Future<String?> generateTitle(
    String transcript, {
    dynamic preferredModel,
  }) async {
    if (transcript.trim().isEmpty) {
      debugPrint('[TitleGen] Empty transcript, returning default');
      return 'Voice Note';
    }

    try {
      // Try Gemini API first
      final apiKey = await _getApiKey();
      debugPrint(
        '[TitleGen] API key present: ${apiKey != null && apiKey.isNotEmpty}',
      );

      if (apiKey != null && apiKey.isNotEmpty) {
        debugPrint('[TitleGen] Attempting Gemini API title generation...');
        final geminiTitle = await _generateWithGemini(transcript, apiKey);
        if (geminiTitle != null && geminiTitle.isNotEmpty) {
          debugPrint('[TitleGen] ✅ Gemini generated title: "$geminiTitle"');
          return geminiTitle;
        } else {
          debugPrint('[TitleGen] ⚠️ Gemini returned empty/null title');
        }
      } else {
        debugPrint('[TitleGen] No API key configured, using fallback');
      }
    } catch (e) {
      debugPrint('[TitleGen] ❌ Gemini title generation failed: $e');
      // Fall through to fallback
    }

    // Fallback to simple extraction
    final fallbackTitle = _generateFallbackTitle(transcript);
    debugPrint('[TitleGen] Using fallback title: "$fallbackTitle"');
    return fallbackTitle;
  }

  /// Generate title using Gemini API
  Future<String?> _generateWithGemini(String transcript, String apiKey) async {
    // Truncate very long transcripts (keep first ~500 chars)
    final truncated = transcript.length > 500
        ? '${transcript.substring(0, 500)}...'
        : transcript;

    debugPrint(
      '[TitleGen] Transcript length: ${transcript.length}, truncated: ${truncated.length}',
    );

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$apiKey',
    );

    final body = {
      'contents': [
        {
          'parts': [
            {
              'text':
                  '''Generate a concise 5-8 word title for this voice recording transcript. Only return the title text, no quotes or extra punctuation.

Transcript: "$truncated"

Title:''',
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 20,
        'topP': 0.8,
      },
    };

    debugPrint('[TitleGen] Sending request to Gemini API...');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('[TitleGen] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint(
          '[TitleGen] Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}',
        );

        final data = json.decode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text'] as String?;
            debugPrint('[TitleGen] Raw Gemini response: "$text"');
            if (text != null) {
              final cleaned = _cleanGeneratedTitle(text);
              debugPrint('[TitleGen] Cleaned title: "$cleaned"');
              return cleaned;
            }
          }
        }
        debugPrint('[TitleGen] ⚠️ No candidates in response');
      } else {
        debugPrint('[TitleGen] ❌ Gemini API error: ${response.statusCode}');
        debugPrint('[TitleGen] Error body: ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('[TitleGen] ❌ Gemini API request failed: $e');
      debugPrint('[TitleGen] Stack trace: $stackTrace');
    }

    return null;
  }

  /// Clean up generated title text
  String _cleanGeneratedTitle(String rawTitle) {
    // Remove common artifacts
    String cleaned = rawTitle.trim();

    // Remove quotation marks
    cleaned = cleaned.replaceAll(RegExp(r'''^["']|["']$'''), '');

    // Remove "Title:" prefix if present
    cleaned = cleaned.replaceAll(
      RegExp(r'^Title:\s*', caseSensitive: false),
      '',
    );

    // Remove trailing punctuation (except ...)
    if (!cleaned.endsWith('...')) {
      cleaned = cleaned.replaceAll(RegExp(r'[.!?]+$'), '');
    }

    // Limit to reasonable length (max 8 words)
    final words = cleaned.split(RegExp(r'\s+'));
    if (words.length > 8) {
      cleaned = '${words.take(8).join(' ')}...';
    }

    // Fallback if somehow empty
    if (cleaned.isEmpty) {
      return 'Voice Note';
    }

    return cleaned;
  }

  /// Fallback title generation (first 6 words)
  String _generateFallbackTitle(String transcript) {
    final cleaned = transcript.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (cleaned.isEmpty) {
      return 'Voice Note';
    }

    final words = cleaned.split(' ').take(6).toList();
    final title = words.join(' ');

    if (cleaned.split(' ').length > 6) {
      return '$title...';
    }

    return title;
  }

  /// Generate URL-safe slug from title
  String generateSlug(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// Generate semantic filename: YYYY-MM-DD_slug
  Future<String> generateFileName(
    String transcript,
    DateTime recordingTime, {
    dynamic preferredModel,
  }) async {
    final title = await generateTitle(
      transcript,
      preferredModel: preferredModel,
    );

    if (title == null || title.isEmpty || title == 'Voice Note') {
      // Fallback to timestamp-based name
      final timestamp = recordingTime
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      return timestamp.replaceAll('T', '_');
    }

    // Generate semantic filename: YYYY-MM-DD_slug
    final dateStr =
        '${recordingTime.year}-${recordingTime.month.toString().padLeft(2, '0')}-${recordingTime.day.toString().padLeft(2, '0')}';
    final slug = generateSlug(title);

    return '${dateStr}_$slug';
  }

  Future<void> dispose() async {
    // Nothing to dispose
  }
}
