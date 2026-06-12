import '../adapters/ai/ai_provider.dart';
import 'models/story_request.dart';
import 'models/story_segment.dart';

/// Orchestrates one story turn. In Phase 0 this is a thin pass-through to the
/// active provider; Phase 2 wraps it with PromptBuilder → SafetyGuard →
/// BeatStore (the never-break-bedtime pipeline). See `docs/architecture.md`.
class StoryEngine {
  const StoryEngine(this._ai);

  final AiProvider _ai;

  /// Produce the next story segment for [request].
  Future<StorySegment> takeTurn(StoryRequest request) {
    // TODO(phase-2): build prompt, run SafetyGuard, persist a Beat, fall back
    // gracefully on any failure so bedtime never breaks.
    return _ai.generate(request);
  }
}
