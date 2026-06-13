import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolve the configured story + voice providers BEFORE the first frame.
  // These read from prefs + secure storage asynchronously; if we let the UI
  // start first, the opening story/narration races them and silently falls back
  // to the offline placeholder + robotic device voice. Warming a shared
  // container here guarantees Gemini (etc.) is active from the very first tap.
  final container = ProviderContainer();
  await Future.wait([
    container.read(aiConfigProvider.notifier).refresh(),
    container.read(voiceConfigProvider.notifier).refresh(),
  ]);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SleepytimeApp(),
    ),
  );
}
