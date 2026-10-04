import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/calendar/programme_calendar.dart';
import 'package:keller_twelve/domain/models/enums.dart';

import '../support/fixtures.dart';

/// Tests C-1 .. C-13 from docs/02-data-model.md algorithm C.
void main() {
  final programme = Fixtures.programme;
  final cal = ProgrammeCalendar(programme);

  // The shipped programme starts Monday 2026-10-12.
  final start = programme.startDate;

  group('C-1 — startDate on a Monday', () {
    test('the start date is a Monday and anchors week 1', () {
      expect(start.weekday, DateTime.monday);
      expect(cal.anchorMonday, start);
      expect(cal.weekNumberFor(start), 1);
    });

    test('week boundaries land where they should', () {
      expect(cal.weekNumberFor(ProgrammeCalendar.addDays(start, 6)), 1);
      expect(cal.weekNumberFor(ProgrammeCalendar.addDays(start, 7)), 2);
      expect(cal.weekNumberFor(ProgrammeCalendar.addDays(start, 76)), 11);
      expect(cal.weekNumberFor(ProgrammeCalendar.addDays(start, 77)), 12);
    });
  });

  group('C-2 — startDate mid-week', () {
    // Shift the start to the Thursday of week 1.
    final thursdayStart = programme.copyWith(
      startDate: ProgrammeCalendar.addDays(start, 3),
    );
    final c = ProgrammeCalendar(thursdayStart);

    test('week 1 is still Monday-anchored', () {
      expect(c.anchorMonday, start);
      expect(c.weekNumberFor(start), 1);
    });

    test('Mon-Wed of week 1 are in the programme but have no session', () {
      for (var i = 0; i < 3; i++) {
        final p = c.forDate(ProgrammeCalendar.addDays(start, i));
        expect(p.status, ProgrammeStatus.active, reason: 'day $i');
        expect(p.weekNo, 1, reason: 'day $i');
        expect(p.day, isNull, reason: 'day $i should have no session');
      }
    });

    test('Thursday onward resolves normally', () {
      final p = c.forDate(ProgrammeCalendar.addDays(start, 3));
      expect(p.day, isNotNull);
      expect(p.day!.weekday, Weekday.thu);
    });
  });

  group('C-3 — dates before the programme', () {
    test('return status before, with no week number', () {
      final p = cal.forDate(ProgrammeCalendar.addDays(start, -1));
      expect(p.status, ProgrammeStatus.before);
      expect(p.weekNo, isNull);
      expect(p.day, isNull);
    });

    test('a date a month earlier is still before, not a negative week', () {
      final p = cal.forDate(ProgrammeCalendar.addDays(start, -30));
      expect(p.status, ProgrammeStatus.before);
    });

    test('week numbering goes 0, -1 backwards from the anchor', () {
      expect(cal.weekNumberFor(ProgrammeCalendar.addDays(start, -1)), 0);
      expect(cal.weekNumberFor(ProgrammeCalendar.addDays(start, -7)), 0);
      expect(cal.weekNumberFor(ProgrammeCalendar.addDays(start, -8)), -1);
    });
  });

  group('C-4 — block boundaries', () {
    test('week 4 -> 5 crosses Foundation into Build', () {
      expect(cal.forDate(cal.startOfWeek(4)).block?.id, 'foundation');
      expect(cal.forDate(cal.startOfWeek(5)).block?.id, 'build');
    });

    test('week 7 -> 8 -> 9 crosses Build, Deload, Push', () {
      expect(cal.forDate(cal.startOfWeek(7)).block?.id, 'build');
      expect(cal.forDate(cal.startOfWeek(8)).block?.id, 'deload');
      expect(cal.forDate(cal.startOfWeek(9)).block?.id, 'push');
    });

    test('week 12 is the test block', () {
      expect(cal.forDate(cal.startOfWeek(12)).block?.id, 'test');
      expect(cal.forDate(cal.startOfWeek(12)).block?.blockKind, BlockKind.test);
    });
  });

  group('C-5 / C-6 / C-7 — week 8 resolves as a deload', () {
    // Tuesday: v4's squat day.
    final tuesday = cal.forDate(
      ProgrammeCalendar.addDays(cal.startOfWeek(8), 1),
    );

    test('multipliers are applied through the calendar', () {
      final squat = tuesday.day!.allPrescriptions.firstWhere(
        (p) => p.id == 'b-tue-1',
      );
      expect(squat.sets, 2); // 3 * 0.6 -> 1.8 -> ceil 2
      expect(squat.startLoadKg, closeTo(21.0 * 0.7, 1e-9));
    });

    test('supersets are unwound', () {
      expect(
        tuesday.day!.allPrescriptions.every((p) => p.groupId == null),
        isTrue,
      );
    });

    test('defaultRir 4 reaches the main lift', () {
      final squat = tuesday.day!.allPrescriptions.firstWhere(
        (p) => p.id == 'b-tue-1',
      );
      expect(squat.targetRir, 4);
    });
  });

  group('C-8 — week 12 Sunday is the time trial', () {
    test('resolves to five-k-time-trial over 5000 m', () {
      final sunday = cal.forDate(
        ProgrammeCalendar.addDays(cal.startOfWeek(12), 6),
      );
      expect(sunday.weekNo, 12);
      final p = sunday.day!.allPrescriptions.first;
      expect(p.exerciseId, 'five-k-time-trial');
      expect(p.repsMax, 5000);
      expect(p.unit, RepUnit.m);
    });
  });

  group('C-9 — past the end', () {
    test('week 13 is complete, not null', () {
      final p = cal.forDate(cal.startOfWeek(13));
      expect(p.status, ProgrammeStatus.complete);
      expect(p.day, isNull);
      expect(cal.isComplete(cal.startOfWeek(13)), isTrue);
    });

    test('the last covered date is the Sunday of week 12', () {
      expect(cal.lastDate, ProgrammeCalendar.addDays(cal.startOfWeek(12), 6));
      expect(cal.isComplete(cal.lastDate), isFalse);
      expect(
        cal.isComplete(ProgrammeCalendar.addDays(cal.lastDate, 1)),
        isTrue,
      );
    });

    test('the programme says what to do next', () {
      expect(programme.onComplete, isNotNull);
      expect(programme.onComplete!.action, CompletionAction.seedNextCycle);
      expect(programme.onComplete!.skipBlocks, contains('foundation'));
    });
  });

  group('C-10 — a weekday with no day defined', () {
    test('returns null without throwing', () {
      // Remove Wednesday from Foundation and check the calendar copes.
      final stripped = programme.copyWith(
        blocks: [
          for (final b in programme.blocks)
            if (b.id == 'foundation')
              b.copyWith(
                days: b.days.where((d) => d.weekday != Weekday.wed).toList(),
              )
            else
              b,
        ],
      );
      final c = ProgrammeCalendar(stripped);
      final wed = c.forDate(ProgrammeCalendar.addDays(c.startOfWeek(1), 2));
      expect(wed.status, ProgrammeStatus.active);
      expect(wed.weekNo, 1);
      expect(wed.day, isNull);
    });
  });

  group('C-12 / C-13 — set rounding at the edges', () {
    test('0.6 x 3 rounds up to 2, never down to 1', () {
      expect(SetRounding.up.apply(3, 0.6), 2);
    });

    test(
      '0.6 x 1 clamps to 1, never 0 — a deload never removes a movement',
      () {
        expect(SetRounding.up.apply(1, 0.6), 1);
        expect(SetRounding.down.apply(1, 0.6), 1);
        expect(SetRounding.nearest.apply(1, 0.1), 1);
      },
    );

    test('rounding modes differ where it matters', () {
      expect(SetRounding.up.apply(4, 0.6), 3); // 2.4
      expect(SetRounding.down.apply(4, 0.6), 2);
      expect(SetRounding.nearest.apply(4, 0.6), 2);
    });
  });

  group('week views', () {
    test('weekOf always returns seven days, Monday first', () {
      for (var w = 1; w <= 12; w++) {
        final days = cal.weekOf(w);
        expect(days, hasLength(7), reason: 'week $w');
        expect(days.first.weekday, Weekday.mon, reason: 'week $w');
        expect(days.last.weekday, Weekday.sun, reason: 'week $w');
      }
    });

    test('every week has three required sessions', () {
      // v4: Tuesday, Thursday, Saturday. Sunday's run or hike is optional
      // and must not count towards the streak.
      for (var w = 1; w <= 12; w++) {
        expect(cal.requiredSessionsInWeek(w), 3, reason: 'week $w');
      }
    });

    test('range covers every date inclusively', () {
      final r = cal.range(
        cal.startOfWeek(1),
        ProgrammeCalendar.addDays(cal.startOfWeek(1), 13),
      );
      expect(r, hasLength(14));
      expect(r.first.date, cal.startOfWeek(1));
    });
  });

  group('the next session', () {
    DateTime d(int offset) => ProgrammeCalendar.addDays(start, offset);

    test('day one is a rest day: the next session is Tuesday', () {
      expect(cal.forDate(start).hasSession, isFalse);
      final next = cal.nextSession(start)!;
      expect(next.date, d(1));
      expect(next.day!.id, 'f-tue');
    });

    test('is strictly after the date asked about', () {
      expect(cal.nextSession(d(1))!.date, d(3), reason: 'Tue -> Thu');
    });

    test('skips the optional Sunday unless asked for it', () {
      final sat = d(5);
      expect(cal.nextSession(sat)!.date, d(8), reason: 'Sat -> next Tue');
      expect(cal.nextSession(sat)!.weekNo, 2);
      expect(
        cal.nextSession(sat, includeOptional: true)!.date,
        d(6),
        reason: 'the Sunday run, when optional days count',
      );
    });

    test('before the start it is the first session of week 1', () {
      final next = cal.nextSession(d(-10))!;
      expect(next.date, d(1));
    });

    test('there is none after the last session of the programme', () {
      expect(cal.nextSession(cal.lastDate), isNull);
      expect(
        cal.nextSession(ProgrammeCalendar.addDays(cal.lastDate, -1)),
        isNull,
      );
    });
  });

  group('shifting the programme', () {
    test('moves every week forward and bumps the revision', () {
      final shifted = ProgrammeCalendar(cal.shiftedBy(2));
      expect(shifted.weekNumberFor(start), -1);
      expect(shifted.weekNumberFor(ProgrammeCalendar.addDays(start, 14)), 1);
      expect(cal.shiftedBy(2).revision, programme.revision + 1);
    });
  });
}
