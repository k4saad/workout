import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/run_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/domain/run/run.dart';
import 'package:keller_twelve/features/runs/route_hero.dart';
import 'package:keller_twelve/features/runs/run_share_card.dart';

/// A run to look at and to send: full screen, and as a card.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const origin = GeoPoint(51.9555, 7.6075);
  final t0 = DateTime(2026, 10, 4, 18, 30).millisecondsSinceEpoch;

  /// 1.2 km, bending east as it goes north.
  RunTrack track() {
    final t = RunTrack();
    for (var s = 0; s <= 400; s++) {
      t.add(
        RunFix(
          tMs: t0 + s * 1000,
          lat: origin.lat + s * 3.0 / 111195.0,
          lng: origin.lng + (s * s) * 0.00000004,
          accuracyM: 5,
        ),
        segmentStart: s == 0,
      );
    }
    return t;
  }

  final run = Run(
    id: 7,
    kind: RunKind.run,
    runOn: DateTime(2026, 10, 4),
    startedAtMs: t0,
    movingMs: 400 * 1000,
    distanceM: 1203,
    elevGainM: 12,
    status: RunStatus.finished,
  );

  // path_provider in a widget test: a temp folder, not the platform.
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kt_share_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tmp.path,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds the handle a moment longer.
    }
  });

  Widget app(Widget home) => ProviderScope(
    overrides: [mapTilesEnabledProvider.overrideWithValue(false)],
    child: MaterialApp(theme: AppTheme.dark, home: home),
  );

  group('full screen', () {
    testWidgets('the card opens it; it draws, replays, and closes', (
      tester,
    ) async {
      final tr = track();
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: RouteHero(
                track: tr,
                onExpand: () => RouteFullScreen.open(
                  context,
                  track: tr,
                  title: 'Evening run',
                  subtitle: 'Sun 4 Oct · 1.20 km',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byTooltip('Full screen'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Evening run'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.byTooltip('Draw it again'), findsOneWidget);
      expect(find.byTooltip('Replay'), findsOneWidget);

      await tester.tap(find.byTooltip('Replay'));
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.textContaining(RegExp(r'^\d+\.\d\d km$')),
        findsOneWidget,
        reason: 'the distance ticking',
      );

      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Evening run'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap on the map opens it too', (tester) async {
      final tr = track();
      var opened = 0;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: RouteHero(track: tr, onExpand: () => opened++),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.tapAt(tester.getCenter(find.byType(RouteHero)));
      expect(opened, 1);
    });
  });

  group('the share card', () {
    Future<List<File>> openSheet(WidgetTester tester) async {
      final shared = <File>[];
      tester.view.physicalSize = const Size(412 * 2, 915 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showRunShareSheet(
                    context,
                    run: run,
                    track: track(),
                    share: (png, title) async => shared.add(png),
                  ),
                  child: const Text('share'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('share'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      return shared;
    }

    testWidgets('it hides the start and finish unless told otherwise', (
      tester,
    ) async {
      await openSheet(tester);
      final card = tester.widget<RunShareCard>(find.byType(RunShareCard));
      expect(card.hidesEnds, isTrue);
      final first = card.route.first.first;
      final last = card.route.last.last;
      final t = track();
      expect(haversineM(t.segments.first.first.point, first), closeTo(200, 2));
      expect(haversineM(t.segments.last.last.point, last), closeTo(200, 2));

      await tester.tap(find.text('Hide the start and finish'));
      await tester.pump();
      final whole = tester.widget<RunShareCard>(find.byType(RunShareCard));
      expect(
        haversineM(t.segments.first.first.point, whole.route.first.first),
        lessThan(1),
      );
    });

    testWidgets('with the route off, the card is the numbers', (tester) async {
      await openSheet(tester);
      await tester.tap(find.text('Show the route'));
      await tester.pump();
      final card = tester.widget<RunShareCard>(find.byType(RunShareCard));
      expect(card.route, isEmpty);
      expect(find.text('CLIMB'), findsOneWidget);
    });

    testWidgets('Share makes a 1080 x 1350 PNG and hands it over', (
      tester,
    ) async {
      final shared = await openSheet(tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('Share image'));
        for (var i = 0; i < 50 && shared.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      expect(shared, hasLength(1));
      final bytes = await tester.runAsync(() => shared.single.readAsBytes());
      // PNG signature, then the IHDR width and height.
      expect(bytes!.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final header = ByteData.sublistView(Uint8List.fromList(bytes), 16, 24);
      expect(header.getUint32(0), 1080);
      expect(header.getUint32(4), 1350);
    });
  });
}
