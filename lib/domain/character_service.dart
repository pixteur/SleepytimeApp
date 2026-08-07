import 'package:uuid/uuid.dart';

import '../adapters/storage/storage_repo.dart';
import 'models/story_character.dart';

/// Manages the reusable cast of characters within a [World]. Selected when
/// starting an episode so the universe stays consistent.
///
/// Adding or removing a character changes every story that follows, so each
/// edit is recorded on the world as a pending cast change: arrivals get
/// introduced, and a removed character is written out gently by the next story
/// instead of silently vanishing. See `docs/data-model.md`.
class CharacterService {
  CharacterService(this._repo, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final StorageRepo _repo;
  final Uuid _uuid;

  Future<List<StoryCharacter>> forWorld(String worldId) =>
      _repo.loadCharacters(worldId);

  Future<StoryCharacter> create({
    required String worldId,
    required String name,
    String description = '',
  }) async {
    final character = StoryCharacter(
      id: _uuid.v4(),
      worldId: worldId,
      name: name,
      description: description,
    );
    await _repo.saveCharacter(character);
    final world = await _repo.loadWorldById(worldId);
    if (world != null) {
      await _repo.saveWorld(
        world.copyWith(
          pendingCastChanges: world.pendingCastChanges.withJoined(
            character.promptLine,
          ),
        ),
      );
    }
    return character;
  }

  Future<void> update(StoryCharacter character) =>
      _repo.saveCharacter(character);

  /// Remove a character and queue their send-off for the next story.
  Future<void> delete(StoryCharacter character) async {
    final world = await _repo.loadWorldById(character.worldId);
    if (world != null) {
      await _repo.saveWorld(
        world.copyWith(
          pendingCastChanges: world.pendingCastChanges.withLeft(
            character.promptLine,
            name: character.name,
          ),
        ),
      );
    }
    await _repo.deleteCharacter(character.id);
  }
}
