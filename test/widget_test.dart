import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleepytime/app.dart';
import 'package:sleepytime/app_providers.dart';

import 'support/in_memory_storage_repo.dart';

void main() {
  testWidgets('App boots to the profile select / welcome screen', (
    tester,
  ) async {
    // Override storage with the in-memory repo so the boot path never touches
    // Drift / native sqlite / path_provider in tests.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageRepoProvider.overrideWithValue(InMemoryStorageRepo()),
        ],
        child: const SleepytimeApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Fresh repo → empty state welcome.
    expect(find.text('Welcome to SleepytimeApp'), findsOneWidget);
    expect(find.text('Add a child'), findsOneWidget);
  });
}
