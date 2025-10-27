import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/file_info.dart';
import '../../../core/models/space.dart';
import '../../../core/providers/api_provider.dart';
import '../screens/markdown_preview_screen.dart';

class SpaceFilesWidget extends ConsumerStatefulWidget {
  final Space space;

  const SpaceFilesWidget({super.key, required this.space});

  @override
  ConsumerState<SpaceFilesWidget> createState() => _SpaceFilesWidgetState();
}

class _SpaceFilesWidgetState extends ConsumerState<SpaceFilesWidget> {
  Future<BrowseResult>? _browseFuture;
  String _currentPath = '';
  String _initialPath = '';

  @override
  void initState() {
    super.initState();
    // Extract relative path from absolute path if needed
    final spacePath = widget.space.path;
    if (spacePath.startsWith('/')) {
      // Absolute path - extract the part after Parachute/
      final parts = spacePath.split('/Parachute/');
      _currentPath = parts.length > 1
          ? parts[1]
          : 'spaces/${spacePath.split('/').last}';
    } else {
      // Already relative
      _initialPath = spacePath.startsWith('spaces/')
          ? spacePath
          : 'spaces/$spacePath';
    }
    _currentPath = _initialPath;
    _loadFiles();
  }

  void _loadFiles() {
    final apiClient = ref.read(apiClientProvider);
    setState(() {
      _browseFuture = apiClient.browseFiles(path: _currentPath);
    });
  }

  void _navigateToPath(String path) {
    setState(() {
      _currentPath = path;
      _loadFiles();
    });
  }

  void _navigateUp() {
    if (_currentPath == _initialPath) return;

    final parts = _currentPath.split('/');
    parts.removeLast();
    _navigateToPath(parts.join('/'));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BrowseResult>(
      future: _browseFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadFiles,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final result = snapshot.data;
        if (result == null) {
          return const Center(child: Text('No data'));
        }

        final allItems = [...result.directories, ...result.files];

        return Column(
          children: [
            // Path breadcrumb
            if (_currentPath != _initialPath)
              Container(
                padding: const EdgeInsets.all(8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _navigateUp,
                      tooltip: 'Go back',
                    ),
                    Expanded(
                      child: Text(
                        _currentPath.replaceFirst(
                          'spaces/${widget.space.path}/',
                          '',
                        ),
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            // File list
            Expanded(
              child: allItems.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Empty folder',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: allItems.length,
                      itemBuilder: (context, index) {
                        final item = allItems[index];
                        return _buildFileItem(context, item);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFileItem(BuildContext context, FileInfo item) {
    IconData icon;
    Color? iconColor;

    if (item.isDirectory) {
      icon = Icons.folder;
      iconColor = Colors.blue;
    } else if (item.isMarkdown) {
      icon = Icons.description;
      iconColor = Colors.green;
    } else if (item.isAudio) {
      icon = Icons.audiotrack;
      iconColor = Colors.orange;
    } else {
      icon = Icons.insert_drive_file;
      iconColor = Colors.grey;
    }

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(item.name),
      subtitle: item.isDirectory
          ? null
          : Text('${item.formattedSize} • ${_formatDate(item.modifiedAt)}'),
      trailing: !item.isDirectory && item.isMarkdown
          ? IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: () => _previewMarkdown(context, item),
              tooltip: 'Preview',
            )
          : item.isDirectory
          ? const Icon(Icons.chevron_right)
          : null,
      onTap: () {
        if (item.isDirectory) {
          _navigateToPath(item.path);
        } else if (item.isMarkdown) {
          _previewMarkdown(context, item);
        }
      },
    );
  }

  void _previewMarkdown(BuildContext context, FileInfo file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarkdownPreviewScreen(filePath: file.path),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}
