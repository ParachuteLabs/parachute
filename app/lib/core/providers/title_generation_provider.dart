import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/models/title_generation_models.dart';
import 'package:app/core/services/title_generation_service.dart';
import 'package:app/core/services/gemma_model_manager.dart';
import 'package:app/features/recorder/providers/service_providers.dart';

/// Provider for the Gemma model manager
final gemmaModelManagerProvider = Provider<GemmaModelManager>((ref) {
  return GemmaModelManager();
});

/// Provider for the title generation service
final titleGenerationServiceProvider = Provider<TitleGenerationService>((ref) {
  final gemmaManager = ref.watch(gemmaModelManagerProvider);

  // Create service with all required dependencies
  final service = TitleGenerationService(
    // Get Gemini API key
    () async {
      final storageService = ref.read(storageServiceProvider);
      return await storageService.getGeminiApiKey();
    },
    // Get title generation mode
    () async {
      final storageService = ref.read(storageServiceProvider);
      final modeString = await storageService.getTitleGenerationMode();
      return TitleModelMode.fromString(modeString) ?? TitleModelMode.api;
    },
    // Get preferred Gemma model
    () async {
      final storageService = ref.read(storageServiceProvider);
      final modelString = await storageService.getPreferredGemmaModel();
      if (modelString == null) return null;
      return GemmaModelType.fromString(modelString);
    },
    gemmaManager,
  );

  ref.onDispose(() async {
    await service.dispose();
  });

  return service;
});
