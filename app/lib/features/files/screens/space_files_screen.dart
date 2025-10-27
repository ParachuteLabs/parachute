import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/space.dart';
import '../widgets/space_files_widget.dart';
import '../../space_notes/widgets/space_notes_widget.dart';

class SpaceFilesScreen extends ConsumerWidget {
  final Space space;

  const SpaceFilesScreen({super.key, required this.space});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(space.name, style: const TextStyle(fontSize: 18)),
              Text(
                'Browse files and linked notes',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.folder), text: 'Files'),
              Tab(icon: Icon(Icons.link), text: 'Linked Notes'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SpaceFilesWidget(space: space),
            SpaceNotesWidget(spaceId: space.id, spaceName: space.name),
          ],
        ),
      ),
    );
  }
}
