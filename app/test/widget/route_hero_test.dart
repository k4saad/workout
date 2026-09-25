import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/run_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/domain/run/run.dart';
import 'package:keller_twelve/features/runs/route_hero.dart';

/// The top of a finished run: the route drawing in, pace colours, replay.
void main() {
  const origin = GeoPoint(51.9555, 7.6075);
  final t0 = DateTime(2026, 10, 4, 18, 30).millisecondsSinceEpoch;

  RunTrack track() {
    final t = RunTrack();
    var d = 0.0;
    for (var s = 0; s <= 400; s++) {
      d += s < 200 ? 3.2 : 2.7;
      t.add(
        RunFix(
          tMs: t0 + s * 1000,
          lat: origin.lat + d / 111195.0,
          lng: origin.lng + (s % 40) * 0.00002,
          accuracyM: 5,
        ),
        segmentStart: s == 0,
      );
    }
    return t;
  }

  Future<void> draw(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mapTilesEnabledProvider.overrideWithValue(false)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: RouteHero(track: track())),
        ),
      ),
    );
  }

  testWidgets('the route draws itself in, then offers pace and replay', (
    tester,
  ) async {
    await draw(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byTooltip('Replay'), findsNothing, reason: 'still drawing');
    await tester.pump(const Duration(seconds: 2));
    expect(find.byTooltip('Replay'), findsOneWidget);
    expect(find.byTooltip('Colour the route by pace'), findsOneWidget);
  });

  testWidgets('pace colours come with a key', (tester) async {
    await draw(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byTooltip('Colour the route by pace'));
    await tester.pump();
    expect(find.text('slower'), findsOneWidget);
    expect(find.text('quicker'), findsOneWidget);
  });

  testWidgets('the replay ticks the distance and time, then stops', (
    tester,
  ) async {
    await draw(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byTooltip('Replay'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining(' km'), findsOneWidget);
    expect(find.byTooltip('Stop the replay'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(find.byTooltip('Replay'), findsOneWidget, reason: 'it ended');
    expect(tester.takeException(), isNull);
  });
}
