import 'package:uuid/uuid.dart';

import '../adapters/storage/storage_repo.dart';
import 'models/child_profile.dart';

/// Manages child accounts. Pure orchestration over the [StorageRepo] port.
/// See `docs/architecture.md`.
class ProfileService {
  ProfileService(this._repo, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final StorageRepo _repo;
  final Uuid _uuid;

  Future<List<ChildProfile>> all() => _repo.loadProfiles();

  Future<ChildProfile?> byId(String id) => _repo.loadProfile(id);

  Future<ChildProfile> create({
    required String displayName,
    required int age,
    String language = 'en',
    DetailLevel detailLevel = DetailLevel.medium,
    int themeColor = 0xFF6750A4,
    String? parentBrief,
  }) async {
    final profile = ChildProfile(
      id: _uuid.v4(),
      displayName: displayName,
      age: age,
      language: language,
      detailLevel: detailLevel,
      themeColor: themeColor,
      parentBrief: parentBrief,
    );
    await _repo.saveProfile(profile);
    return profile;
  }

  Future<void> update(ChildProfile profile) => _repo.saveProfile(profile);

  Future<void> delete(String id) => _repo.deleteProfile(id);
}
