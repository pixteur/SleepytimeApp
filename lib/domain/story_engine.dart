import 'package:uuid/uuid.dart';

import '../adapters/ai/ai_provider.dart';
import '../adapters/storage/storage_repo.dart';
import 'age_policy.dart';
import 'beat_store.dart';
import 'models/beat.dart';
import 'models/child_profile.dart';
import 'models/learned_profile.dart';
import 'models/series.dart';
import 'models/story_request.dart';
import 'models/story_segment.dart';
import 'prompt_builder.dart';
import 'safety_guard.dart';

/// Orchestrates one story turn end-to-end:
/// gather context → build prompt → generate → SafetyGuard → (retry/fallback) →
/// persist a Beat → update the LearnedProfile + story bible.
///
/// Bedtime must never break: on repeated failure or unsafe output it falls back
/// to a safe pre-written beat. See `docs/architecture.md`, `docs/safety.md`.
class StoryEngine {
  StoryEngine({
    required AiProvider ai,
    required StorageRepo repo,
    BeatStore? beatStore,
    PromptBuilder promptBuilder = const PromptBuilder(),
    SafetyGuard safetyGuard = const SafetyGuard(),
    List<String> bannedThemes = BannedThemes.defaults,
    int maxRetries = 2,
    Uuid? uuid,
  }) : _ai = ai, // ignore: prefer_initializing_formals
       _repo = repo,
       _beats = beatStore ?? BeatStore(repo),
       _prompt = promptBuilder,
       _safety = safetyGuard,
       _banned = bannedThemes,
       _maxRetries = maxRetries, // ignore: prefer_initializing_formals
       _uuid = uuid ?? const Uuid();

  final AiProvider _ai;
  final StorageRepo _repo;
  final BeatStore _beats;
  final PromptBuilder _prompt;
  final SafetyGuard _safety;
  final List<String> _banned;
  final int _maxRetries;
  final Uuid _uuid;

  /// Produce, vet, and persist the next beat for [series].
  Future<Beat> takeTurn({
    required ChildProfile child,
    required Series series,
    required StoryIntent intent,
    String? chosenTwist,
  }) async {
    final ctx = await _beats.recentContext(series.id);
    final interests = await _repo.loadInterests(child.id);
    final request = StoryRequest(
      child: child,
      series: series,
      intent: intent,
      recentBeats: ctx.recentBeats,
      interests: interests,
      chosenTwist: chosenTwist,
      chapterNumber: ctx.nextSeq + 1,
    );
    final prompt = _prompt.build(request, bannedThemes: _banned);
    final band = child.ageBand;

    StorySegment? safe;
    for (var attempt = 0; attempt <= _maxRetries && safe == null; attempt++) {
      try {
        final segment = await _ai.generate(prompt);
        final verdict = _safety.review(
          segment,
          band: band,
          bannedThemes: _banned,
        );
        if (verdict.ok) safe = segment;
      } catch (_) {
        // Swallow and retry; the fallback below guarantees a result.
      }
    }
    safe ??= _fallback();

    final beat = Beat(
      id: _uuid.v4(),
      seriesId: series.id,
      childId: child.id,
      seq: ctx.nextSeq,
      intent: intent,
      chosenTwist: chosenTwist,
      text: safe.storyText,
      summary: safe.summary,
      rating: safe.rating,
      setting: safe.setting,
      characters: safe.characters,
      openThreads: safe.openThreads,
      language: child.language,
      isFinal: safe.isFinal,
    );
    await _beats.append(beat);
    await _recordLearning(child.id, intent, chosenTwist);
    await _updateStoryBible(series, safe.summary);
    return beat;
  }

  /// A safe pre-written beat so the night never breaks.
  StorySegment _fallback() => const StorySegment(
    storyText:
        'Tonight, a soft cloud drifted by and offered a quiet, cozy ride. '
        'Wrapped in starlight, everyone felt calm, safe, and sleepy as the '
        'moon hummed a gentle lullaby.',
    summary: 'A calm, cozy cloud ride under a humming moon.',
    rating: AgeRating.tiny,
    setting: 'a soft, starlit sky',
    characters: [],
    openThreads: [],
  );

  Future<void> _recordLearning(
    String childId,
    StoryIntent intent,
    String? chosenTwist,
  ) async {
    // Only twist-card / dice choices feed twist affinity (free requests don't).
    if (chosenTwist == null ||
        (intent != StoryIntent.dice && intent != StoryIntent.option)) {
      return;
    }
    final current =
        await _repo.loadLearnedProfile(childId) ??
        LearnedProfile(childId: childId);
    final affinity = Map<String, int>.from(current.twistAffinity);
    affinity[chosenTwist] = (affinity[chosenTwist] ?? 0) + 1;
    await _repo.saveLearnedProfile(current.copyWith(twistAffinity: affinity));
  }

  Future<void> _updateStoryBible(Series series, String summary) async {
    final combined = '${series.storyBible} $summary'.trim();
    // Keep the bible bounded so context stays cheap.
    final bible = combined.length > 1200
        ? combined.substring(combined.length - 1200)
        : combined;
    await _repo.saveSeries(series.copyWith(storyBible: bible));
  }
}
