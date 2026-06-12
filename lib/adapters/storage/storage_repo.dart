import '../../domain/models/child_profile.dart';

/// Local-only persistence at launch; the same interface backs optional cloud
/// sync later. DB choice is Drift (SQLite). Full CRUD (series, beats, quiz,
/// learned profile) arrives in Phases 1–2. See `docs/data-model.md`.
abstract class StorageRepo {
  Future<List<ChildProfile>> loadProfiles();
  Future<void> saveProfile(ChildProfile profile);
  Future<void> deleteProfile(String id);
}
