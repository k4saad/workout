import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/calendar/programme_calendar.dart';
import 'package:keller_twelve/domain/planner/planner.dart';

import '../support/fixtures.dart';

/// The day planner (docs/12-semester-plan.md, Phase L), written before it:
/// what is on a date, when to train, when to eat — against the real WS 26/27
/// timetable, the real programme and the real meal targets.
void main() {
  final timetable = Timetable.fromJson(Fixtures.timetableJson);
  final calendar = ProgrammeCalendar(Fixtures.programme);
  final planner = DayPlanner(
    timetable: timetable,
    meals: MealTarget.fromFuelJson(Fixtures.fuelJson),
  );

  // Week 1 of the programme: Monday 12 October 2026, the first day of term.
  DateTime d(int month, int day, [int year = 2026]) =>
      DateTime(year, month, day);

  DayPlan plan(DateTime date, {List<PlannerEntry> entries = const []}) =>
      planner.plan(date, session: calendar.forDate(date).day, entries: entries);

  String at(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  List<String> committed(DayPlan p) => [for (final i in p.commitments) i.id];

  PlanItem meal(DayPlan p, String id) =>
      p.meals.singleWhere((m) => m.id == 'meal:$id');

  group('the timetable', () {
    test('reads every weekly block, with its room', () {
      expect(timetable.blocks, hasLength(15));
      final gis = timetable.blocks.firstWhere((b) => b.id == 'gis-mon');
      expect(gis.title, 'Geoinformation in Society');
      expect(gis.room, 'Room 242');
      expect(at(gis.start), '10:15');
      expect(at(gis.end), '11:45');
      expect(gis.kind, PlanKind.lecture);
      expect(timetable.travelMinutes, 30);
    });

    test('knows term from the break and from after it', () {
      expect(timetable.hasLectures(d(10, 12)), isTrue);
      expect(timetable.hasLectures(d(12, 23)), isFalse);
      expect(timetable.breakOn(d(12, 23)), 'Winter break');
      expect(timetable.hasLectures(d(1, 4, 2027)), isTrue);
      expect(timetable.hasLectures(d(2, 5, 2027)), isTrue);
      expect(timetable.hasLectures(d(2, 8, 2027)), isFalse);
      expect(timetable.hasLectures(d(10, 11)), isFalse, reason: 'before term');
    });
  });

  group('what is on', () {
    test('a Monday in term: the lecture, then Job 2', () {
      expect(committed(plan(d(10, 12))), ['gis-mon', 'job2-mon']);
    });

    test('travel is drawn to campus, between campus and work, and home', () {
      final travel = plan(d(10, 12)).items
          .where((i) => i.kind == PlanKind.travel)
          .map((i) => '${at(i.start)}-${at(i.end)}')
          .toList();
      expect(travel, ['09:45-10:15', '11:45-12:15', '17:00-17:30']);
    });

    test('no lectures in the winter break; work goes on', () {
      final p = plan(d(12, 23));
      expect(committed(p), ['job1-wed']);
      expect(p.breakName, 'Winter break');
    });

    test('no lectures after the fifth of February', () {
      expect(committed(plan(d(2, 8, 2027))), ['job2-mon']);
    });

    test('Jumu\'ah is every Friday, term or not', () {
      expect(committed(plan(d(12, 25))), ['jumuah-fri']);
    });

    test('Friday\'s Job 2 only on a Friday he marked', () {
      final friday = d(10, 16);
      expect(committed(plan(friday)), isNot(contains('job2-fri')));
      final marked = plan(
        friday,
        entries: [PlannerEntry.mark(date: friday, blockId: 'job2-fri')],
      );
      expect(committed(marked).first, 'job2-fri');
      expect(at(marked.commitments.first.start), '07:00');
    });

    test('a skipped class is off the day, and still listed as skipped', () {
      final thu = d(10, 15);
      final p = plan(
        thu,
        entries: [PlannerEntry.skip(date: thu, blockId: 'sii-ex-thu')],
      );
      expect(committed(p), ['job1-thu', 'sii-thu']);
      expect(p.skipped.map((i) => i.id), ['sii-ex-thu']);
    });

    test('his own entry is on the day, with its reminder wish', () {
      final sat = d(10, 17);
      final p = plan(
        sat,
        entries: [
          PlannerEntry.event(
            id: 7,
            date: sat,
            title: 'Exam prep',
            start: 14 * 60,
            end: 16 * 60,
            remind: true,
          ),
        ],
      );
      final e = p.items.singleWhere((i) => i.kind == PlanKind.event);
      expect(e.id, 'event:7');
      expect(e.title, 'Exam prep');
      expect(e.remind, isTrue);
      expect(at(e.start), '14:00');
    });
  });

  group('when to train', () {
    test('Monday: after Job 2, the ride home and a snack', () {
      final s = plan(d(10, 12)).session!;
      expect(at(s.start), '18:00');
      expect(s.title, 'Full Body A');
      expect(s.end - s.start, calendar.forDate(d(10, 12)).day!.estMinutes);
    });

    test('Wednesday: after Spatial Justice', () {
      expect(at(plan(d(10, 14)).session!.start), '16:45');
    });

    test('Saturday morning', () {
      expect(at(plan(d(10, 17)).session!.start), '10:00');
    });

    test('a rest day has no session', () {
      expect(plan(d(10, 13)).session, isNull);
      expect(plan(d(10, 15)).session, isNull);
    });

    test('the optional Sunday is planned, and says it is optional', () {
      final s = plan(d(10, 18)).session!;
      expect(s.optional, isTrue);
      expect(at(s.start), '10:00');
    });

    test('moved by hand, it stays where he put it', () {
      final mon = d(10, 12);
      final p = plan(
        mon,
        entries: [PlannerEntry.sessionAt(date: mon, start: 19 * 60 + 30)],
      );
      expect(at(p.session!.start), '19:30');
      expect(p.session!.moved, isTrue);
    });

    test('an evening entry of his own pushes it later', () {
      final mon = d(10, 12);
      final p = plan(
        mon,
        entries: [
          PlannerEntry.event(
            id: 1,
            date: mon,
            title: 'Study group',
            start: 18 * 60,
            end: 19 * 60,
          ),
        ],
      );
      expect(at(p.session!.start), '19:30');
    });

    test('a session is never on top of anything', () {
      for (var i = 0; i < 21; i++) {
        final p = plan(ProgrammeCalendar.addDays(d(10, 12), i));
        final s = p.session;
        if (s == null) continue;
        for (final c in [...p.commitments, ...p.travel]) {
          expect(
            s.start >= c.end || s.end <= c.start,
            isTrue,
            reason: '${p.date}: ${s.title} against ${c.id}',
          );
        }
      }
    });
  });

  group('when to eat', () {
    test('Monday: lunch packed at work, the snack fuels the session', () {
      final p = plan(d(10, 12));
      expect(at(meal(p, 'breakfast').start), '07:30');
      final lunch = meal(p, 'lunch');
      expect(at(lunch.start), '13:00');
      expect(lunch.packed, isTrue, reason: 'Job 2 runs 12:15-17:00');
      final snack = meal(p, 'snack');
      expect(at(snack.start), '17:30');
      expect(snack.sessionFuel, isTrue);
      expect(at(meal(p, 'dinner').start), '19:30');
    });

    test('Tuesday: breakfast before the 07:00 shift', () {
      final p = plan(d(10, 13));
      expect(at(meal(p, 'breakfast').start), '06:10');
      expect(at(meal(p, 'lunch').start), '13:45');
      expect(meal(p, 'lunch').packed, isFalse);
      expect(at(meal(p, 'snack').start), '16:05');
    });

    test('Wednesday: the snack lands between the lecture and the session', () {
      final p = plan(d(10, 14));
      expect(meal(p, 'lunch').packed, isTrue);
      final snack = meal(p, 'snack');
      expect(at(snack.start), '16:15');
      expect(snack.sessionFuel, isTrue);
    });

    test('Friday: a quick lunch between the lecture and Jumu\'ah', () {
      final lunch = meal(plan(d(10, 16)), 'lunch');
      expect(at(lunch.start), '13:45');
      expect(lunch.end, lessThanOrEqualTo(14 * 60));
    });

    test('Saturday: breakfast is the fuel for a morning session', () {
      final p = plan(d(10, 17));
      final breakfast = meal(p, 'breakfast');
      expect(at(breakfast.start), '08:30');
      expect(breakfast.sessionFuel, isTrue);
      expect(meal(p, 'snack').sessionFuel, isFalse);
    });

    test('no meal is ever in a lecture, on the road or in a session', () {
      final days = [
        for (var i = 0; i < 21; i++) ProgrammeCalendar.addDays(d(10, 12), i),
        for (var i = 0; i < 7; i++) ProgrammeCalendar.addDays(d(12, 21), i),
      ];
      for (final date in days) {
        final p = plan(date);
        for (final m in p.meals) {
          for (final c in p.items.where(
            (i) =>
                i.kind == PlanKind.lecture ||
                i.kind == PlanKind.prayer ||
                i.kind == PlanKind.travel ||
                i.kind == PlanKind.session,
          )) {
            expect(
              m.start >= c.end || m.end <= c.start,
              isTrue,
              reason: '$date: ${m.title} ${at(m.start)} against ${c.id}',
            );
          }
          if (m.packed) {
            expect(
              p.commitments.any(
                (c) =>
                    c.kind == PlanKind.job &&
                    m.start >= c.start &&
                    m.end <= c.end,
              ),
              isTrue,
              reason: '$date: packed only means at work',
            );
          }
        }
      }
    });

    test('the meals keep their order, at least an hour and a half apart', () {
      for (var i = 0; i < 14; i++) {
        final p = plan(ProgrammeCalendar.addDays(d(10, 12), i));
        expect(p.meals.map((m) => m.id), [
          'meal:breakfast',
          'meal:lunch',
          'meal:snack',
          'meal:dinner',
        ]);
        for (var j = 1; j < p.meals.length; j++) {
          expect(
            p.meals[j].start - p.meals[j - 1].start,
            greaterThanOrEqualTo(90),
            reason: '${p.date}: ${p.meals[j].id}',
          );
        }
      }
    });

    test('meal times for Fuel, by slot', () {
      final times = plan(d(10, 13)).mealTimes;
      expect(times, {
        'breakfast': '06:10',
        'lunch': '13:45',
        'snack': '16:05',
        'dinner': '19:30',
      });
    });
  });

  group('now and next', () {
    test('mid-lecture: the lecture is now, Job 2 is next', () {
      final p = plan(d(10, 12));
      final (now, next) = p.nowAndNext(11 * 60);
      expect(now?.id, 'gis-mon');
      expect(next?.id, 'job2-mon', reason: 'travel and meals are not "next"');
    });

    test('in a gap, nothing is now and the next thing is named', () {
      final (now, next) = plan(d(10, 13)).nowAndNext(15 * 60);
      expect(now, isNull);
      expect(next?.id, 'gis-tue');
    });

    test('after the last thing, the day is done', () {
      final (now, next) = plan(d(10, 13)).nowAndNext(22 * 60);
      expect(now, isNull);
      expect(next, isNull);
    });
  });
}
