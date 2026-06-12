import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adapters/ai/ai_provider.dart';
import 'adapters/ai/claude_provider.dart';
import 'adapters/ai/fake_ai_provider.dart';
import 'adapters/ai/gemini_provider.dart';
import 'adapters/ai/openai_provider.dart';
import 'adapters/prefs/app_prefs.dart';
import 'adapters/secrets/dpapi_secret_store.dart';
import 'adapters/secrets/secret_store.dart';
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

/// OS-secure storage for API keys (Windows DPAPI).
final secretStoreProvider = Provider<SecretStore>((ref) => DpapiSecretStore());

/// Map a stored provider name to its id (defaults to Claude).
ProviderId providerIdFromName(String name) => switch (name) {
  'openai' => ProviderId.openai,
  'gemini' => ProviderId.gemini,
  _ => ProviderId.claude,
};

/// The SecretStore key name for a real provider, or null for fake/hosted.
String? keyNameFor(ProviderId id) => switch (id) {
  ProviderId.claude => ClaudeProvider.keyName,
  ProviderId.openai => OpenAiProvider.keyName,
  ProviderId.gemini => GeminiProvider.keyName,
  ProviderId.hosted || ProviderId.fake => null,
};

/// Which AI backend is active. Defaults to [ProviderId.fake] (offline, no key)
/// and upgrades to the parent-selected provider only when its key is stored AND
/// third-party-AI consent is given (per CLAUDE.md). Settings calls
/// [AiConfigController.refresh] after changes.
final aiConfigProvider = NotifierProvider<AiConfigController, ProviderId>(
  AiConfigController.new,
);

class AiConfigController extends Notifier<ProviderId> {
  @override
  ProviderId build() {
    _hydrate();
    return ProviderId.fake;
  }

  Future<void> _hydrate() async => state = await _resolve();

  Future<ProviderId> _resolve() async {
    final prefs = await AppPrefs.open();
    if (!prefs.aiConsentGiven) return ProviderId.fake;
    final selected = providerIdFromName(prefs.selectedProvider);
    final keyName = keyNameFor(selected);
    if (keyName == null) return ProviderId.fake;
    final hasKey = await ref.read(secretStoreProvider).hasKey(keyName);
    return hasKey ? selected : ProviderId.fake;
  }

  Future<void> refresh() async => state = await _resolve();
}

/// The active AI provider — the configured + consented one, else the offline
/// [FakeAiProvider]. See `docs/ai-providers.md`.
final aiProvider = Provider<AiProvider>((ref) {
  final secrets = ref.watch(secretStoreProvider);
  return switch (ref.watch(aiConfigProvider)) {
    ProviderId.claude => ClaudeProvider(secrets: secrets),
    ProviderId.openai => OpenAiProvider(secrets: secrets),
    ProviderId.gemini => GeminiProvider(secrets: secrets),
    ProviderId.hosted || ProviderId.fake => const FakeAiProvider(),
  };
});

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
