import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/file_info.dart';
import '../providers/local_file_browser_provider.dart';
import '../../settings/screens/settings_screen.dart';
import 'markdown_preview_screen.dart';

class FileBrowserScreen extends ConsumerWidget {
  const FileBrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browseResultAsync = ref.watch(localBrowseResultProvider);
    final currentPath = ref.watch(localCurrentPathProvider);
    final actions = ref.read(localFileBrowserActionsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.folder),
          onPressed: currentPath.isNotEmpty ? actions.navigateToRoot : null,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Files', style: TextStyle(fontSize: 18)),
            if (currentPath.isNotEmpty)
              Text(
                currentPath,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
        actions: [
          if (currentPath.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              onPressed: actions.navigateUp,
              tooltip: 'Go up',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: actions.refresh,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: browseResultAsync.when(
        data: (result) => _buildFileList(context, ref, result, actions),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: actions.refresh,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileList(
    BuildContext context,
    WidgetRef ref,
    BrowseResult result,
    LocalFileBrowserActions actions,
  ) {
    final allItems = [...result.directories, ...result.files];

    if (allItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Empty directory',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];
        return _buildFileListItem(context, ref, item, actions);
      },
    );
  }

  Widget _buildFileListItem(
    BuildContext context,
    WidgetRef ref,
    FileInfo item,
    LocalFileBrowserActions actions,
  ) {
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
          ? const Text('Folder')
          : Text('${item.formattedSize} • ${_formatDate(item.modifiedAt)}'),
      trailing: !item.isDirectory
          ? PopupMenuButton<String>(
              onSelected: (value) =>
                  _handleFileAction(context, ref, item, value, actions),
              itemBuilder: (context) => [
                if (item.isMarkdown)
                  const PopupMenuItem(
                    value: 'preview',
                    child: Row(
                      children: [
                        Icon(Icons.visibility),
                        SizedBox(width: 8),
                        Text('Preview'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'show',
                  child: Row(
                    children: [
                      Icon(Icons.folder_open),
                      SizedBox(width: 8),
                      Text('Show in Finder'),
                    ],
                  ),
                ),
              ],
            )
          : const Icon(Icons.chevron_right),
      onTap: () {
        if (item.isDirectory) {
          actions.navigateToPath(item.path);
        } else if (item.isMarkdown) {
          _previewMarkdown(context, ref, item, actions);
        } else {
          _showFileOptions(context, ref, item, actions);
        }
      },
    );
  }

  void _handleFileAction(
    BuildContext context,
    WidgetRef ref,
    FileInfo file,
    String action,
    LocalFileBrowserActions actions,
  ) {
    switch (action) {
      case 'preview':
        _previewMarkdown(context, ref, file, actions);
        break;
      case 'show':
        _showInFinder(context, file, actions);
        break;
    }
  }

  void _previewMarkdown(
    BuildContext context,
    WidgetRef ref,
    FileInfo file,
    LocalFileBrowserActions actions,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarkdownPreviewScreen(filePath: file.path),
      ),
    );
  }

  void _showInFinder(
    BuildContext context,
    FileInfo file,
    LocalFileBrowserActions actions,
  ) {
    // Local files are already on disk
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('File: ${file.name}'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
    // TODO: Implement platform-specific "show in finder/explorer" functionality
  }

  void _showFileOptions(
    BuildContext context,
    WidgetRef ref,
    FileInfo file,
    LocalFileBrowserActions actions,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('Show in Finder'),
            onTap: () {
              Navigator.pop(context);
              _showInFinder(context, file, actions);
            },
          ),
        ],
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
