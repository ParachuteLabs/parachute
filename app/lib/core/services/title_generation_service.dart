import 'dart:io';

/// Service for generating semantic titles from transcripts
///
/// NOTE: LLM integration temporarily disabled due to native library bundling complexity.
/// Currently uses simple fallback: extracts first 6 words from transcript.
///
/// TODO: Re-enable LLM integration once llama_cpp_dart packaging is resolved
class TitleGenerationService {
  final _modelManager;

  TitleGenerationService(this._modelManager);

  /// Generate a concise title from a transcript
  /// Currently uses fallback (first 6 words) until LLM integration is fixed
  Future<String?> generateTitle(String transcript, {preferredModel}) async {
    return _generateFallbackTitle(transcript);
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

  String generateSlug(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Future<String> generateFileName(
    String transcript,
    DateTime recordingTime, {
    preferredModel,
  }) async {
    final title = await generateTitle(
      transcript,
      preferredModel: preferredModel,
    );

    if (title == null || title.isEmpty || title == 'Voice Note') {
      final timestamp = recordingTime
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      return timestamp.replaceAll('T', '_');
    }

    final dateStr =
        '${recordingTime.year}-${recordingTime.month.toString().padLeft(2, '0')}-${recordingTime.day.toString().padLeft(2, '0')}';
    final slug = generateSlug(title);

    return '${dateStr}_$slug';
  }

  void dispose() {
    // Nothing to dispose in fallback mode
  }
}
