import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/services/file_sync_service.dart';

/// Provider for FileSyncService
final fileSyncServiceProvider = Provider<FileSyncService>((ref) {
  final service = FileSyncService(baseUrl: 'http://localhost:8080');

  // Cleanup when provider is disposed
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});
