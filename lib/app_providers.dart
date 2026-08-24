import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'adapters/ai/ai_provider.dart';
import 'adapters/ai/claude_provider.dart';
import 'adapters/ai/fake_ai_provider.dart';
import 'adapters/ai/gemini_provider.dart';
import 'adapters/ai/model_catalog.dart';
import 'adapters/ai/openai_provider.dart';
import 'adapters/prefs/app_prefs.dart';
import 'adapters/secrets/dpapi_secret_store.dart';
import 'adapters/secrets/secret_store.dart';
import 'adapters/storage/app_database.dart';
import 'adapters/storage/drift_storage_repo.dart';
import 'adapters/storage/storage_repo.dart';
import 'adapters/tts/audio_cache.dart';
import 'adapters/tts/cloud_tts_provider.dart';
import 'adapters/tts/device_tts_provider.dart';
import 'adapters/tts/elevenlabs_tts_synthesizer.dart';
import 'adapters/tts/gemini_tts_synthesizer.dart';
import 'adapters/tts/openai_tts_synthesizer.dart';
import 'adapters/tts/tts_provider.dart';
import 'domain/character_service.dart';
import 'domain/models/beat.dart';
import 'domain/models/child_profile.dart';
import 'domain/models/series.dart';
import 'domain/models/story_character.dart';
import 'domain/models/world.dart';
import 'domain/profile_service.dart';
import 'domain/quiz_service.dart';
import 'domain/series_service.dart';
import 'domain/sleepy_service.dart';
import 'domain/story_engine.dart';
import 'domain/twist_deck.dart';
import 'domain/world_service.dart';

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

/// The story model chosen for the active provider — blank means "whatever the
/// adapter ships with". Kept apart from [aiConfigProvider] so switching
/// provider doesn't drag a Claude model id over to Gemini: the pref is keyed by
/// provider, and this re-reads it whenever the provider changes.
final textModelProvider = NotifierProvider<TextModelController, String>(
  TextModelController.new,
);

class TextModelController extends Notifier<String> {
  @override
  String build() {
    // Watch, not read: picking a different provider must re-resolve the model.
    ref.watch(aiConfigProvider);
    _hydrate();
    return '';
  }

  Future<void> _hydrate() async => state = await _resolve();

  Future<String> _resolve() async {
    final prefs = await AppPrefs.open();
    return prefs.textModel(prefs.selectedProvider) ?? '';
  }

  Future<void> refresh() async => state = await _resolve();
}

