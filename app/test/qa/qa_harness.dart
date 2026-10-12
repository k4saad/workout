import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterExceptionHandler;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/run_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/app/router.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/app/settings_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/notification_service.dart';
import 'package:keller_twelve/data/preferences_service.dart';
import 'package:keller_twelve/data/programme_repository.dart';

import '../support/fake_terrain.dart';
import '../support/screenshot.dart';

/// The QA robot: the whole app, driven the way a thumb drives it, with
/// every framework error collected instead of stopping at the first.
///
/// Run with `--dart-define=QA=true`; off otherwise, because it renders with
/// real fonts and walks every screen, which the normal suite does not need.
const qaEnabled = bool.fromEnvironment('QA');

/// One problem the framework reported while the robot was on a screen.
class QaIssue {
  QaIssue(this.where, this.summary, this.source);

  final String where;
  final String summary;

  /// The `lib/…dart:line` the framework blamed, when it named one.
  final String? source;

  @override
  String toString() => '$where | $summary${source == null ? '' : ' | $source'}';
}

class QaApp {
  QaApp({required this.db, required this.repo, required this.tmp});

  final AppDatabase db;
  final ProgrammeRepository repo;
  final Directory tmp;
  late GoRouter router;

  final issues = <QaIssue>[];
  FlutterExceptionHandler? _previous;
  String _where = 'start';

  /// Starts collecting errors under [where]. Call [stopCollecting] before
  /// the test body ends: the binding checks the handler was put back.
  void collect(String where) {
    _where = where;
    _previous ??= FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.toString();
      final src = RegExp(r'lib[\\/][\w\\/]+\.dart:\d+(:\d+)?')
          .firstMatch(text)
          ?.group(0);
      issues.add(
        QaIssue(_where, details.exceptionAsString().split('\n').first, src),
      );
    };
  }

  void stopCollecting() {
    if (_previous != null) FlutterError.onError = _previous;
    _previous = null;
  }

  static Future<void> settle(WidgetTester tester, {int rounds = 10}) =>
      Screenshot.settle(tester, rounds: rounds);

  /// Pumps the app at a phone of [size] and [textScale], pinned to [today].
  Future<void> pump(
    WidgetTester tester, {
    required DateTime today,
    Size size = const Size(412, 915),
    double textScale = 1.0,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = Size(size.width * 2, size.height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await repo.ensureSeeded();
      await repo.loadLibrary();
      await repo.loadInventory();
      await repo.loadProgramme();
      await repo.loadMotions();
      await repo.loadFuel();
      await repo.loadTimetable();
    });
    router = buildRouter();
    await tester.pumpWidget(
      Screenshot.frame(
        ProviderScope(
          overrides: [
            programmeRepositoryProvider.overrideWithValue(repo),
            databaseProvider.overrideWithValue(db),
            Screenshot.pinToday(today),
            preferencesServiceProvider.overrideWithValue(
              PreferencesService(documentsDir: tmp),
            ),
            notificationServiceProvider.overrideWithValue(QuietNotifications()),
            // No network on a robot: the made-up hill, and no map tiles.
            terrainSourceProvider.overrideWithValue(FakeTerrain()),
            mapTilesEnabledProvider.overrideWithValue(false),
            ...overrides,
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: Screenshot.themed(AppTheme.dark),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  /// Every vertical list on screen, walked to its end, so rows that are only
  /// built when scrolled to are laid out too — and back to the top.
  Future<void> sweep(WidgetTester tester) async {
    // Re-found every round: a screen may rebuild its lists as they scroll.
    for (var n = 0; n < 8; n++) {
      final all = find.byType(Scrollable).evaluate().toList();
      if (n >= all.length) break;
      final e = all[n];
      if (!e.mounted) continue;
      final state = (e as StatefulElement).state as ScrollableState;
      if (state.axisDirection != AxisDirection.down) continue;
      final pos = state.position;
      if (!pos.hasContentDimensions) continue;
      var guard = 0;
      while (e.mounted && pos.pixels < pos.maxScrollExtent && guard++ < 60) {
        pos.jumpTo((pos.pixels + 400).clamp(0, pos.maxScrollExtent));
        await tester.pump();
      }
      if (e.mounted) {
        pos.jumpTo(0);
        await tester.pump();
      }
    }
    await settle(tester, rounds: 3);
  }

  /// Records a failure of the robot's own step as an issue, rather than
  /// failing the test: a failed widget test with a live database hangs its
  /// teardown for minutes.
  void harness(Object error) =>
      issues.add(QaIssue(_where, 'ROBOT: ${'$error'.split('\n').first}', null));
}

class QuietNotifications implements NotificationService {
  @override
  bool get canScheduleExact => false;
  @override
  bool get isAndroid => false;
  @override
  Future<void> init({void Function(String? payload)? onTap}) async {}
  @override
  Future<void> scheduleRestEnd(
    DateTime at, {
    required String exerciseName,
    required int setNumber,
    String? payload,
  }) async {}
  @override
  Future<void> scheduleIntervalCues(
    List<({DateTime at, String title, String body})> cues, {
    int max = 24,
  }) async {}
  @override
  Future<void> cancelSessionReminders() async {}
  @override
  Future<void> schedulePlannerReminders(
    List<({DateTime at, String title, String body})> reminders,
  ) async {}
  @override
  Future<void> cancelPlannerReminders() async {}
  @override
  Future<void> cancelRest() async {}
  @override
  Future<void> cancelIntervals() async {}
  @override
  Future<void> cancelAll() async {}
}
