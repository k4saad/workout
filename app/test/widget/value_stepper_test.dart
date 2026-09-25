import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/core/ui/ui.dart';

/// A number set with the thumb: no keyboard for a weigh-in with wet hands.
void main() {
  Future<double?> open(
    WidgetTester tester, {
    double initial = 50,
    double max = 200,
  }) async {
    double? result = -1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await showStepperSheet(
                    context,
                    title: 'This morning',
                    initial: initial,
                    step: 0.1,
                    bigStep: 1,
                    min: 30,
                    max: max,
                    decimals: 1,
                    unit: 'kg',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('steps by a tenth and a whole, with no float noise', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('50.0'), findsOneWidget);
    await tester.tap(find.byTooltip('Up 0.1'));
    await tester.tap(find.byTooltip('Up 0.1'));
    await tester.pump();
    expect(find.text('50.2'), findsOneWidget);
    await tester.tap(find.byTooltip('Down 1'));
    await tester.pump();
    expect(find.text('49.2'), findsOneWidget);
  });

  testWidgets('stops at the limit', (tester) async {
    await open(tester, initial: 199.5, max: 200);
    await tester.tap(find.byTooltip('Up 1'));
    await tester.pump();
    expect(find.text('200.0'), findsOneWidget);
  });

  testWidgets('holding a button keeps stepping', (tester) async {
    await open(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byTooltip('Up 0.1')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();
    final shown = double.parse(
      tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((s) => RegExp(r'^\d+\.\d$').hasMatch(s)),
    );
    expect(shown, greaterThan(50.5));
  });

  testWidgets('Save returns the value; closing returns nothing', (
    tester,
  ) async {
    double? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async => saved = await showStepperSheet(
                context,
                title: 'Waist',
                initial: 70,
                step: 0.1,
                bigStep: 1,
                min: 30,
                max: 200,
                decimals: 1,
                unit: 'cm',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Up 1'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved, 71.0);
  });
}
