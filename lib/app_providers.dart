import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adapters/ai/ai_provider.dart';
import 'adapters/ai/fake_ai_provider.dart';
import 'adapters/storage/app_database.dart';
import 'adapters/storage/drift_storage_repo.dart';
import 'adapters/storage/storage_repo.dart';
import 'domain/models/beat.dart';
import 'domain/models/child_profile.dart';
import 'domain/models/series.dart';
import 'domain/profile_service.dart';
import 'domain/quiz_service.dart';
import 'domain/series_service.dart';
import 'domain/story_engine.dart';
import 'domain/twist_deck.dart';

// ─── AI / story ───────────────────────────────────────────────────────

/// The active AI provider. Phase 0 uses [FakeAiProvider] so everything runs
/// offline with no API key; later phases swap this based on settings
/// (Claude / OpenAI / Gemini / hosted). See `docs/ai-providers.md`.
final aiProvider = Provider<AiProvider>((ref) => const FakeAiProvider());

/// The story engine, wired to the active provider + storage.
final storyEngineProvider = Provider<StoryEngine>(
  (ref) => StoryEngine(
    ai: ref.watch(aiProvider),
    repo: ref.watch(storageRepoProvider),
  ),
);

/// The twist deck (six option cards + dice).
final twistDeckProvider = Provider<TwistDeck>((ref) => const TwistDeck());

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

final seriesServiceProvider = Provider<SeriesService>(
  (ref) => SeriesService(ref.watch(storageRepoProvider)),
);

/// Active (non-archived) series for a given child — the story library.
/// Invalidate after creating/archiving a series to refresh.
final seriesForChildProvider = FutureProvider.family<List<Series>, String>(
  (ref, childId) => ref.watch(seriesServiceProvider).forChild(childId),
);

/// The currently open series (null = none).
final activeSeriesProvider = NotifierProvider<ActiveSeries, Series?>(
  ActiveSeries.new,
);

class ActiveSeries extends Notifier<Series?> {
  @override
  Series? build() => null;

  void select(Series? series) => state = series;
}

/// All beats for a series, oldest→newest. Invalidate after a new turn.
final beatsForSeriesProvider = FutureProvider.family<List<Beat>, String>(
  (ref, seriesId) => ref.watch(storageRepoProvider).loadBeats(seriesId),
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
