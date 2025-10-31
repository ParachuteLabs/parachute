import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/title_generation_service.dart';
import '../services/smollm_model_manager.dart';

/// Provider for the SmolLM model manager
final smollmModelManagerProvider = Provider<SmolLMModelManager>((ref) {
  final manager = SmolLMModelManager();
  ref.onDispose(() {
    manager.dispose();
  });
  return manager;
});

/// Provider for the title generation service
final titleGenerationServiceProvider = Provider<TitleGenerationService>((ref) {
  final modelManager = ref.watch(smollmModelManagerProvider);
  final service = TitleGenerationService(modelManager);

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});
