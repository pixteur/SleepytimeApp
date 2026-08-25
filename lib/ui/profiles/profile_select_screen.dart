import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../domain/models/child_profile.dart';
import '../common/hold_to_delete.dart';
import '../quiz/quiz_screen.dart';
import '../common/parent_gate.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import 'create_profile_screen.dart';

/// The launch screen: pick which child is listening tonight, or (behind the
/// parent gate) add a new one. See `docs/ui-ux.md`.
class ProfileSelectScreen extends ConsumerWidget {
  const ProfileSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Who is listening tonight? 🌙'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Grown-up settings',
            onPressed: () async {
              final passed = await showParentGate(context);
              if (!passed || !context.mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load profiles:\n$e')),
        data: (profiles) => _body(context, ref, profiles),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    List<ChildProfile> profiles,
  ) {
    if (profiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🌙', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 8),
            Text(
              'Welcome to SleepytimeApp',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text("Let's set up your first storyteller."),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _addChild(context, ref, gate: false),
              icon: const Icon(Icons.add),
              label: const Text('Add a child'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                for (final child in profiles) _ProfileCard(child: child),
                _AddCard(onTap: () => _addChild(context, ref, gate: true)),
              ],
            ),
            // The gesture is the only way to reach either of these, so parent
            // mode says so. Invisible to a child, like everything else here.
            if (ref.watch(parentModeProvider)) ...[
              const SizedBox(height: 20),
              Text(
                'Hold a name — or right-click it — to redo the quiz or remove '
                'a child.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _addChild(
    BuildContext context,
    WidgetRef ref, {
    required bool gate,
  }) async {
    if (gate) {
      final passed = await showParentGate(context);
      if (!passed || !context.mounted) return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateProfileScreen()),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.child});

  final ChildProfile child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 140,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            ref.read(activeChildProvider.notifier).select(child);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          },
          // Grown-ups only, and only by holding: a child's whole library goes
          // with them, so this must never be one tap away.
          onLongPress: () => _holdMenu(context, ref),
          // A mouse has no long press. Right-click is the same gesture on a
          // desktop, and this app is used on one far more than on a phone.
          onSecondaryTap: () => _holdMenu(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Color(child.themeColor),
                  child: Text(
                    child.displayName.characters.first.toUpperCase(),
                    style: const TextStyle(fontSize: 28, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  child.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Age ${child.age}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Run the onboarding quiz again for this child.
  ///
  /// A quiz answered at four is stale at six, and the bank draws a different
  /// question per dimension every time, so asking again genuinely learns
  /// something rather than repeating itself. The newest answers win: the story
  /// engine reads the most recent quiz result.
  Future<void> _redoQuiz(BuildContext context, WidgetRef ref) async {
    ref.read(activeChildProvider.notifier).select(child);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuizScreen(child: child)),
    );
  }

  /// The hold sheet for a child: redo the quiz, or remove them.
  Future<void> _holdMenu(BuildContext context, WidgetRef ref) async {
    final stories =
        (await ref.read(seriesServiceProvider).forChild(child.id)).length;
    if (!context.mounted) return;
    final deleted = await holdToDelete(
      context,
      enabled: ref.read(parentModeProvider),
      what: child.displayName,
      icon: '🧒',
      extras: [
        HoldAction(
          icon: Icons.quiz_outlined,
          label: 'Redo the quiz',
          subtitle: 'Ask again — the questions are drawn fresh each time',
          onTap: () => _redoQuiz(context, ref),
        ),
      ],
      warning:
          'This removes ${child.displayName} and everything of theirs: '
          '${stories == 0 ? "no stories yet" : "$stories "
                    "${stories == 1 ? "story" : "stories"}"}, their worlds, '
          'characters and saved narration.',
      onDelete: () async {
        await ref.read(profileServiceProvider).delete(child.id);
        // Whoever was selected may be the one that just went.
        if (ref.read(activeChildProvider)?.id == child.id) {
          ref.read(activeChildProvider.notifier).select(null);
        }
        ref.invalidate(profilesProvider);
      },
    );
    if (deleted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${child.displayName} was removed.')),
      );
    }
  }
}

class _AddCard extends StatelessWidget {
  const _AddCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 168,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, size: 36),
              SizedBox(height: 8),
              Text('Add a child'),
            ],
          ),
        ),
      ),
    );
  }
}
