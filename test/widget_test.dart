import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleepytime/app.dart';

void main() {
  testWidgets('App boots to the home screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SleepytimeApp()));

    expect(find.text('SleepytimeApp'), findsOneWidget);
    expect(find.text('Roll the dice'), findsOneWidget);
  });
}
