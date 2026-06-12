import 'package:flutter/material.dart';

import 'ui/home/home_screen.dart';

/// Root widget. Theming/color config and routing live here; only this UI layer
/// changes meaningfully when porting to touch/iOS. See `docs/ui-ux.md`.
class SleepytimeApp extends StatelessWidget {
  const SleepytimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SleepytimeApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark, // bedtime-friendly default
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
