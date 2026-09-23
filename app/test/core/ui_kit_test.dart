import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/core/ui/ui.dart';

/// The house kit's edge cases: the numbers it prints and the states it
/// claims, which every screen now leans on.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.dark,
    home: MediaQuery(
      // Reduced motion: the final value is rendered immediately.
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(body: Center(child: child)),
    ),
  );

  group('AnimatedCount prints what a person expects', () {
    for (final (value, decimals, expected) in const [
      (2600.0, 0, '2,600'),
      (999.0, 0, '999'),
      (999.6, 0, '1,000'),
      (-0.4, 0, '0'),
      (-1250.0, 0, '-1,250'),
      (52.44, 1, '52.4'),
      (12345678.0, 0, '12,345,678'),
    ]) {
      testWidgets('$value -> $expected', (tester) async {
        await tester.pumpWidget(
          host(AnimatedCount(value: value, decimals: decimals)),
        );
        expect(find.text(expected), findsOneWidget);
      });
    }
  });

  testWidgets('a ring with a non-finite value draws empty and never ticks', (
    tester,
  ) async {
    await tester.pumpWidget(host(const RingProgress(value: double.nan)));
    expect(find.byIcon(Icons.check), findsNothing);
    await tester.pumpWidget(host(const RingProgress(value: 1.0)));
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('an inert Pressable offers nothing to tap', (tester) async {
    await tester.pumpWidget(host(const Pressable(child: Text('x'))));
    expect(find.byType(InkWell), findsNothing);
    await tester.pumpWidget(
      host(Pressable(onTap: () {}, child: const Text('x'))),
    );
    expect(find.byType(InkWell), findsOneWidget);
  });

  testWidgets('a tappable card still centres its content', (tester) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 300,
          child: AppCard(
            onTap: () {},
            child: const Column(children: [Text('mid')]),
          ),
        ),
      ),
    );
    final card = tester.getRect(find.byType(AppCard));
    final text = tester.getCenter(find.text('mid'));
    expect(text.dx, closeTo(card.center.dx, 0.5));
  });
}