/// The active AI provider — the configured + consented one, else the offline
/// [FakeAiProvider]. See `docs/ai-providers.md`.
final aiProvider = Provider<AiProvider>((ref) {
  final secrets = ref.watch(secretStoreProvider);
  final chosen = ref.watch(textModelProvider);
  return switch (ref.watch(aiConfigProvider)) {
    ProviderId.claude => ClaudeProvider(
      secrets: secrets,
      model: chosen.isEmpty ? ClaudeProvider.defaultModel : chosen,
    ),
    ProviderId.openai => OpenAiProvider(
      secrets: secrets,
      model: chosen.isEmpty ? OpenAiProvider.defaultModel : chosen,
    ),
    ProviderId.gemini => GeminiProvider(
      secrets: secrets,
      model: chosen.isEmpty ? GeminiProvider.defaultModel : chosen,
    ),
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

/// Parent mode: when true, grown-up controls (delete/rename) are shown. Default
/// false ("child mode"). Toggled in Settings (behind the parental gate).
final parentModeProvider = NotifierProvider<ParentModeController, bool>(
  ParentModeController.new,
);

class ParentModeController extends Notifier<bool> {
  @override
  bool build() {
    _hydrate();
    return false;
  }

  Future<void> _hydrate() async => state = (await AppPrefs.open()).parentMode;

  Future<void> set(bool value) async {
    state = value;
    await (await AppPrefs.open()).setParentMode(value);
  }
}

/// Listening mode: the reader hides its text and darkens the screen so a story
/// can be heard with eyes closed. Remembered between sessions.
final listeningModeProvider = NotifierProvider<ListeningModeController, bool>(
  ListeningModeController.new,
);

class ListeningModeController extends Notifier<bool> {
  @override
  bool build() {
    _hydrate();
    return false;
  }

  Future<void> _hydrate() async =>
      state = (await AppPrefs.open()).listeningMode;

  Future<void> toggle() async {
    state = !state;
    await (await AppPrefs.open()).setListeningMode(state);
  }
}

/// The vendors whose catalogues can be listed. One per API key, not one per
/// role — OpenAI's and Google's lists cover both story and voice models.
enum ModelVendor { anthropic, openai, google, elevenlabs }

/// Looks up what a vendor's key can actually reach, so the settings screens
/// offer real model ids instead of a hard-coded guess. See `model_catalog.dart`.
final modelDirectoryProvider = Provider.family<ModelDirectory, ModelVendor>((
  ref,
  vendor,
) {
  final secrets = ref.watch(secretStoreProvider);
  return switch (vendor) {
    ModelVendor.anthropic => AnthropicModelDirectory(secrets: secrets),
    ModelVendor.openai => OpenAiModelDirectory(secrets: secrets),
    ModelVendor.google => GoogleModelDirectory(secrets: secrets),
    ModelVendor.elevenlabs => ElevenLabsModelDirectory(secrets: secrets),
  };
});

/// Which vendor serves a story provider.
ModelVendor vendorForProvider(ProviderId id) => switch (id) {
  ProviderId.openai => ModelVendor.openai,
  ProviderId.gemini => ModelVendor.google,
  _ => ModelVendor.anthropic,
};

/// Which vendor serves a voice engine (null for the offline device voice).
ModelVendor? vendorForVoice(VoiceEngine engine) => switch (engine) {
  VoiceEngine.openai => ModelVendor.openai,
  VoiceEngine.gemini => ModelVendor.google,
  VoiceEngine.elevenlabs => ModelVendor.elevenlabs,
  VoiceEngine.device => null,
};

// ─── Voice engine ─────────────────────────────────────────────────────

enum VoiceEngine { device, openai, elevenlabs, gemini }

VoiceEngine voiceEngineFromName(String name) => switch (name) {
  'openai' => VoiceEngine.openai,
  'elevenlabs' => VoiceEngine.elevenlabs,
  'gemini' => VoiceEngine.gemini,
  _ => VoiceEngine.device,
};

/// The SecretStore key name a cloud voice engine uses (null for device).
String? ttsKeyNameFor(VoiceEngine engine) => switch (engine) {
  VoiceEngine.openai => OpenAiTtsSynthesizer.keyName,
  VoiceEngine.elevenlabs => ElevenLabsTtsSynthesizer.keyName,
  VoiceEngine.gemini => GeminiTtsSynthesizer.keyName,
  VoiceEngine.device => null,
};

class VoiceConfig {
  const VoiceConfig(this.engine, this.voiceName, [this.model = '']);
  final VoiceEngine engine;
  final String voiceName; // '' = engine default
  final String model; // '' = the adapter's own default
}

/// Resolves the active voice engine. Falls back to device TTS unless the chosen
/// cloud engine has a key AND third-party-AI consent is given. Settings calls
/// [VoiceConfigController.refresh] after changes.
final voiceConfigProvider =
    NotifierProvider<VoiceConfigController, VoiceConfig>(
      VoiceConfigController.new,
    );

class VoiceConfigController extends Notifier<VoiceConfig> {
  @override
  VoiceConfig build() {
    _hydrate();
    return const VoiceConfig(VoiceEngine.device, '');
  }

  Future<void> _hydrate() async => state = await _resolve();

  Future<VoiceConfig> _resolve() async {
    final prefs = await AppPrefs.open();
    final engine = voiceEngineFromName(prefs.voiceEngine);
    if (engine == VoiceEngine.device) {
      return const VoiceConfig(VoiceEngine.device, '');
    }
    if (!prefs.aiConsentGiven) return const VoiceConfig(VoiceEngine.device, '');
    final hasKey = await ref
        .read(secretStoreProvider)
        .hasKey(ttsKeyNameFor(engine)!);
    if (!hasKey) return const VoiceConfig(VoiceEngine.device, '');
    return VoiceConfig(
      engine,
      prefs.voiceName(engine.name) ?? '',
      prefs.voiceModel(engine.name) ?? '',
    );
  }

  Future<void> refresh() async => state = await _resolve();
}

/// On-disk cache of synthesized narration, so replays/re-opens are instant and
/// gap-free and don't re-hit the cloud. Shared across voice-provider rebuilds.
final audioCacheProvider = Provider<AudioCache>((ref) => FileAudioCache());

/// The active voice reader — device TTS or a cloud engine. Disposed on rebuild.
final ttsProvider = Provider<TtsProvider>((ref) {
  final cfg = ref.watch(voiceConfigProvider);
  final secrets = ref.watch(secretStoreProvider);
  final cache = ref.watch(audioCacheProvider);
  final provider = switch (cfg.engine) {
    VoiceEngine.openai => CloudTtsProvider(
      OpenAiTtsSynthesizer(
        secrets: secrets,
        voiceName: cfg.voiceName.isEmpty ? 'nova' : cfg.voiceName,
        model: cfg.model.isEmpty
            ? OpenAiTtsSynthesizer.defaultModel
            : cfg.model,
      ),
      TtsProviderId.openai,
      cache: cache,
    ),
    VoiceEngine.elevenlabs => CloudTtsProvider(
      ElevenLabsTtsSynthesizer(
        secrets: secrets,
        voiceName: cfg.voiceName.isEmpty
            ? '21m00Tcm4TlvDq8ikWAM'
            : cfg.voiceName,
        model: cfg.model.isEmpty
            ? ElevenLabsTtsSynthesizer.defaultModel
            : cfg.model,
      ),
      TtsProviderId.elevenlabs,
      cache: cache,
    ),
    VoiceEngine.gemini => CloudTtsProvider(
      GeminiTtsSynthesizer(
        secrets: secrets,
        voiceName: cfg.voiceName.isEmpty ? 'Kore' : cfg.voiceName,
        model: cfg.model.isEmpty
            ? GeminiTtsSynthesizer.defaultModel
            : cfg.model,
      ),
      TtsProviderId.gemini,
      cache: cache,
    ),
    VoiceEngine.device => DeviceTtsProvider(),
  };
  ref.onDispose(provider.dispose);
  return provider;
});

// ─── Storage ──────────────────────────────────────────────────────────

/// The on-device Drift database. Opened lazily; closed when disposed.
final databaseProvider = Provider<AppDatabase>((ref) {
  // path_provider lives here, on the Flutter side, so the database itself
  // stays reachable from a plain `dart run`.
  final db = AppDatabase(
    LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      return NativeDatabase.createInBackground(
        File(p.join(dir.path, AppDatabase.fileName)),
      );
    }),
  );
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

final worldServiceProvider = Provider<WorldService>(
  (ref) => WorldService(ref.watch(storageRepoProvider)),
);

final characterServiceProvider = Provider<CharacterService>(
  (ref) => CharacterService(ref.watch(storageRepoProvider)),
);

/// Export/import stories as `.sleepy` files (text + audio + metadata).
final sleepyServiceProvider = Provider<SleepyService>(
  (ref) => SleepyService(
    ref.watch(storageRepoProvider),
    ref.watch(audioCacheProvider),
  ),
);

/// The child's worlds (the bookshelf). Invalidate after create/delete.
final worldsForChildProvider = FutureProvider.family<List<World>, String>(
  (ref, childId) => ref.watch(worldServiceProvider).forChild(childId),
);

/// A world's saved characters. Invalidate after create/edit/delete.
final charactersForWorldProvider =
    FutureProvider.family<List<StoryCharacter>, String>(
      (ref, worldId) => ref.watch(characterServiceProvider).forWorld(worldId),
    );

/// The currently open world (null = none / standalone).
final activeWorldProvider = NotifierProvider<ActiveWorld, World?>(
  ActiveWorld.new,
);

class ActiveWorld extends Notifier<World?> {
  @override
  World? build() => null;

  void select(World? world) => state = world;
}

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
