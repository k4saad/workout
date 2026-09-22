import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/calendar/adherence.dart';
import 'package:keller_twelve/domain/calendar/programme_calendar.dart';

import '../support/fixtures.dart';

void main() {
  final programme = Fixtures.programme;
  final calendar = ProgrammeCalendar(programme);
  final merge = CalendarMerge(calendar);

  DateTime day(int week, int weekdayOffset) =>
      ProgrammeCalendar.addDays(calendar.startOfWeek(week), weekdayOffset);

  SessionRecord record(
    int week,
    int offset,
    String dayId,
    RecordStatus status, {
    int? movedToOffset,
    bool retro = false,
  }) => SessionRecord(
    dayId: dayId,
    weekNo: week,
    plannedDate: day(week, offset),
    scheduledDate: day(week, movedToOffset ?? offset),
    status: status,
    loggedRetroactively: retro,
  );

  group('merging planned days with what happened', () {
    test('a completed session attaches to its date', () {
      final entries = merge.entriesFor(calendar.startOfWeek(5), day(5, 6), [
        record(5, 0, 'b-mon', RecordStatus.completed),
      ]);
      expect(entries, hasLength(7));
      expect(entries.first.record?.status, RecordStatus.completed);
      expect(entries[1].record, isNull);
    });

    test('a moved session is drawn on its NEW date', () {
      // Planned Monday, actually done Wednesday.
      final entries = merge.entriesFor(calendar.startOfWeek(5), day(5, 6), [
        record(5, 0, 'b-mon', RecordStatus.completed, movedToOffset: 2),
      ]);
      expect(entries[0].record, isNull, reason: 'not on Monday any more');
      expect(entries[2].record?.status, RecordStatus.completed);
      expect(entries[2].record?.wasMoved, isTrue);
      expect(entries[2].glyph(day(6, 0)), '↷');
    });
  });

  group('glyphs carry the state, not colour', () {
    final today = day(6, 0);

    test('completed, partial, skipped and in-progress each have one', () {
      const cases = {
        RecordStatus.completed: '✓',
        RecordStatus.partial: '◐',
        RecordStatus.skipped: '✕',
        RecordStatus.inProgress: '▶',
      };
      cases.forEach((status, glyph) {
        final e = merge.entriesFor(calendar.startOfWeek(5), day(5, 0), [
          record(5, 0, 'b-mon', status),
        ]).first;
        expect(e.glyph(today), glyph, reason: status.name);
      });
    });

    test('a past required session with no record reads as missed', () {
      final e = merge
          .entriesFor(calendar.startOfWeek(5), day(5, 0), const [])
          .first;
      expect(e.missed(today), isTrue);
      expect(e.glyph(today), '✕');
    });

    test('a FUTURE session is not missed, it just has not happened', () {
      final e = merge.entriesFor(day(7, 0), day(7, 0), const []).first;
      expect(e.missed(today), isFalse);
      expect(e.glyph(today), '');
    });

    test('an optional day is never missed', () {
      // Wednesday of a Build week is the optional run.
      final e = merge.entriesFor(day(5, 2), day(5, 2), const []).first;
      expect(e.isOptional, isTrue);
      expect(
        e.missed(today),
        isFalse,
        reason: 'skipping it must not count against you',
      );
    });

    test('a rest day is not a missed session', () {
      // Saturday of a Build week.
      final e = merge.entriesFor(day(5, 5), day(5, 5), const []).first;
      expect(e.isTrainingDay, isFalse);
      expect(e.missed(today), isFalse);
    });
  });

  group('adherence', () {
    test('a perfect week is 100%', () {
      final records = [
        record(5, 0, 'b-mon', RecordStatus.completed),
        record(5, 1, 'b-tue', RecordStatus.completed),
        record(5, 3, 'b-thu', RecordStatus.completed),
        record(5, 4, 'b-fri', RecordStatus.completed),
        record(5, 6, 'b-sun', RecordStatus.completed),
      ];
      final stats = merge.adherence(5, 5, records, day(6, 0));
      expect(stats.planned, 5);
      expect(stats.completed, 5);
      expect(stats.percent, 100);
      expect(stats.missed, 0);
    });

    test('a partial session still counts as turning up', () {
      final records = [
        record(5, 0, 'b-mon', RecordStatus.partial),
        record(5, 1, 'b-tue', RecordStatus.completed),
        record(5, 3, 'b-thu', RecordStatus.completed),
        record(5, 4, 'b-fri', RecordStatus.completed),
        record(5, 6, 'b-sun', RecordStatus.completed),
      ];
      final stats = merge.adherence(5, 5, records, day(6, 0));
      expect(stats.percent, 100);
      expect(stats.partial, 1);
    });

    test('a missed session shows as missed, not hidden', () {
      final records = [
        record(5, 0, 'b-mon', RecordStatus.completed),
        record(5, 1, 'b-tue', RecordStatus.completed),
        // Thursday never happened.
        record(5, 4, 'b-fri', RecordStatus.completed),
        record(5, 6, 'b-sun', RecordStatus.completed),
      ];
      final stats = merge.adherence(5, 5, records, day(6, 0));
      expect(stats.completed, 4);
      expect(stats.missed, 1);
      expect(stats.percent, 80);
    });

    test('skipping the optional Wednesday does not dent it', () {
      final records = [
        record(5, 0, 'b-mon', RecordStatus.completed),
        record(5, 1, 'b-tue', RecordStatus.completed),
        record(5, 3, 'b-thu', RecordStatus.completed),
        record(5, 4, 'b-fri', RecordStatus.completed),
        record(5, 6, 'b-sun', RecordStatus.completed),
      ];
      final stats = merge.adherence(5, 5, records, day(6, 0));
      expect(stats.planned, 5, reason: 'the optional run is not counted');
      expect(stats.percent, 100);
    });

    test('a moved session counts in the week it was PLANNED for', () {
      final records = [
        // Planned week 5 Monday, done on the Saturday.
        record(5, 0, 'b-mon', RecordStatus.completed, movedToOffset: 5),
        record(5, 1, 'b-tue', RecordStatus.completed),
        record(5, 3, 'b-thu', RecordStatus.completed),
        record(5, 4, 'b-fri', RecordStatus.completed),
        record(5, 6, 'b-sun', RecordStatus.completed),
      ];
      final stats = merge.adherence(5, 5, records, day(6, 0));
      expect(
        stats.percent,
        100,
        reason: 'life moves sessions; that is not a failure',
      );
    });

    test('future weeks do not count as missed yet', () {
      // Nothing logged, but we are only at the start of week 5.
      final stats = merge.adherence(5, 7, const [], day(5, 0));
      expect(stats.missed, 0);
      expect(stats.planned, 15, reason: '3 weeks x 5 required sessions');
    });

    test('a retroactively logged session counts fully', () {
      final records = [
        record(5, 0, 'b-mon', RecordStatus.completed, retro: true),
      ];
      final stats = merge.adherence(5, 5, records, day(5, 1));
      expect(stats.completed, 1);
      expect(records.single.loggedRetroactively, isTrue);
    });
  });

  group('streaks', () {
    test('counts consecutive sessions turned up for', () {
      final records = [
        record(1, 0, 'f-mon', RecordStatus.completed),
        record(1, 1, 'f-tue', RecordStatus.completed),
        record(1, 2, 'f-wed', RecordStatus.completed),
      ];
      final stats = merge.adherence(1, 1, records, day(1, 3));
      expect(stats.currentStreak, 3);
    });

    test('a missed session breaks it', () {
      final records = [
        record(1, 0, 'f-mon', RecordStatus.completed),
        // Tuesday missed.
        record(1, 2, 'f-wed', RecordStatus.completed),
      ];
      final stats = merge.adherence(1, 1, records, day(1, 3));
      expect(stats.currentStreak, 1);
      expect(stats.longestStreak, 1);
    });

    test('a skipped session breaks it too — skipping is a choice', () {
      final records = [
        record(1, 0, 'f-mon', RecordStatus.completed),
        record(1, 1, 'f-tue', RecordStatus.skipped),
        record(1, 2, 'f-wed', RecordStatus.completed),
      ];
      final stats = merge.adherence(1, 1, records, day(1, 3));
      expect(stats.currentStreak, 1);
    });

    test('the longest streak survives a later break', () {
      final records = [
        record(1, 0, 'f-mon', RecordStatus.completed),
        record(1, 1, 'f-tue', RecordStatus.completed),
        record(1, 2, 'f-wed', RecordStatus.completed),
        record(1, 4, 'f-fri', RecordStatus.completed),
        // Sunday missed.
      ];
      final stats = merge.adherence(1, 1, records, day(2, 0));
      expect(stats.longestStreak, 4);
      expect(stats.currentStreak, 0);
    });
  });

  group('the whole-programme view', () {
    test('twelve weeks of required sessions is sixty', () {
      final stats = merge.adherence(1, 12, const [], calendar.lastDate);
      expect(stats.planned, 60, reason: '12 weeks x 5 required sessions');
    });

    test('an empty programme reports zero rather than dividing by zero', () {
      expect(AdherenceStats.empty.rate, 0);
      expect(AdherenceStats.empty.percent, 0);
    });
  });
}
