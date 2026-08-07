import 'package:uuid/uuid.dart';

import '../adapters/storage/storage_repo.dart';
import 'models/series.dart';
import 'models/world.dart';

/// Manages a child's story "universes" (the bookshelf). Each [World] holds a
/// premise + characters and spawns many episodes. See `docs/data-model.md`.
class WorldService {
  WorldService(this._repo, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final StorageRepo _repo;
  final Uuid _uuid;

  Future<List<World>> forChild(String childId) => _repo.loadWorlds(childId);

  Future<World> create({
    required String childId,
    required String name,
    String premise = '',
    StoryTheme theme = StoryTheme.cozy,
    List<StoryTheme> extraThemes = const [],
  }) async {
    final world = World(
      id: _uuid.v4(),
      childId: childId,
      name: name,
      premise: premise,
      theme: theme,
      extraThemes: extraThemes,
    );
    await _repo.saveWorld(world);
    return world;
  }

  Future<void> update(World world) => _repo.saveWorld(world);

  /// Delete a world and (via FK cascade) its characters + episodes.
  Future<void> delete(String id) => _repo.deleteWorld(id);
}
