import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/calendar/programme_calendar.dart';
import 'package:keller_twelve/domain/models/enums.dart';
import 'package:keller_twelve/domain/planner/planner.dart';

import '../support/fixtures.dart';

/// The day planner (docs/12-semester-plan.md Phase L, docs/13-your-week-plan.md),
/// written before it: what is on a date, when to train, when to eat —
/// against the real week, the real programme and the real meal targets.
void main() {
  final timetable = Timetable.fromJson(Fixtures.timetableJson);
  final calendar = ProgrammeCalendar(Fixtures.programme);
  final meals = MealTarget.fromFuelJson(Fixtures.fuelJson);
  final planner = DayPlanner(timetable: timetable, meals: meals);

  // Week 1 of the programme: Monday 9 November 2026.
  DateTime d(int month, int day, [int year = 2026]) =>
      DateTime(year, month, day);
  final monday = d(11, 9);
  DateTime day(int offset) => ProgrammeCalendar.addDays(monday, offset);

  DayPlan plan(DateTime date, {List<PlannerEntry> entries = const []}) =>
      planner.plan(date, session: calendar.forDate(date).day, entries: entries);

  String at(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  List<String> committed(DayPlan p) => [for (final i in p.commitments) i.id];

  List<String> travel(DayPlan p) => [
    for (final i in p.travel) '${at(i.start)}-${at(i.end)}',
  ];

  PlanItem meal(DayPlan p, String id) =>
      p.meals.singleWhere((m) => m.id == 'meal:$id');

  group('the week', () {
    test('reads every weekly block, with its room', () {
      expect(timetable.blocks, hasLength(13));
      final sj = timetable.block('sj-wed')!;
      expect(sj.title, 'Spatial Justice');
      expect(sj.room, 'Room 147');
      expect(sj.days, [Weekday.wed]);
      expect(at(sj.start), '14:15');
      expect(at(sj.end), '15:45');
      expect(sj.kind, PlanKind.lecture);
      expect(timetable.travelMinutes, 30);
    });

    test('Geoinformation in Society, Friday\'s Spatial Justice and the study '
        'project are gone', () {
      for (final id in ['gis-mon', 'gis-tue', 'sj-fri', 'sp-fri']) {
        expect(timetable.block(id), isNull, reason: id);
      }
      expect(
        timetable.blocks.where((b) => b.title == 'Spatial Justice'),
        hasLength(1),
      );
    });

    test('German, an hour every day, anywhere', () {
      final german = timetable.block('german')!;
      expect(german.days, Weekday.values);
      expect(german.kind, PlanKind.study);
      expect(german.place, isNull);
      expect(german.minutes, 60);
      expect(german.offInBreaks, isFalse);
    });

    test('the library, in the evening after class, off in the break', () {
      final library = timetable.block('library')!;
      expect(library.days, [Weekday.tue, Weekday.fri]);
      expect(library.kind, PlanKind.study);
      expect(timetable.places[library.place], 'Library');
      expect(library.minutes, greaterThanOrEqualTo(3 * 60));
      expect(library.offInBreaks, isTrue);
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
    test('Monday: Job 2, then German', () {
      final p = plan(monday);
      expect(committed(p), ['job2-mon', 'german']);
      expect(travel(p), ['11:45-12:15', '17:00-17:30']);
    });

    test('Tuesday: the shift, the Forum, the library, German', () {
      final p = plan(day(1));
      expect(committed(p), ['job2-tue', 'forum-tue', 'library', 'german']);
      expect(travel(p), [
        '06:30-07:00',
        '11:45-12:15',
        '14:30-15:00',
        '18:00-18:30',
      ]);
      expect(p.travel.map((t) => t.title), [
        'To Job 2',
        'To Campus',
        'To Library',
        'Home',
      ]);
    });

    test('Spatial Justice on Wednesday only', () {
      expect(committed(plan(day(2))), ['job1-wed', 'sj-wed', 'german']);
      expect(committed(plan(day(4))), [
        'astd-fri',
        'jumuah-fri',
        'library',
        'german',
      ]);
    });

    test('German anywhere: it adds no travel', () {
      final p = plan(day(5));
      expect(committed(p), ['german']);
      expect(p.travel, isEmpty);
    });

    test('no lectures in the winter break; work and German go on', () {
      final p = plan(d(12, 23));
      expect(committed(p), ['job1-wed', 'german']);
      expect(p.breakName, 'Winter break');
    });

    test('the library is off in the break, Jumu\'ah is not', () {
      expect(committed(plan(d(12, 25))), ['jumuah-fri', 'german']);
    });

    test('after the fifth of February: no lectures, still the library', () {
      expect(committed(plan(d(2, 8, 2027))), ['job2-mon', 'german']);
      final tue = plan(d(2, 9, 2027));
      expect(committed(tue), ['job2-tue', 'library', 'german']);
      // Three hours between the shift and the library: home in between.
      expect(travel(tue), [
        '06:30-07:00',
        '11:45-12:15',
        '14:30-15:00',
        '18:00-18:30',
      ]);
      expect(tue.travel.map((t) => t.title), [
        'To Job 2',
        'Home',
        'To Library',
        'Home',
      ]);
    });

    test('Friday\'s Job 2 only on a Friday he marked', () {
      final friday = day(4);
      expect(committed(plan(friday)), isNot(contains('job2-fri')));
      final marked = plan(
        friday,
        entries: [PlannerEntry.mark(date: friday, blockId: 'job2-fri')],
      );
      expect(committed(marked).first, 'job2-fri');
      expect(at(marked.commitments.first.start), '07:00');
    });

    test('a skipped class is off the day, and still listed as skipped', () {
      final thu = day(3);
      final p = plan(
        thu,
        entries: [PlannerEntry.skip(date: thu, blockId: 'sii-ex-thu')],
      );
      expect(committed(p), ['job1-thu', 'sii-thu', 'german']);
      expect(p.skipped.map((i) => i.id), ['sii-ex-thu']);
    });

    test('German skipped one day is only skipped that day', () {
      final sat = day(5);
      final p = plan(
        sat,
        entries: [PlannerEntry.skip(date: sat, blockId: 'german')],
      );
      expect(committed(p), isEmpty);
      expect(p.skipped.map((i) => i.id), ['german']);
      expect(committed(plan(day(6))), ['german']);
    });

    test('his own entry is on the day, with its reminder wish', () {
      final sat = day(5);
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
      final s = plan(monday).session!;
      expect(at(s.start), '18:00');
      expect(s.title, 'Full Body A');
      expect(s.end - s.start, calendar.forDate(monday).day!.estMinutes);
    });

    test('Wednesday: after Spatial Justice', () {
      expect(at(plan(day(2)).session!.start), '16:45');
    });

    test('Saturday morning', () {
      expect(at(plan(day(5)).session!.start), '10:00');
    });

    test('a rest day has no session', () {
      expect(plan(day(1)).session, isNull);
      expect(plan(day(3)).session, isNull);
      expect(plan(day(4)).session, isNull);
    });

    test('the optional Sunday is planned, and says it is optional', () {
      final s = plan(day(6)).session!;
      expect(s.optional, isTrue);
      expect(at(s.start), '10:00');
    });

    test('nothing before the ninth of November', () {
      expect(plan(d(11, 2)).session, isNull);
      expect(plan(d(11, 7)).session, isNull);
    });

    test('moved by hand, it stays where he put it', () {
      final p = plan(
        monday,
        entries: [PlannerEntry.sessionAt(date: monday, start: 19 * 60 + 30)],
      );
      expect(at(p.session!.start), '19:30');
      expect(p.session!.moved, isTrue);
    });

    test('an evening entry of his own pushes it later', () {
      final p = plan(
        monday,
        entries: [
          PlannerEntry.event(
            id: 1,
            date: monday,
            title: 'Study group',
            start: 18 * 60,
            end: 19 * 60,
          ),
        ],
      );
      expect(at(p.session!.start), '19:30');
      expect(
        p.session!.end,
        lessThanOrEqualTo(20 * 60),
        reason: 'and still ends before German',
      );
    });

    test('German does not push it: the session comes first', () {
      final p = plan(monday);
      final german = p.items.singleWhere((i) => i.id == 'german');
      expect(p.session!.end, lessThanOrEqualTo(german.start));
    });

    test(
      'evening study away from home: the session waits until he is back',
      () {
        final t = Timetable(
          name: 'Test',
          lecturesFrom: d(10, 12),
          lecturesTo: d(2, 5, 2027),
          breaks: const [],
          travelMinutes: 30,
          places: const {'job2': 'Job 2', 'library': 'Library'},
          blocks: [
            TimetableBlock(
              id: 'job',
              days: const [Weekday.mon],
              start: 12 * 60 + 15,
              end: 17 * 60,
              kind: PlanKind.job,
              title: 'Job 2',
              place: 'job2',
            ),
            TimetableBlock(
              id: 'lib',
              days: const [Weekday.mon],
              start: 18 * 60,
              end: 19 * 60 + 30,
              kind: PlanKind.study,
              title: 'Library',
              place: 'library',
            ),
          ],
        );
        final p = DayPlanner(
          timetable: t,
          meals: meals,
        ).plan(monday, session: calendar.forDate(monday).day);
        // Work, straight to the library, home at 20:00, half an hour to
        // settle.
        expect(travel(p), ['11:45-12:15', '17:30-18:00', '19:30-20:00']);
        expect(at(p.session!.start), '20:30');
      },
    );

    test('a session is never on top of anything, and always at home', () {
      for (var i = 0; i < 28; i++) {
        final p = plan(day(i));
        final s = p.session;
        if (s == null) continue;
        for (final c in [...p.commitments, ...p.travel]) {
          expect(
            s.start >= c.end || s.end <= c.start,
            isTrue,
            reason: '${p.date}: ${s.title} against ${c.id}',
          );
        }
        final out = p.travel.where((t) => t.end <= s.start).lastOrNull;
        expect(
          out == null || out.title == 'Home',
          isTrue,
          reason: '${p.date}: the last ride before the session goes home',
        );
      }
    });
  });

  group('when to eat', () {
    test('Monday: lunch packed at work, the snack fuels the session', () {
      final p = plan(monday);
      expect(at(meal(p, 'breakfast').start), '07:30');
      final lunch = meal(p, 'lunch');
      expect(at(lunch.start), '13:00');
      expect(lunch.packed, isTrue, reason: 'Job 2 runs 12:15-17:00');
      final snack = meal(p, 'snack');
      expect(at(snack.start), '17:30');
      expect(snack.sessionFuel, isTrue);
      expect(at(meal(p, 'dinner').start), '19:30');
    });

    test('Tuesday: breakfast before the shift, the snack at the library', () {
      final p = plan(day(1));
      expect(at(meal(p, 'breakfast').start), '06:10');
      final lunch = meal(p, 'lunch');
      expect(at(lunch.start), '13:45');
      expect(lunch.packed, isFalse);
      expect(lunch.takeAlong, isFalse);
      final snack = meal(p, 'snack');
      expect(at(snack.start), '16:30');
      expect(snack.takeAlong, isTrue, reason: 'Library 15:00-18:00');
      expect(snack.packed, isFalse);
      expect(at(meal(p, 'dinner').start), '19:30');
    });

    test('Wednesday: the snack lands between the lecture and the session', () {
      final p = plan(day(2));
      expect(meal(p, 'lunch').packed, isTrue);
      final snack = meal(p, 'snack');
      expect(at(snack.start), '16:15');
      expect(snack.sessionFuel, isTrue);
    });

    test('Thursday: lunch at work, so dinner is not pushed past German', () {
      final p = plan(day(3));
      expect(meal(p, 'lunch').packed, isTrue);
      expect(at(meal(p, 'lunch').start), '13:00');
      expect(
        at(meal(p, 'snack').start),
        '16:05',
        reason: 'between the SII lecture and its exercise',
      );
      expect(at(meal(p, 'dinner').start), '19:30');
    });

    test('Friday: a quick lunch before Jumu\'ah, the snack at the library', () {
      final p = plan(day(4));
      final lunch = meal(p, 'lunch');
      expect(at(lunch.start), '13:45');
      expect(lunch.quick, isTrue);
      expect(lunch.end, lessThanOrEqualTo(14 * 60));
      expect(meal(p, 'snack').takeAlong, isTrue);
      expect(at(meal(p, 'dinner').start), '19:30');
    });

    test('Saturday: breakfast is the fuel for a morning session', () {
      final p = plan(day(5));
      final breakfast = meal(p, 'breakfast');
      expect(at(breakfast.start), '08:30');
      expect(breakfast.sessionFuel, isTrue);
      expect(meal(p, 'snack').sessionFuel, isFalse);
    });

    test('no meal is ever in a lecture, on the road, in a session or in '
        'German', () {
      final days = [
        for (var i = 0; i < 21; i++) day(i),
        for (var i = 0; i < 7; i++) ProgrammeCalendar.addDays(d(12, 21), i),
        for (var i = 0; i < 7; i++) ProgrammeCalendar.addDays(d(2, 8, 2027), i),
      ];
      for (final date in days) {
        final p = plan(date);
        for (final m in p.meals) {
          for (final c in p.items.where(
            (i) =>
                i.kind == PlanKind.lecture ||
                i.kind == PlanKind.prayer ||
                i.kind == PlanKind.travel ||
                i.kind == PlanKind.session ||
                (i.kind == PlanKind.study && i.place == null),
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
          if (m.takeAlong) {
            expect(
              p.commitments.any(
                (c) =>
                    c.kind == PlanKind.study &&
                    c.place != null &&
                    m.start >= c.start &&
                    m.end <= c.end,
              ),
              isTrue,
              reason: '$date: taken along only to his own study out',
            );
          }
        }
      }
    });

    test('the meals keep their order, at least an hour and a half apart', () {
      for (var i = 0; i < 14; i++) {
        final p = plan(day(i));
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

    test('dinner is never after German on a day it fits before', () {
      for (var i = 0; i < 14; i++) {
        final p = plan(day(i));
        final german = p.items.where((x) => x.id == 'german').singleOrNull;
        if (german == null) continue;
        expect(
          meal(p, 'dinner').end,
          lessThanOrEqualTo(german.start),
          reason: '${p.date}',
        );
      }
    });

    test('meal times for Fuel, by slot', () {
      final times = plan(day(1)).mealTimes;
      expect(times, {
        'breakfast': '06:10',
        'lunch': '13:45',
        'snack': '16:30',
        'dinner': '19:30',
      });
    });

    test('a day with no room for a meal still names a time for it', () {
      final t = Timetable(
        name: 'Test',
        lecturesFrom: d(10, 12),
        lecturesTo: d(2, 5, 2027),
        breaks: const [],
        travelMinutes: 30,
        places: const {'campus': 'Campus'},
        blocks: [
          TimetableBlock(
            id: 'all-day',
            days: const [Weekday.tue],
            start: 6 * 60,
            end: 23 * 60,
            kind: PlanKind.lecture,
            title: 'Exam marathon',
            place: 'campus',
          ),
        ],
      );
      final p = DayPlanner(timetable: t, meals: meals).plan(day(1));
      expect(p.meals, hasLength(4));
      for (var j = 1; j < p.meals.length; j++) {
        expect(p.meals[j].start, greaterThan(p.meals[j - 1].start));
      }
    });
  });

  group('now and next', () {
    test('mid-shift: Job 2 is now, the session is next', () {
      final (now, next) = plan(monday).nowAndNext(14 * 60);
      expect(now?.id, 'job2-mon');
      expect(next?.id, 'session', reason: 'travel and meals are not "next"');
    });

    test('in a gap, nothing is now and the next thing is named', () {
      final (now, next) = plan(day(1)).nowAndNext(14 * 60);
      expect(now, isNull);
      expect(next?.id, 'library');
    });

    test('German counts: it is what he is in at 20:30', () {
      final (now, _) = plan(day(1)).nowAndNext(20 * 60 + 30);
      expect(now?.id, 'german');
    });

    test('after the last thing, the day is done', () {
      final (now, next) = plan(day(1)).nowAndNext(22 * 60);
      expect(now, isNull);
      expect(next, isNull);
    });
  });
}
