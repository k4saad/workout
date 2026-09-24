import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/calendar/adherence.dart';
import 'package:keller_twelve/domain/calendar/day_markers.dart';
import 'package:keller_twelve/domain/calendar/programme_calendar.dart';

import '../support/fixtures.dart';

/// Everything else a calendar day says, beyond its session, and the month in
/// one line.
void main() {
  group('meals hit', () {
    test('a day is fed at 85 % of its meals, halves counting as halves', () {
      expect(mealsHit(eatenPortions: 6, plannedMeals: 7), isTrue);
      expect(mealsHit(eatenPortions: 5.5, plannedMeals: 7), isFalse);
      expect(mealsHit(eatenPortions: 5.95, plannedMeals: 7), isTrue);
    });

    test('no plan, nothing to hit', () {
      expect(mealsHit(eatenPortions: 3, plannedMeals: 0), isFalse);
    });
  });

  group('markers', () {
    final d1 = DateTime(2026, 10, 4);
    final d2 = DateTime(2026, 10, 5);

    test('each kind lands on its own date, times of day ignored', () {
      final m = markersFor(
        runDays: [DateTime(2026, 10, 4, 18, 30)],
        weighDays: [d1, d2],
        shootDays: [d2],
        fedDays: [d1],
      );
      expect(m[d1]!.ran, isTrue);
      expect(m[d1]!.weighed, isTrue);
      expect(m[d1]!.fed, isTrue);
      expect(m[d1]!.shoot, isFalse);
      expect(m[d2]!.shoot, isTrue);
      expect(m[d2]!.ran, isFalse);
    });

    test('a small cell shows the most telling first', () {
      const all = DayMarkers(ran: true, weighed: true, fed: true, shoot: true);
      expect(all.ordered, [
        DayMarker.shoot,
        DayMarker.run,
        DayMarker.weighIn,
        DayMarker.fed,
      ]);
      expect(const DayMarkers().isEmpty, isTrue);
    });
  });

  group('the month summary', () {
    final calendar = ProgrammeCalendar(Fixtures.programme);
    final merge = CalendarMerge(calendar);
    final month = DateTime(
      calendar.startOfWeek(5).year,
      calendar.startOfWeek(5).month,
    );

    List<CalendarEntry> entries(List<SessionRecord> records) {
      final first = DateTime(month.year, month.month);
      final last = DateTime(month.year, month.month + 1, 0);
      return merge.entriesFor(first, last, records);
    }

    SessionRecord done(DateTime date, String dayId, RecordStatus s) =>
        SessionRecord(
          dayId: dayId,
          weekNo: calendar.weekNumberFor(date),
          plannedDate: date,
          scheduledDate: date,
          status: s,
        );

    test('counts sessions against what was due in the month', () {
      final es = entries(const []);
      final required = [
        for (final e in es)
          if (e.isTrainingDay && !e.isOptional) e,
      ];
      // Everything up to the fourth required day done, one of them skipped.
      final recs = [
        done(
          required[0].date,
          required[0].planned.day!.id,
          RecordStatus.completed,
        ),
        done(
          required[1].date,
          required[1].planned.day!.id,
          RecordStatus.partial,
        ),
        done(
          required[2].date,
          required[2].planned.day!.id,
          RecordStatus.skipped,
        ),
      ];
      final today = ProgrammeCalendar.addDays(required[3].date, 1);
      final s = MonthSummary.of(
        entries: entries(recs),
        month: month,
        today: today,
      );
      expect(s.sessionsDone, 2);
      expect(s.skipped, 1);
      expect(s.missed, 1, reason: 'the fourth, past and never logged');
      expect(s.sessionsDue, 4);
    });

    test('adds up the runs, the weigh-ins and the rest', () {
      final s = MonthSummary.of(
        entries: entries(const []),
        month: month,
        today: DateTime(month.year, month.month, 1),
        runKm: const [3.2, 4.1],
        weighIns: [
          (DateTime(month.year, month.month, 2), 50.4),
          (DateTime(month.year, month.month, 20), 51.0),
        ],
        shoots: 1,
        fedDays: 18,
      );
      expect(s.runs, 2);
      expect(s.km, closeTo(7.3, 1e-9));
      expect(s.weighIns, 2);
      expect(s.weightChangeKg, closeTo(0.6, 1e-9));
      expect(s.shoots, 1);
      expect(s.fedDays, 18);
    });

    test('one weigh-in is not a change', () {
      final s = MonthSummary.of(
        entries: entries(const []),
        month: month,
        today: DateTime(month.year, month.month, 1),
        weighIns: [(DateTime(month.year, month.month, 2), 50.4)],
      );
      expect(s.weightChangeKg, isNull);
    });
  });
}
