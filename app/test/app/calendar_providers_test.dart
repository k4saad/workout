import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/app/calendar_providers.dart';
import 'package:keller_twelve/app/providers.dart';
import 'package:keller_twelve/app/session_providers.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/programme_repository.dart';
import 'package:keller_twelve/domain/calendar/adherence.dart';

/// The calendar reads the database LIVE. v2 read it once: finish a session,
/// go back to the calendar, and the day still said nothing had happened.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a session logged elsewhere reaches the calendar without a reload',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final seen = <List<SessionRecord>>[];
      final sub = container.listen(
        allRecordsProvider,
        (_, next) => next.whenData(seen.add),
        fireImmediately: true,
      );
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              programmeId: 'keller-twelve',
              blockId: 'foundation',
              dayId: 'f-mon',
              weekNo: 1,
              plannedDate: DateTime(2026, 9, 28),
              scheduledDate: DateTime(2026, 9, 28),
              status: const Value(SessionStatus.completed),
            ),
          );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(seen.last, hasLength(1));
      expect(seen.last.single.status, RecordStatus.completed);
    },
  );
  group('a range stops at its last day', () {
    late Directory tmp;
    late ProgrammeRepository repo;
    late AppDatabase db;
    late ProviderContainer container;

    setUpAll(() async {
      tmp = Directory.systemTemp.createTempSync('kt_cal_prov_');
      repo = ProgrammeRepository(documentsDir: tmp);
      await repo.ensureSeeded();
    });

    tearDownAll(() {
      try {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows holds the handle a moment longer.
      }
    });

    setUp(() {
      db = AppDatabase.memory();
      container = ProviderContainer(
        overrides: [
          programmeRepositoryProvider.overrideWithValue(repo),
          databaseProvider.overrideWithValue(db),
          todayProvider.overrideWith(() => _Pinned(DateTime(2026, 11, 15))),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<T> read<T>(ProviderListenable<Future<T>> p) {
      final sub = container.listen(p, (_, _) {});
      addTearDown(sub.close);
      return sub.read();
    }

    test('a weigh-in on the first of next month is not this month', () async {
      await db.upsertBodyweight(DateTime(2026, 10, 2), 50.4);
      await db.upsertBodyweight(DateTime(2026, 10, 31), 51.0);
      await db.upsertBodyweight(DateTime(2026, 11, 1), 53.0);
      final s = await read(monthSummaryProvider(DateTime(2026, 10)).future);
      expect(s.weighIns, 2);
      expect(s.weightChangeKg, closeTo(0.6, 1e-9));
    });

    test("a day's sheet does not show tomorrow's weigh-in", () async {
      await db.upsertBodyweight(DateTime(2026, 10, 6), 50.8);
      final d = await read(dayDetailsProvider(DateTime(2026, 10, 5)).future);
      expect(d.weighInKg, isNull);
      final next = await read(dayDetailsProvider(DateTime(2026, 10, 6)).future);
      expect(next.weighInKg, 50.8);
    });

    test('a marker does not spill onto the day after the range', () async {
      await db.upsertBodyweight(DateTime(2026, 10, 6), 50.8);
      final m = await read(
        dayMarkersProvider((
          from: DateTime(2026, 10, 1),
          to: DateTime(2026, 10, 5),
        )).future,
      );
      expect(m, isEmpty);
    });
  });
}

class _Pinned extends TodayNotifier {
  _Pinned(this.day);
  final DateTime day;
  @override
  DateTime build() => day;
}
