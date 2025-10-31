import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/title_generation_service.dart';
import '../../features/recorder/providers/service_providers.dart';

/// Provider for the title generation service
final titleGenerationServiceProvider = Provider<TitleGenerationService>((ref) {
  // Pass a function that gets the Gemini API key from storage
  final service = TitleGenerationService(() async {
    final storageService = ref.read(storageServiceProvider);
    return await storageService.getGeminiApiKey();
  });

  ref.onDispose(() async {
    await service.dispose();
  });

  return service;
});
