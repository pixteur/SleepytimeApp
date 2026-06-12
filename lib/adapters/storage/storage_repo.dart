import '../../domain/models/child_profile.dart';
import '../../domain/models/interest.dart';
import '../../domain/models/learned_profile.dart';
import '../../domain/models/quiz_result.dart';

/// Local-only persistence at launch; the same interface backs optional cloud
/// sync later. Backed by Drift (SQLite). Series/Beats are added in Phase 2.
/// Domain code depends on this port, never on Drift directly.
/// See `docs/data-model.md`.
abstract class StorageRepo {
  // ── Child profiles ──────────────────────────────────────────────
  Future<List<ChildProfile>> loadProfiles();
  Future<ChildProfile?> loadProfile(String id);
  Future<void> saveProfile(ChildProfile profile);
  Future<void> deleteProfile(String id);

  // ── Quiz results ────────────────────────────────────────────────
  Future<void> saveQuizResult(QuizResult result);
  Future<QuizResult?> latestQuizResult(String childId);

  // ── Interests ───────────────────────────────────────────────────
  Future<List<Interest>> loadInterests(String childId);
  Future<void> saveInterest(Interest interest);
  Future<void> deleteInterest(String id);

  // ── Learned profile ─────────────────────────────────────────────
  Future<LearnedProfile?> loadLearnedProfile(String childId);
  Future<void> saveLearnedProfile(LearnedProfile profile);
}
