import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../providers/local_file_browser_provider.dart';

class MarkdownPreviewScreen extends ConsumerWidget {
  final String filePath;

  const MarkdownPreviewScreen({super.key, required this.filePath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(localFileBrowserActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(filePath.split('/').last, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () async {
              final absolutePath = await actions.getAbsolutePath(filePath);
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('File: $absolutePath')));
              }
            },
            tooltip: 'Show path',
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: actions.readFile(filePath),
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
                  Text('Error loading file: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final content = snapshot.data ?? '';

          return Markdown(
            data: content,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              p: const TextStyle(fontSize: 16, height: 1.5),
              code: TextStyle(
                backgroundColor: Colors.grey.shade200,
                fontFamily: 'monospace',
              ),
              codeblockDecoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        },
      ),
    );
  }
}
