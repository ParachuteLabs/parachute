import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/space.dart';
import '../widgets/space_files_widget.dart';

class SpaceFilesScreen extends ConsumerWidget {
  final Space space;

  const SpaceFilesScreen({
    super.key,
    required this.space,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Files', style: TextStyle(fontSize: 18)),
            Text(
              space.name,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
      body: SpaceFilesWidget(space: space),
    );
  }
}
