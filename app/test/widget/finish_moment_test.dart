import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/domain/metrics/session_summary.dart';
import 'package:keller_twelve/features/session/widgets/finish_moment.dart';

/// The screen that ends a session.
void main() {
  const summary = SessionSummary(
    workingSets: 18,
    movements: 6,
    volumeKg: 4210,
    duration: Duration(minutes: 51),
  );

  Future<void> draw(WidgetTester tester, {int done = 18, int of = 18}) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: FinishMoment(
          title: 'Full Body B',
          summary: summary,
          doneSets: done,
          plannedSets: of,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('a full session is done, with what it added up to', (
    tester,
  ) async {
    await draw(tester);
    expect(find.text('Done'), findsWidgets);
    expect(find.text('Full Body B'), findsOneWidget);
    expect(find.text('Every set logged. Now eat, and sleep.'), findsOneWidget);
    expect(find.text('4,210'), findsOneWidget, reason: 'grouped thousands');
    expect(find.text('51'), findsOneWidget);
    expect(find.text('6 movements'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a part session says so, and still counts', (tester) async {
    await draw(tester, done: 12, of: 18);
    expect(find.text('Part done'), findsOneWidget);
    expect(find.text('◐'), findsOneWidget);
    expect(find.textContaining('12 of 18 sets'), findsOneWidget);
  });
}
