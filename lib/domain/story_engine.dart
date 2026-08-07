import 'dart:async';

import 'package:uuid/uuid.dart';

import '../adapters/ai/ai_provider.dart';
import '../adapters/storage/storage_repo.dart';
import 'age_policy.dart';
import 'beat_store.dart';
import 'models/beat.dart';
import 'models/cast_changes.dart';
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
    int maxChapters = 6,
    Uuid? uuid,
  }) : _ai = ai, // ignore: prefer_initializing_formals
       _repo = repo,
       _beats = beatStore ?? BeatStore(repo),
       _prompt = promptBuilder,
       _safety = safetyGuard,
       _banned = bannedThemes,
       _maxRetries = maxRetries, // ignore: prefer_initializing_formals
       _maxChapters = maxChapters, // ignore: prefer_initializing_formals
       _uuid = uuid ?? const Uuid();

  final AiProvider _ai;
  final StorageRepo _repo;
  final BeatStore _beats;
  final PromptBuilder _prompt;
  final SafetyGuard _safety;
  final List<String> _banned;
  final int _maxRetries;
  final int _maxChapters;
  final Uuid _uuid;

  /// Per-series generation lock so concurrent turns (e.g. background
  /// auto-complete + a user tap) can't compute the same `seq` and duplicate a
  /// chapter. Turns for a series run one at a time.
  final Map<String, Future<void>> _locks = {};

  /// Why the last turn used the safe fallback instead of a generated chapter
  /// (API error or safety rejection), or null if the real provider succeeded.
  /// The UI surfaces this so silent "generic" chapters become diagnosable.
  String? lastFallbackReason;

  /// Produce, vet, and persist the next beat for [series]. Serialized per series.
  Future<Beat> takeTurn({
    required ChildProfile child,
    required Series series,
    required StoryIntent intent,
    String? chosenTwist,
  }) async {
    final prior = _locks[series.id];
    final gate = Completer<void>();
    _locks[series.id] = gate.future;
    try {
      if (prior != null) {
        try {
          await prior;
        } catch (_) {
          /* a failed prior turn shouldn't block the next */
        }
      }
      return await _runTurn(
        child: child,
        series: series,
        intent: intent,
        chosenTwist: chosenTwist,
      );
    } finally {
      gate.complete();
      if (identical(_locks[series.id], gate.future)) _locks.remove(series.id);
    }
  }

  Future<Beat> _runTurn({
    required ChildProfile child,
    required Series series,
    required StoryIntent intent,
    String? chosenTwist,
  }) async {
    final ctx = await _beats.recentContext(series.id);
    final interests = await _repo.loadInterests(child.id);
    // Pull in the world premise + saved cast so episodes stay in-universe.
    final worldId = series.worldId;
    final world = worldId == null ? null : await _repo.loadWorldById(worldId);
    final cast = worldId == null
        ? const <String>[]
        : (await _repo.loadCharacters(
            worldId,
          )).map((c) => c.promptLine).toList();
    // Cast edits are honoured by the first chapter of the next story, so a
    // departing character gets their send-off there rather than mid-story.
    final isFirstChapter = ctx.nextSeq == 0;
    final castChanges = isFirstChapter
        ? (world?.pendingCastChanges ?? CastChanges.none)
        : CastChanges.none;

    final request = StoryRequest(
      child: child,
      series: series,
      intent: intent,
      recentBeats: ctx.recentBeats,
      interests: interests,
      chosenTwist: chosenTwist,
      chapterNumber: ctx.nextSeq + 1,
      maxChapters: _maxChapters,
      worldPremise: world?.premise ?? '',
      cast: cast,
      castChanges: castChanges,
    );
    final prompt = _prompt.build(request, bannedThemes: _banned);
    final band = child.ageBand;

    StorySegment? safe;
    String? reason;
    for (var attempt = 0; attempt <= _maxRetries && safe == null; attempt++) {
      try {
        final segment = await _ai.generate(prompt);
        final verdict = _safety.review(
          segment,
          band: band,
          bannedThemes: _banned,
        );
        if (verdict.ok) {
          safe = segment;
        } else {
          reason = 'safety rejected (${verdict.reasons.join(", ")})';
        }
      } catch (e) {
        // Swallow and retry; the fallback below guarantees a result.
        reason = e.toString();
      }
    }
    if (safe == null) {
      lastFallbackReason = reason ?? 'unknown error';
      safe = _fallback();
    } else {
      lastFallbackReason = null;
    }

    // Enforce the cap: even if the model won't end the story, the last allowed
    // chapter is always final. Stops runaway generation (and quota burn).
    final isFinal = safe.isFinal || request.mustConclude;

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
      openThreads: isFinal ? const [] : safe.openThreads,
      language: child.language,
      isFinal: isFinal,
    );
    await _beats.append(beat);
    await _recordLearning(child.id, intent, chosenTwist);
    await _saveSeriesProgress(
      series,
      safe,
      nameIt: series.autoTitle && isFirstChapter && lastFallbackReason == null,
    );
    // The send-off has been written, so the world's cast is settled again.
    // (A fallback chapter didn't say goodbye — keep them pending for next time.)
    if (world != null && castChanges.isNotEmpty && lastFallbackReason == null) {
      await _repo.saveWorld(
        world.copyWith(pendingCastChanges: CastChanges.none),
      );
    }
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

  /// Roll the summary into the story bible and, for a story the grown-up left
  /// unnamed, adopt the title the model drew from the chapter it just wrote.
  Future<void> _saveSeriesProgress(
    Series series,
    StorySegment segment, {
    required bool nameIt,
  }) async {
    final combined = '${series.storyBible} ${segment.summary}'.trim();
    // Keep the bible bounded so context stays cheap.
    final bible = combined.length > 1200
        ? combined.substring(combined.length - 1200)
        : combined;
    final title = nameIt ? _cleanTitle(segment.suggestedTitle) : null;
    await _repo.saveSeries(
      series.copyWith(
        storyBible: bible,
        title: title,
        autoTitle: title == null ? null : false,
      ),
    );
  }

  /// Tidy the model's title suggestion: strip wrapping quotes and trailing
  /// punctuation, cap the length, and reject anything unusable (null → keep
  /// the placeholder and try again next chapter).
  static String? _cleanTitle(String raw) {
    var t = raw
        .trim()
        .replaceAll(RegExp(r'^["“”\x27]+|["“”\x27.]+$'), '')
        .trim();
    if (t.length > 60) t = t.substring(0, 60).trim();
    return t.isEmpty ? null : t;
  }
}
