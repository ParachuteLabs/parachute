import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/space.dart';
import '../../../core/providers/api_provider.dart';

// Space List Provider
final spaceListProvider = FutureProvider<List<Space>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return apiClient.getSpaces();
});

// Selected Space Provider
final selectedSpaceProvider = StateProvider<Space?>((ref) => null);

// Space Actions Provider
final spaceActionsProvider = Provider((ref) => SpaceActions(ref));

class SpaceActions {
  final Ref ref;

  SpaceActions(this.ref);

  Future<Space> createSpace({
    required String name,
    required String path,
  }) async {
    final apiClient = ref.read(apiClientProvider);
    final space = await apiClient.createSpace(name: name, path: path);

    // Refresh the space list
    ref.invalidate(spaceListProvider);

    return space;
  }

  Future<Space> updateSpace({
    required String id,
    String? name,
    String? path,
  }) async {
    final apiClient = ref.read(apiClientProvider);
    final space = await apiClient.updateSpace(id: id, name: name, path: path);

    // Refresh the space list
    ref.invalidate(spaceListProvider);

    return space;
  }

  Future<void> deleteSpace(String id) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.deleteSpace(id);

    // Clear selection if the deleted space was selected
    final selectedSpace = ref.read(selectedSpaceProvider);
    if (selectedSpace?.id == id) {
      ref.read(selectedSpaceProvider.notifier).state = null;
    }

    // Refresh the space list
    ref.invalidate(spaceListProvider);
  }

  void selectSpace(Space space) {
    ref.read(selectedSpaceProvider.notifier).state = space;
  }
}
