import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/file_info.dart';
import '../../../core/providers/api_provider.dart';

// Current path provider
final currentPathProvider = StateProvider<String>((ref) => '');

// Browse result provider (depends on current path)
final browseResultProvider = FutureProvider<BrowseResult>((ref) async {
  final path = ref.watch(currentPathProvider);
  final apiClient = ref.watch(apiClientProvider);
  return apiClient.browseFiles(path: path);
});

// Selected file provider (for preview/download)
final selectedFileProvider = StateProvider<FileInfo?>((ref) => null);

// File browser actions provider
final fileBrowserActionsProvider = Provider((ref) => FileBrowserActions(ref));

class FileBrowserActions {
  final Ref ref;

  FileBrowserActions(this.ref);

  void navigateToPath(String path) {
    ref.read(currentPathProvider.notifier).state = path;
    ref.read(selectedFileProvider.notifier).state = null;
  }

  void navigateUp() {
    final current = ref.read(currentPathProvider);
    if (current.isEmpty) return;

    final parts = current.split('/');
    parts.removeLast();
    final parent = parts.join('/');
    
    navigateToPath(parent);
  }

  void navigateToRoot() {
    navigateToPath('');
  }

  void selectFile(FileInfo file) {
    ref.read(selectedFileProvider.notifier).state = file;
  }

  void clearSelection() {
    ref.read(selectedFileProvider.notifier).state = null;
  }

  Future<String> readFile(String path) async {
    final apiClient = ref.read(apiClientProvider);
    return apiClient.readFile(path);
  }

  String getDownloadUrl(String path) {
    final apiClient = ref.read(apiClientProvider);
    return apiClient.getDownloadUrl(path);
  }

  void refresh() {
    ref.invalidate(browseResultProvider);
  }
}
