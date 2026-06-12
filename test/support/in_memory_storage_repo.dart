import 'package:sleepytime/adapters/storage/storage_repo.dart';
import 'package:sleepytime/domain/models/child_profile.dart';
import 'package:sleepytime/domain/models/interest.dart';
import 'package:sleepytime/domain/models/learned_profile.dart';
import 'package:sleepytime/domain/models/quiz_result.dart';

/// A pure-Dart [StorageRepo] for tests — no Drift, no native sqlite, no
/// platform channels. The real DriftStorageRepo is exercised at app runtime.
class InMemoryStorageRepo implements StorageRepo {
  final Map<String, ChildProfile> _profiles = {};
  final Map<String, List<QuizResult>> _quiz = {};
  final Map<String, Interest> _interests = {};
  final Map<String, LearnedProfile> _learned = {};

  @override
  Future<List<ChildProfile>> loadProfiles() async => _profiles.values.toList();

  @override
  Future<ChildProfile?> loadProfile(String id) async => _profiles[id];

  @override
  Future<void> saveProfile(ChildProfile profile) async =>
      _profiles[profile.id] = profile;

  @override
  Future<void> deleteProfile(String id) async => _profiles.remove(id);

  @override
  Future<void> saveQuizResult(QuizResult result) async =>
      (_quiz[result.childId] ??= []).add(result);

  @override
  Future<QuizResult?> latestQuizResult(String childId) async {
    final list = _quiz[childId];
    return (list == null || list.isEmpty) ? null : list.last;
  }

  @override
  Future<List<Interest>> loadInterests(String childId) async =>
      _interests.values.where((i) => i.childId == childId).toList();

  @override
  Future<void> saveInterest(Interest interest) async =>
      _interests[interest.id] = interest;

  @override
  Future<void> deleteInterest(String id) async => _interests.remove(id);

  @override
  Future<LearnedProfile?> loadLearnedProfile(String childId) async =>
      _learned[childId];

  @override
  Future<void> saveLearnedProfile(LearnedProfile profile) async =>
      _learned[profile.childId] = profile;
}
