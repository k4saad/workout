import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/body_service.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';

void main() {
  late AppDatabase db;
  late BodyService body;

  setUp(() {
    db = AppDatabase.memory();
    body = BodyService(db);
  });
  tearDown(() => db.close());

  final today = DateTime(2026, 11, 2);
  DateTime ago(int days) => DateTime(2026, 11, 2 - days);

  group('weight history', () {
    test('comes back oldest first, ready for the trend', () async {
      await db.upsertBodyweight(ago(2), 50.4);
      await db.upsertBodyweight(today, 50.9);
      await db.upsertBodyweight(ago(1), 50.6);

      final history = await body.weightHistory();
      expect(history.map((e) => e.kg).toList(), [50.4, 50.6, 50.9]);
    });
  });

  group('waist change', () {
    test('is null until there are two measurements', () async {
      expect(await body.waistChangeCm(), isNull);
      await db.upsertMeasurement(ago(60), MeasurementSite.waist, 68.0);
      expect(await body.waistChangeCm(), isNull);
    });

    test('is first to latest, not latest minus previous', () async {
      await db.upsertMeasurement(ago(60), MeasurementSite.waist, 68.0);
      await db.upsertMeasurement(ago(30), MeasurementSite.waist, 69.5);
      await db.upsertMeasurement(today, MeasurementSite.waist, 70.5);
      expect(await body.waistChangeCm(), closeTo(2.5, 0.001));
    });

    test('ignores other sites', () async {
      await db.upsertMeasurement(ago(60), MeasurementSite.waist, 68.0);
      await db.upsertMeasurement(today, MeasurementSite.waist, 69.0);
      await db.upsertMeasurement(ago(60), MeasurementSite.chest, 90.0);
      await db.upsertMeasurement(today, MeasurementSite.chest, 96.0);
      expect(await body.waistChangeCm(), closeTo(1.0, 0.001));
    });
  });

  group('the food tick', () {
    test('one entry per day, re-ticking replaces', () async {
      await body.logFood(today, hitTarget: false);
      await body.logFood(today, hitTarget: true);
      final row = await body.foodFor(today);
      expect(row, isNotNull);
      expect(row!.hitTarget, isTrue);
      expect(await db.select(db.foodLogs).get(), hasLength(1));
    });

    test('a day with no tick reads as null, not as a miss', () async {
      expect(await body.foodFor(today), isNull);
    });
  });

  group('the streak', () {
    test('counts consecutive days hit', () async {
      for (var i = 0; i < 5; i++) {
        await body.logFood(ago(i), hitTarget: true);
      }
      expect(await body.foodStreak(today), 5);
    });

    test('a missed day breaks it', () async {
      await body.logFood(today, hitTarget: true);
      await body.logFood(ago(1), hitTarget: true);
      await body.logFood(ago(2), hitTarget: false);
      await body.logFood(ago(3), hitTarget: true);
      expect(await body.foodStreak(today), 2);
    });

    test('an unticked day breaks it too — silence is not a hit', () async {
      await body.logFood(today, hitTarget: true);
      // Yesterday never logged.
      await body.logFood(ago(2), hitTarget: true);
      expect(await body.foodStreak(today), 1);
    });

    test('today not yet ticked means no streak at all', () async {
      await body.logFood(ago(1), hitTarget: true);
      await body.logFood(ago(2), hitTarget: true);
      expect(
        await body.foodStreak(today),
        0,
        reason: 'the streak must never claim a day that has not finished',
      );
    });

    test('no entries at all is zero, not an error', () async {
      expect(await body.foodStreak(today), 0);
    });
  });

  group('cardio logging', () {
    test('records a run with duration, distance and effort', () async {
      await body.logCardio(
        kind: CardioKind.run,
        on: today,
        durationSec: 26 * 60,
        distanceM: 4200,
        effort: 4,
      );
      final logs = await body.recentCardio();
      expect(logs, hasLength(1));
      expect(logs.single.kind, CardioKind.run);
      expect(logs.single.durationSec, 1560);
      expect(logs.single.distanceM, 4200);
      expect(logs.single.effort, 4);
    });

    test('records skipping and bag rounds separately', () async {
      await body.logCardio(
        kind: CardioKind.skip,
        on: today,
        durationSec: 450,
        rounds: 8,
      );
      await body.logCardio(
        kind: CardioKind.bag,
        on: today,
        durationSec: 480,
        rounds: 3,
      );
      final logs = await body.recentCardio();
      expect(logs.map((l) => l.kind).toSet(), {
        CardioKind.skip,
        CardioKind.bag,
      });
    });

    test('newest first', () async {
      await body.logCardio(kind: CardioKind.run, on: ago(3), durationSec: 600);
      await body.logCardio(kind: CardioKind.run, on: today, durationSec: 900);
      final logs = await body.recentCardio();
      expect(logs.first.durationSec, 900);
    });

    test(
      'running minutes over a range excludes skipping and bag work',
      () async {
        await body.logCardio(
          kind: CardioKind.run,
          on: today,
          durationSec: 26 * 60,
        );
        await body.logCardio(
          kind: CardioKind.skip,
          on: today,
          durationSec: 10 * 60,
        );
        final minutes = await body.runningMinutes(ago(7), today);
        expect(
          minutes,
          26,
          reason: 'the skipping must not be counted as a run',
        );
      },
    );

    test('a range excludes what falls outside it', () async {
      await body.logCardio(
        kind: CardioKind.run,
        on: ago(30),
        durationSec: 30 * 60,
      );
      await body.logCardio(
        kind: CardioKind.run,
        on: today,
        durationSec: 20 * 60,
      );
      expect(await body.runningMinutes(ago(7), today), 20);
    });
  });
}
