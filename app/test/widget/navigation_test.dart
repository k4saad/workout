import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/app/router.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/app/shell.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/programme_repository.dart';

/// Navigation, from the report that started it: "if back button is pressed it
/// exits the application, there is no main page".
///
/// Both had the same cause — every screen navigated with `context.go`, which
/// REPLACES the stack, so there was never anything behind the current screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;
  late GoRouter router;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('kt_nav_');
    db = AppDatabase.memory();
    repo = ProgrammeRepository(documentsDir: tmp);
    await repo.ensureSeeded();
    await repo.loadLibrary();
    await repo.loadInventory();
    await repo.loadProgramme();
    // A fresh router per test: it holds the per-branch navigator stacks, so a
    // shared one would carry one test's tab position into the next.
    router = buildRouter();
  });

  tearDown(() async {
    await db.close();
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows keeps the handle a moment longer.
    }
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          programmeRepositoryProvider.overrideWithValue(repo),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await settle(tester);
    await settle(tester);
  }

  /// The Android hardware back button, as the framework delivers it.
  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(NavigationDestination, label));
    await settle(tester);
  }

  testWidgets('the bottom bar is present and thumb-reachable', (tester) async {
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final d in AppShell.destinations) {
      expect(find.text(d.label), findsWidgets);
    }

    // It must sit in the bottom third — the whole point is the thumb.
    final bar = tester.getRect(find.byType(NavigationBar));
    final screen = tester.getRect(find.byType(MaterialApp));
    expect(bar.top, greaterThan(screen.height * 0.66));
  });

  testWidgets('every tab opens its own screen', (tester) async {
    await pumpApp(tester);

    for (final (label, heading) in const [
      ('Week', 'Week'),
      ('Fuel', 'Fuel'),
      ('Progress', 'Progress'),
      ('More', 'More'),
    ]) {
      await tapTab(tester, label);
      expect(
        find.widgetWithText(AppBar, heading),
        findsOneWidget,
        reason: 'the $label tab did not open',
      );
    }
  });

  int selectedTab(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  /// A sideways fling across the top of the screen in front of you.
  Future<void> swipe(WidgetTester tester, String title, double dx) async {
    await tester.flingFrom(
      tester.getCenter(find.widgetWithText(AppBar, title)),
      Offset(dx, 0),
      1500,
    );
    // The slide home starts on the next frame; then give it a second.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
  }

  testWidgets('a sideways swipe moves between the tabs, both ways', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(selectedTab(tester), 0);

    await swipe(tester, 'The Keller Twelve', -300);
    expect(selectedTab(tester), 1);
    expect(find.widgetWithText(AppBar, 'Week'), findsOneWidget);

    await swipe(tester, 'Week', -300);
    expect(selectedTab(tester), 2);
    expect(find.widgetWithText(AppBar, 'Fuel'), findsOneWidget);

    await swipe(tester, 'Fuel', 300);
    expect(selectedTab(tester), 1);
    expect(find.widgetWithText(AppBar, 'Week'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Fuel'), findsNothing);
  });

  testWidgets('a drilled-in screen keeps its sideways gestures', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapTab(tester, 'More');
    await tester.tap(find.text('Exercises'));
    await settle(tester);

    await swipe(tester, 'Exercises', 300);
    expect(selectedTab(tester), 4);
    expect(find.widgetWithText(AppBar, 'Exercises'), findsOneWidget);

    // Back at the root, the swipe is the tabs' again.
    await pressBack(tester);
    await swipe(tester, 'More', 300);
    expect(selectedTab(tester), 3);
  });

  testWidgets('back from a drilled-in screen returns, it does not quit', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapTab(tester, 'More');
    expect(find.widgetWithText(AppBar, 'More'), findsOneWidget);

    await tester.tap(find.text('Exercises'));
    await settle(tester);
    expect(find.widgetWithText(AppBar, 'Exercises'), findsOneWidget);

    await pressBack(tester);

    // This is the bug: it used to leave the app entirely.
    expect(
      find.widgetWithText(AppBar, 'More'),
      findsOneWidget,
      reason: 'back should walk up the tab stack, not close the app',
    );
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('back from a tab root returns to Today', (tester) async {
    await pumpApp(tester);
    await tapTab(tester, 'Progress');
    expect(find.widgetWithText(AppBar, 'Progress'), findsOneWidget);

    await pressBack(tester);

    expect(find.widgetWithText(AppBar, 'The Keller Twelve'), findsOneWidget);
  });

  testWidgets('back on Today asks before closing rather than just going', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.widgetWithText(AppBar, 'The Keller Twelve'), findsOneWidget);

    await pressBack(tester);

    expect(find.text('Close the app?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await settle(tester);
    expect(find.widgetWithText(AppBar, 'The Keller Twelve'), findsOneWidget);
  });

  testWidgets('a tab remembers where it was while you visit another', (
    tester,
  ) async {
    await pumpApp(tester);

    await tapTab(tester, 'More');
    await tester.tap(find.text('Exercises'));
    await settle(tester);
    expect(find.widgetWithText(AppBar, 'Exercises'), findsOneWidget);

    await tapTab(tester, 'Today');
    expect(find.widgetWithText(AppBar, 'The Keller Twelve'), findsOneWidget);

    await tapTab(tester, 'More');
    expect(
      find.widgetWithText(AppBar, 'Exercises'),
      findsOneWidget,
      reason: 'each tab keeps its own stack',
    );
  });

  testWidgets('tapping the tab you are on pops it back to its root', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapTab(tester, 'More');
    await tester.tap(find.text('Exercises'));
    await settle(tester);
    expect(find.widgetWithText(AppBar, 'Exercises'), findsOneWidget);

    await tapTab(tester, 'More');
    expect(find.widgetWithText(AppBar, 'More'), findsOneWidget);
  });

  testWidgets('the Progress hub drills into Body, and back returns to it', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapTab(tester, 'Progress');
    await tester.tap(find.text('BODY'));
    await settle(tester);
    expect(find.widgetWithText(AppBar, 'Body'), findsOneWidget);

    await pressBack(tester);
    expect(find.widgetWithText(AppBar, 'Progress'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('back in the session runner asks, then returns to the tab', (
    tester,
  ) async {
    // v2 entered the runner with context.go, which REPLACED the shell: back
    // mid-session closed the app. It is pushed now, and asks first.
    await pumpApp(tester);
    router.push('/run/1/f-mon');
    await settle(tester);
    // Let the page transition finish before looking: mid-fade, the shell
    // underneath is still on stage.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(NavigationBar), findsNothing);

    await pressBack(tester);
    expect(find.text('Leave the session?'), findsOneWidget);
    await tester.tap(find.text('Leave'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'The Keller Twelve'), findsOneWidget);
  });

  testWidgets('photos opened from Body come back to Body', (tester) async {
    await pumpApp(tester);
    await tapTab(tester, 'Progress');
    await tester.tap(find.text('BODY'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Progress photos'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(NavigationBar), findsOneWidget);

    await pressBack(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.widgetWithText(AppBar, 'Body'), findsOneWidget);
  });
}
