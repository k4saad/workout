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
        RecordStatus.skipped: '⊘',
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

  // ---------------------------------------------------------------- v3 ----
  // The Phase 5 calendar bugs, each pinned by the test that would have
  // caught it.

  group('adherence is measured against what was DUE', () {
    test('two for two on Wednesday of a new block is 100 %, not 13 %', () {
      final records = [
        record(5, 0, 'b-mon', RecordStatus.completed),
        record(5, 1, 'b-tue', RecordStatus.completed),
      ];
      final stats = merge.adherence(5, 7, records, day(5, 2));
      expect(stats.planned, 15, reason: 'the whole range, still there');
      expect(stats.due, 2);
      expect(stats.percent, 100, reason: 'adherence: done over due');
      expect(stats.progressPercent, 13, reason: 'progress: done over planned');
    });

    test('with nothing due yet there is no adherence to report', () {
      final stats = merge.adherence(5, 5, const [], day(5, 0));
      expect(stats.due, 0);
      expect(stats.hasDue, isFalse);
    });

    test('training today counts today; not having trained yet does not', () {
      final done = [record(5, 0, 'b-mon', RecordStatus.completed)];
      final morning = merge.adherence(5, 5, const [], day(5, 0));
      final evening = merge.adherence(5, 5, done, day(5, 0));
      expect(morning.due, 0);
      expect(evening.due, 1);
      expect(evening.percent, 100);
    });
  });

  group('the streak survives the morning', () {
    test('today, not trained yet, does not break it', () {
      final records = [
        record(1, 0, 'f-mon', RecordStatus.completed),
        record(1, 1, 'f-tue', RecordStatus.completed),
      ];
      // Wednesday morning: Wednesday's session is later today.
      final stats = merge.adherence(1, 1, records, day(1, 2));
      expect(stats.currentStreak, 2);
    });

    test('trained today, it grows', () {
      final records = [
        record(1, 0, 'f-mon', RecordStatus.completed),
        record(1, 1, 'f-tue', RecordStatus.completed),
        record(1, 2, 'f-wed', RecordStatus.completed),
      ];
      final stats = merge.adherence(1, 1, records, day(1, 2));
      expect(stats.currentStreak, 3);
    });
  });

  group('moved sessions', () {
    test('the date a session moved AWAY from is not a missed session', () {
      final entries = merge.entriesFor(calendar.startOfWeek(5), day(5, 6), [
        record(5, 0, 'b-mon', RecordStatus.completed, movedToOffset: 2),
      ]);
      final monday = entries[0];
      expect(monday.missed(day(6, 0)), isFalse);
      expect(monday.movedAway, hasLength(1));
      expect(monday.glyph(day(6, 0)), '→');
    });

    test('two sessions on one date are both kept', () {
      // Monday's session moved onto Tuesday, and Tuesday's was done too.
      final entries = merge.entriesFor(calendar.startOfWeek(5), day(5, 6), [
        record(5, 0, 'b-mon', RecordStatus.completed, movedToOffset: 1),
        record(5, 1, 'b-tue', RecordStatus.completed),
      ]);
      final tuesday = entries[1];
      expect(tuesday.records, hasLength(2));
      expect(tuesday.record!.dayId, 'b-tue', reason: 'its own session first');
    });
  });

  group('skipped is not missed', () {
    test('a deliberate skip and a no-show carry different glyphs', () {
      final skipped = merge.entriesFor(calendar.startOfWeek(5), day(5, 0), [
        record(5, 0, 'b-mon', RecordStatus.skipped),
      ]).first;
      final missed = merge
          .entriesFor(calendar.startOfWeek(5), day(5, 0), const [])
          .first;
      final today = day(6, 0);
      expect(skipped.glyph(today), '⊘');
      expect(missed.glyph(today), '✕');
      expect(skipped.missed(today), isFalse);
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
  group('the state of a day, in one word', () {
    final today = day(6, 0);

    EntryState stateOf(List<SessionRecord> rs, int offset, {DateTime? on}) =>
        merge
            .entriesFor(day(5, offset), day(5, offset), rs)
            .single
            .state(on ?? today);

    test('its own session says what happened to it', () {
      const cases = {
        RecordStatus.completed: EntryState.done,
        RecordStatus.partial: EntryState.partial,
        RecordStatus.skipped: EntryState.skipped,
        RecordStatus.inProgress: EntryState.inProgress,
      };
      cases.forEach((status, state) {
        expect(
          stateOf([record(5, 0, 'b-mon', status)], 0),
          state,
          reason: status.name,
        );
      });
    });

    test('moved away, moved here, missed, and nothing yet', () {
      final moved = [
        record(5, 0, 'b-mon', RecordStatus.completed, movedToOffset: 2),
      ];
      expect(stateOf(moved, 0), EntryState.movedAway);
      expect(stateOf(moved, 2), EntryState.movedHere);
      expect(stateOf(const [], 1), EntryState.missed);
      expect(
        stateOf(const [], 1, on: day(5, 0)),
        EntryState.none,
        reason: 'the future has not happened',
      );
      expect(stateOf(const [], 5), EntryState.none, reason: 'a rest day');
    });

    test('the glyph follows the state', () {
      for (final s in EntryState.values) {
        expect(s.glyph, isNotNull);
      }
      expect(EntryState.done.glyph, '✓');
      expect(EntryState.missed.glyph, '✕');
      expect(EntryState.skipped.glyph, '⊘');
      expect(EntryState.movedAway.glyph, '→');
      expect(EntryState.movedHere.glyph, '↷');
      expect(EntryState.none.glyph, '');
    });
  });

  group('a tally of required sessions', () {
    List<CalendarEntry> week5(List<SessionRecord> rs) =>
        merge.entriesFor(calendar.startOfWeek(5), day(5, 6), rs);

    test('Thursday morning, nothing logged: two missed, two due', () {
      final t = SessionTally.of(week5(const []), day(5, 3));
      expect(t.required, 5, reason: 'the optional Wednesday is not required');
      expect(t.missed, 2, reason: 'Monday and Tuesday; Thursday is today');
      expect(t.due, 2);
      expect(t.done, 0);
    });

    test('a session moved later in the week still counts for its day', () {
      final t = SessionTally.of(
        week5([
          record(5, 0, 'b-mon', RecordStatus.completed, movedToOffset: 2),
          record(5, 1, 'b-tue', RecordStatus.partial),
        ]),
        day(5, 3),
      );
      expect(t.done, 2);
      expect(t.missed, 0);
      expect(t.due, 2);
    });

    test('done ahead of time is due already; skipped is not missed', () {
      final t = SessionTally.of(
        week5([
          record(5, 0, 'b-mon', RecordStatus.skipped),
          record(5, 1, 'b-tue', RecordStatus.completed),
          record(5, 3, 'b-thu', RecordStatus.completed, movedToOffset: 2),
        ]),
        day(5, 2),
      );
      expect(t.skipped, 1);
      expect(t.missed, 0);
      expect(t.done, 2, reason: 'Thursday, trained on Wednesday, counts');
      expect(t.due, 3);
      expect(t.remaining, 2);
    });
  });
}
