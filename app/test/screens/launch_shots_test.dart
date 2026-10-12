import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/quote_providers.dart';
import 'package:keller_twelve/app/run_providers.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/app/settings_providers.dart';
import 'package:keller_twelve/core/theme/app_theme.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/preferences_service.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/domain/content/quotes.dart';
import 'package:keller_twelve/domain/metrics/session_summary.dart';
import 'package:keller_twelve/features/launch/launch_gate.dart';
import 'package:keller_twelve/features/session/widgets/finish_moment.dart';

import '../support/screenshot.dart';

/// The launch quote, Today and the end of a session, rendered:
/// `build/screens/p7_*.png`.
///
///     flutter test --dart-define=SCREENSHOTS=true test/screens/launch_shots_test.dart
const _enabled = bool.fromEnvironment('SCREENSHOTS');

void main() {
  late Directory tmp;
  late AppDatabase db;
  late ProgrammeRepository repo;

  final book = QuoteBook.fromJson(
    jsonDecode(File('assets/content/quotes.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  setUp(() async {
    await Screenshot.loadRealFonts();
    tmp = Directory.systemTemp.createTempSync('kt_p7_shots_');
    db = AppDatabase.memory();
    repo = ProgrammeRepository(documentsDir: tmp);
  });

  tearDown(() async {
    await db.close();
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds the handle a moment longer.
    }
  });

  for (final id in ['q-94-5', 'g-hesiod-sweat', 'h-muslim-2664']) {
    testWidgets('launch: $id', skip: !_enabled, (tester) async {
      final quote = book.byId(id)!;
      Screenshot.phone(tester);
      await tester.pumpWidget(
        Screenshot.frame(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              preferencesProvider.overrideWith(
                () => _Prefs(const Preferences()),
              ),
              quoteOfDayProvider.overrideWith(
                (ref) async => (quote: quote, fresh: true),
              ),
              openRunProvider.overrideWith((ref) async => null),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: Screenshot.themed(AppTheme.dark),
              builder: (context, child) => LaunchGate(
                now: () => DateTime(2026, 11, 2, 6, 40),
                child: child!,
              ),
              home: const Scaffold(),
            ),
          ),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await Screenshot.capture(tester, 'p7_launch_$id');
    });
  }

  testWidgets('today, mid-programme', skip: !_enabled, (tester) async {
    final today = DateTime(2026, 10, 28);
    await tester.runAsync(
      () => Screenshot.seedHistory(db, repo: repo, today: today),
    );
    Screenshot.phone(tester, height: 2300);
    await Screenshot.pumpApp(
      tester,
      db: db,
      repo: repo,
      overrides: [
        Screenshot.pinToday(today),
        quoteOfDayProvider.overrideWith(
          (ref) async => (quote: book.byId('r-marcus-5-1')!, fresh: false),
        ),
      ],
    );
    await Screenshot.settle(tester, rounds: 30);
    await Screenshot.capture(tester, 'p7_today');
  });

  testWidgets('today, trained', skip: !_enabled, (tester) async {
    final today = DateTime(2026, 10, 28);
    await tester.runAsync(() async {
      await Screenshot.seedHistory(db, repo: repo, today: today);
      final programme = await repo.loadProgramme();
      await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              programmeId: programme.id,
              blockId: 'foundation',
              dayId: 'f-wed',
              weekNo: 3,
              plannedDate: today,
              scheduledDate: today,
              status: const Value(SessionStatus.completed),
            ),
          );
      await db.upsertBodyweight(today, 51.2);
    });
    Screenshot.phone(tester, height: 1400);
    await Screenshot.pumpApp(
      tester,
      db: db,
      repo: repo,
      overrides: [
        Screenshot.pinToday(today),
        quoteOfDayProvider.overrideWith(
          (ref) async => (quote: book.byId('q-53-39')!, fresh: false),
        ),
      ],
    );
    await Screenshot.settle(tester, rounds: 30);
    await Screenshot.capture(tester, 'p7_today_done');
  });

  testWidgets('today, before week 1', skip: !_enabled, (tester) async {
    Screenshot.phone(tester, height: 1500);
    await Screenshot.pumpApp(
      tester,
      db: db,
      repo: repo,
      overrides: [
        Screenshot.pinToday(DateTime(2026, 10, 9)),
        quoteOfDayProvider.overrideWith(
          (ref) async => (quote: book.byId('g-plato-beginning')!, fresh: false),
        ),
      ],
    );
    await Screenshot.settle(tester, rounds: 30);
    await Screenshot.capture(tester, 'p7_today_before');
  });

  testWidgets('the end of a session', skip: !_enabled, (tester) async {
    Screenshot.phone(tester);
    await tester.pumpWidget(
      Screenshot.frame(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: Screenshot.themed(AppTheme.dark),
          home: const FinishMoment(
            title: 'Full Body B',
            summary: SessionSummary(
              workingSets: 18,
              movements: 6,
              volumeKg: 4210,
              duration: Duration(minutes: 51),
            ),
            doneSets: 18,
            plannedSets: 18,
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await Screenshot.capture(tester, 'p7_finish');
  });
}

class _Prefs extends PreferencesNotifier {
  _Prefs(this.prefs);
  final Preferences prefs;
  @override
  Future<Preferences> build() async => prefs;
}
