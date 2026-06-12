import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adapters/ai/ai_provider.dart';
import 'adapters/ai/fake_ai_provider.dart';
import 'adapters/storage/app_database.dart';
import 'adapters/storage/drift_storage_repo.dart';
import 'adapters/storage/storage_repo.dart';
import 'domain/models/child_profile.dart';
import 'domain/profile_service.dart';
import 'domain/quiz_service.dart';
import 'domain/story_engine.dart';

// ─── AI / story ───────────────────────────────────────────────────────

/// The active AI provider. Phase 0 uses [FakeAiProvider] so everything runs
/// offline with no API key; later phases swap this based on settings
/// (Claude / OpenAI / Gemini / hosted). See `docs/ai-providers.md`.
final aiProvider = Provider<AiProvider>((ref) => const FakeAiProvider());

/// The story engine, wired to whatever [aiProvider] currently resolves to.
final storyEngineProvider = Provider<StoryEngine>(
  (ref) => StoryEngine(ref.watch(aiProvider)),
);

// ─── Storage ──────────────────────────────────────────────────────────

/// The on-device Drift database. Opened lazily; closed when disposed.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final storageRepoProvider = Provider<StorageRepo>(
  (ref) => DriftStorageRepo(ref.watch(databaseProvider)),
);

// ─── Domain services ──────────────────────────────────────────────────

final profileServiceProvider = Provider<ProfileService>(
  (ref) => ProfileService(ref.watch(storageRepoProvider)),
);

final quizServiceProvider = Provider<QuizService>(
  (ref) => QuizService(ref.watch(storageRepoProvider)),
);

/// All child profiles. Invalidate after create/edit/delete to refresh the UI.
final profilesProvider = FutureProvider<List<ChildProfile>>(
  (ref) => ref.watch(profileServiceProvider).all(),
);

/// The currently selected child (null = none chosen yet).
final activeChildProvider = NotifierProvider<ActiveChild, ChildProfile?>(
  ActiveChild.new,
);

class ActiveChild extends Notifier<ChildProfile?> {
  @override
  ChildProfile? build() => null;

  void select(ChildProfile? child) => state = child;
}
