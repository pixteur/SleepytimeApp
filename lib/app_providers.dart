import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adapters/ai/ai_provider.dart';
import 'adapters/ai/fake_ai_provider.dart';
import 'domain/story_engine.dart';

/// The active AI provider. Phase 0 uses [FakeAiProvider] so everything runs
/// offline with no API key; later phases swap this based on settings
/// (Claude / OpenAI / Gemini / hosted). See `docs/ai-providers.md`.
final aiProvider = Provider<AiProvider>((ref) => const FakeAiProvider());

/// The story engine, wired to whatever [aiProvider] currently resolves to.
final storyEngineProvider = Provider<StoryEngine>(
  (ref) => StoryEngine(ref.watch(aiProvider)),
);
