import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../core/models/file_info.dart';
import '../../../core/services/file_system_service.dart';

/// Provider for FileSystemService
final fileSystemServiceProvider = Provider<FileSystemService>((ref) {
  return FileSystemService();
});

/// Current path provider (relative to ~/Parachute/)
final localCurrentPathProvider = StateProvider<String>((ref) => '');

/// Browse result provider for local files
final localBrowseResultProvider = FutureProvider<BrowseResult>((ref) async {
  final relativePath = ref.watch(localCurrentPathProvider);
  final fileSystem = ref.watch(fileSystemServiceProvider);

  return _browseLocalFiles(fileSystem, relativePath);
});

/// Get parent path from a relative path
String _getParentPath(String relativePath) {
  if (relativePath.isEmpty) return '';

  final parts = p.split(relativePath);
  if (parts.isEmpty || parts.length == 1) return '';

  parts.removeLast();
  return parts.isEmpty ? '' : p.joinAll(parts);
}

/// Browse local files in the ~/Parachute/ directory
Future<BrowseResult> _browseLocalFiles(
  FileSystemService fileSystem,
  String relativePath,
) async {
  try {
    final rootPath = await fileSystem.getRootPath();
    final fullPath = relativePath.isEmpty
        ? rootPath
        : p.join(rootPath, relativePath);

    debugPrint('[LocalFileBrowser] Browsing: $fullPath');

    final directory = Directory(fullPath);
    if (!await directory.exists()) {
      debugPrint('[LocalFileBrowser] Directory does not exist: $fullPath');
      return BrowseResult(
        path: relativePath,
        parent: _getParentPath(relativePath),
        directories: [],
        files: [],
      );
    }

    final directories = <FileInfo>[];
    final files = <FileInfo>[];

    await for (final entity in directory.list()) {
      try {
        final stat = await entity.stat();
        final name = p.basename(entity.path);

        // Skip hidden files/folders
        if (name.startsWith('.')) continue;

        // Calculate relative path from root
        final entityRelativePath = relativePath.isEmpty
            ? name
            : p.join(relativePath, name);

        // Determine file type
        final isDir = entity is Directory;
        final ext = isDir ? null : p.extension(name).toLowerCase();
        final isMarkdown = ext == '.md' || ext == '.markdown';
        final isAudio =
            ext == '.wav' || ext == '.mp3' || ext == '.m4a' || ext == '.opus';

        final fileInfo = FileInfo(
          name: name,
          path: entityRelativePath,
          size: stat.size,
          modifiedAt: stat.modified,
          isDirectory: isDir,
          extension: ext,
          isMarkdown: isMarkdown,
          isAudio: isAudio,
          downloadUrl: null, // Local files don't have download URLs
        );

        if (entity is Directory) {
          directories.add(fileInfo);
        } else {
          files.add(fileInfo);
        }
      } catch (e) {
        debugPrint('[LocalFileBrowser] Error processing ${entity.path}: $e');
      }
    }

    // Sort directories and files alphabetically
    directories.sort((a, b) => a.name.compareTo(b.name));
    files.sort((a, b) => a.name.compareTo(b.name));

    debugPrint(
      '[LocalFileBrowser] Found ${directories.length} dirs, ${files.length} files',
    );

    return BrowseResult(
      path: relativePath,
      parent: _getParentPath(relativePath),
      directories: directories,
      files: files,
    );
  } catch (e, stackTrace) {
    debugPrint('[LocalFileBrowser] Error browsing: $e');
    debugPrint('[LocalFileBrowser] Stack trace: $stackTrace');
    rethrow;
  }
}

/// Local file browser actions provider
final localFileBrowserActionsProvider = Provider(
  (ref) => LocalFileBrowserActions(ref),
);

class LocalFileBrowserActions {
  final Ref ref;

  LocalFileBrowserActions(this.ref);

  void navigateToPath(String path) {
    ref.read(localCurrentPathProvider.notifier).state = path;
  }

  void navigateUp() {
    final current = ref.read(localCurrentPathProvider);
    if (current.isEmpty) return;

    // Split path and remove last component
    final parts = p.split(current);
    if (parts.isEmpty) {
      navigateToRoot();
      return;
    }

    parts.removeLast();
    final parent = parts.isEmpty ? '' : p.joinAll(parts);

    navigateToPath(parent);
  }

  void navigateToRoot() {
    navigateToPath('');
  }

  void refresh() {
    ref.invalidate(localBrowseResultProvider);
  }

  /// Read a local file's content
  Future<String> readFile(String relativePath) async {
    final fileSystem = ref.read(fileSystemServiceProvider);
    final rootPath = await fileSystem.getRootPath();
    final fullPath = p.join(rootPath, relativePath);

    final file = File(fullPath);
    if (!await file.exists()) {
      throw Exception('File not found: $relativePath');
    }

    return await file.readAsString();
  }

  /// Get the absolute path for a file (for external operations)
  Future<String> getAbsolutePath(String relativePath) async {
    final fileSystem = ref.read(fileSystemServiceProvider);
    final rootPath = await fileSystem.getRootPath();
    return p.join(rootPath, relativePath);
  }
}
