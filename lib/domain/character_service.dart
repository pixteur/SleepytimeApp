import 'package:uuid/uuid.dart';

import '../adapters/storage/storage_repo.dart';
import 'models/story_character.dart';

/// Manages the reusable cast of characters within a [World]. Selected when
/// starting an episode so the universe stays consistent. See `docs/data-model.md`.
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
    return character;
  }

  Future<void> update(StoryCharacter character) =>
      _repo.saveCharacter(character);

  Future<void> delete(String id) => _repo.deleteCharacter(id);
}
