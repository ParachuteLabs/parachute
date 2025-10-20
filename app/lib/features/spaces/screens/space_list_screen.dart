import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/space_provider.dart';
import '../widgets/create_space_dialog.dart';

class SpaceListScreen extends ConsumerWidget {
  const SpaceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaceListAsync = ref.watch(spaceListProvider);
    final selectedSpace = ref.watch(selectedSpaceProvider);
    final spaceActions = ref.watch(spaceActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parachute'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateSpaceDialog(context, ref),
            tooltip: 'Create Space',
          ),
        ],
      ),
      body: spaceListAsync.when(
        data: (spaces) {
          if (spaces.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No spaces yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a space to get started',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateSpaceDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Space'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: spaces.length,
            itemBuilder: (context, index) {
              final space = spaces[index];
              final isSelected = selectedSpace?.id == space.id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: isSelected ? 4 : 1,
                color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                child: ListTile(
                  leading: Icon(
                    Icons.folder,
                    color: isSelected ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: Text(
                    space.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    space.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref, space.id, space.name),
                  ),
                  onTap: () {
                    spaceActions.selectSpace(space);
                    Navigator.pushNamed(context, '/conversations');
                  },
                ),
              );
            },
          );
        },
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
                onPressed: () => ref.invalidate(spaceListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateSpaceDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const CreateSpaceDialog(),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Space'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(spaceActionsProvider).deleteSpace(id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deleted "$name"')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting space: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
