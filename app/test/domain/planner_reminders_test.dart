import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/calendar/programme_calendar.dart';
import 'package:keller_twelve/domain/models/enums.dart';
import 'package:keller_twelve/domain/planner/planner.dart';

import '../support/fixtures.dart';

/// "Bruh, this is starting": what notifies him, when, and what it says.
void main() {
  final timetable = Timetable.fromJson(Fixtures.timetableJson);
  final calendar = ProgrammeCalendar(Fixtures.programme);
  final meals = MealTarget.fromFuelJson(Fixtures.fuelJson);
  final planner = DayPlanner(timetable: timetable, meals: meals);
  const reminders = PlannerReminders();

  DayPlan plan(DateTime date, {List<PlannerEntry> entries = const []}) =>
      planner.plan(date, session: calendar.forDate(date).day, entries: entries);

  // Week 1: Monday 9 November 2026.
  final monday = DateTime(2026, 11, 9);
  final tuesday = DateTime(2026, 11, 10);
  final wednesday = DateTime(2026, 11, 11);
  final saturday = DateTime(2026, 11, 14);
  final sunday = DateTime(2026, 11, 15);

  List<PlannerReminder> on(
    DateTime date, {
    DateTime? from,
    bool classes = true,
    bool work = true,
    bool sessions = true,
    bool study = true,
    Set<DateTime> trained = const {},
    List<PlannerEntry> entries = const [],
  }) => reminders.build(
    [plan(date, entries: entries)],
    from: from ?? date,
    classes: classes,
    work: work,
    sessions: sessions,
    study: study,
    trained: trained,
    travelMinutes: timetable.travelMinutes,
  );

  String hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  test('a class, fifteen minutes before, with its room', () {
    final r = on(wednesday).firstWhere((r) => r.title.startsWith('Spatial'));
    expect(hm(r.at), '14:00');
    expect(r.title, 'Spatial Justice · 14:15');
    expect(r.body, contains('Room 147'));
  });

  test('work: when to leave, thirty minutes out', () {
    final r = on(tuesday).firstWhere((r) => r.title.startsWith('Job 2'));
    expect(hm(r.at), '06:20', reason: '07:00, less 30 to get there, less 10');
    expect(r.body, contains('Leave'));
  });

  test('work straight after a class says so when the class ends', () {
    // A class until 11:45 and the shift at 12:15: 11:35 would ring in the
    // middle of the lecture.
    final t = Timetable(
      name: 'Test',
      lecturesFrom: DateTime(2026, 10, 12),
      lecturesTo: DateTime(2027, 2, 5),
      breaks: const [],
      travelMinutes: 30,
      places: const {'campus': 'Campus', 'job2': 'Job 2'},
      blocks: [
        TimetableBlock(
          id: 'class',
          days: const [Weekday.mon],
          start: 10 * 60 + 15,
          end: 11 * 60 + 45,
          kind: PlanKind.lecture,
          title: 'Geoinformation in Society',
          place: 'campus',
        ),
        TimetableBlock(
          id: 'job',
          days: const [Weekday.mon],
          start: 12 * 60 + 15,
          end: 17 * 60,
          kind: PlanKind.job,
          title: 'Job 2',
          place: 'job2',
        ),
      ],
    );
    final r = reminders
        .build(
          [DayPlanner(timetable: t, meals: meals).plan(monday)],
          from: monday,
          travelMinutes: 30,
        )
        .firstWhere((r) => r.title.startsWith('Job 2'));
    expect(hm(r.at), '11:45');
  });

  test('a session, half an hour before, with how long it takes', () {
    final r = on(monday).firstWhere((r) => r.title.startsWith('Full Body'));
    expect(hm(r.at), '17:30');
    expect(r.title, 'Full Body A · 18:00');
    expect(r.body, contains('26 min'));
  });

  test('a session already trained is not reminded about', () {
    final r = on(monday, trained: {monday});
    expect(r.any((r) => r.title.startsWith('Full Body')), isFalse);
  });

  test('the optional Sunday never nags; German still rings', () {
    final r = on(sunday);
    expect(r.map((r) => r.title), ['German · 20:00']);
  });

  test('German, fifteen minutes before, every day', () {
    for (var i = 0; i < 7; i++) {
      final date = ProgrammeCalendar.addDays(monday, i);
      final r = on(date).where((r) => r.title == 'German · 20:00');
      expect(r, hasLength(1), reason: '$date');
      expect(hm(r.single.at), '19:45');
      expect(r.single.body, contains('60 min'));
    }
  });

  test('the library rings when it is time to leave for it', () {
    final r = on(tuesday).firstWhere((r) => r.title.startsWith('Library'));
    expect(r.title, 'Library · 15:00');
    expect(hm(r.at), '14:20', reason: 'the ride starts at 14:30');
    expect(r.body, contains('Leave by 14:30'));
  });

  test('study is switched off on its own', () {
    final r = on(tuesday, study: false);
    expect(r.any((r) => r.title.startsWith('German')), isFalse);
    expect(r.any((r) => r.title.startsWith('Library')), isFalse);
    expect(r.any((r) => r.title.startsWith('Job 2')), isTrue);
    expect(r.any((r) => r.title.startsWith('Geoinformatics Forum')), isTrue);
  });

  test('a skipped class is quiet', () {
    final thu = DateTime(2026, 11, 12);
    final r = on(
      thu,
      entries: [PlannerEntry.skip(date: thu, blockId: 'sii-ex-thu')],
    );
    expect(r.map((r) => r.title), isNot(contains('SII exercise · 16:15')));
    expect(r.map((r) => r.title), contains('SII lecture · 14:15'));
  });

  test('German skipped is quiet that day', () {
    final r = on(
      saturday,
      entries: [PlannerEntry.skip(date: saturday, blockId: 'german')],
    );
    expect(r.any((r) => r.title.startsWith('German')), isFalse);
  });

  test('his own entry rings when he asked, and only then', () {
    final r = on(
      saturday,
      entries: [
        PlannerEntry.event(
          id: 1,
          date: saturday,
          title: 'Exam prep',
          start: 14 * 60,
          end: 16 * 60,
        ),
        PlannerEntry.event(
          id: 2,
          date: saturday,
          title: 'Laundry',
          start: 17 * 60,
          end: 18 * 60,
          remind: false,
        ),
      ],
    );
    expect(r.map((r) => r.title), contains('Exam prep · 14:00'));
    expect(r.map((r) => r.title), isNot(contains('Laundry · 17:00')));
  });

  test('each kind can be switched off', () {
    final none = on(
      monday,
      classes: false,
      work: false,
      sessions: false,
      study: false,
    );
    expect(none, isEmpty);
    final onlyWork = on(monday, classes: false, sessions: false, study: false);
    expect(onlyWork.map((r) => r.title), ['Job 2 · 12:15']);
  });

  test('nothing in the past, and in order', () {
    final r = on(monday, from: DateTime(2026, 11, 9, 12));
    expect(r.every((r) => r.at.isAfter(DateTime(2026, 11, 9, 12))), isTrue);
    expect(r.map((r) => r.title), ['Full Body A · 18:00', 'German · 20:00']);
    final week = reminders.build(
      [for (var i = 0; i < 7; i++) plan(ProgrammeCalendar.addDays(monday, i))],
      from: monday,
      travelMinutes: timetable.travelMinutes,
    );
    for (var i = 1; i < week.length; i++) {
      expect(week[i].at.isBefore(week[i - 1].at), isFalse);
    }
  });

  test('meals and travel never ring', () {
    final week = reminders.build(
      [for (var i = 0; i < 7; i++) plan(ProgrammeCalendar.addDays(monday, i))],
      from: monday,
      travelMinutes: timetable.travelMinutes,
    );
    expect(
      week.any(
        (r) =>
            r.title.startsWith('Breakfast') ||
            r.title.startsWith('Lunch') ||
            r.title.startsWith('To ') ||
            r.title.startsWith('Home'),
      ),
      isFalse,
    );
    expect(
      week.where((r) => r.title.startsWith('Jumu')),
      isEmpty,
      reason: 'he asked for classes, work, sessions and study',
    );
  });
}
