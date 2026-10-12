import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/calendar/programme_calendar.dart';
import 'package:keller_twelve/domain/planner/planner.dart';

import '../support/fixtures.dart';

/// "Bruh, this is starting": what notifies him, when, and what it says.
void main() {
  final timetable = Timetable.fromJson(Fixtures.timetableJson);
  final calendar = ProgrammeCalendar(Fixtures.programme);
  final planner = DayPlanner(
    timetable: timetable,
    meals: MealTarget.fromFuelJson(Fixtures.fuelJson),
  );
  const reminders = PlannerReminders();

  DayPlan plan(DateTime date, {List<PlannerEntry> entries = const []}) =>
      planner.plan(date, session: calendar.forDate(date).day, entries: entries);

  final monday = DateTime(2026, 10, 12);
  final tuesday = DateTime(2026, 10, 13);

  List<PlannerReminder> on(
    DateTime date, {
    DateTime? from,
    bool classes = true,
    bool work = true,
    bool sessions = true,
    Set<DateTime> trained = const {},
    List<PlannerEntry> entries = const [],
  }) => reminders.build(
    [plan(date, entries: entries)],
    from: from ?? date,
    classes: classes,
    work: work,
    sessions: sessions,
    trained: trained,
    travelMinutes: timetable.travelMinutes,
  );

  String hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  test('a class, fifteen minutes before, with its room', () {
    final r = on(monday).firstWhere((r) => r.title.startsWith('Geo'));
    expect(hm(r.at), '10:00');
    expect(r.title, 'Geoinformation in Society · 10:15');
    expect(r.body, contains('Room 242'));
  });

  test('work: when to leave, thirty minutes out', () {
    final r = on(tuesday).firstWhere((r) => r.title.startsWith('Job 2'));
    expect(hm(r.at), '06:20', reason: '07:00, less 30 to get there, less 10');
    expect(r.body, contains('Leave'));
  });

  test('work straight after a class says so when the class ends', () {
    // Monday: Geoinformation ends 11:45, Job 2 starts 12:15. 11:35 would
    // ring in the middle of the lecture.
    final r = on(monday).firstWhere((r) => r.title.startsWith('Job 2'));
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

  test('the optional Sunday never nags', () {
    expect(on(DateTime(2026, 10, 18)), isEmpty);
  });

  test('a skipped class is quiet', () {
    final thu = DateTime(2026, 10, 15);
    final r = on(
      thu,
      entries: [PlannerEntry.skip(date: thu, blockId: 'sii-ex-thu')],
    );
    expect(r.map((r) => r.title), isNot(contains('SII exercise · 16:15')));
    expect(r.map((r) => r.title), contains('SII lecture · 14:15'));
  });

  test('his own entry rings when he asked, and only then', () {
    final sat = DateTime(2026, 10, 17);
    final r = on(
      sat,
      entries: [
        PlannerEntry.event(
          id: 1,
          date: sat,
          title: 'Exam prep',
          start: 14 * 60,
          end: 16 * 60,
        ),
        PlannerEntry.event(
          id: 2,
          date: sat,
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
    final none = on(monday, classes: false, work: false, sessions: false);
    expect(none, isEmpty);
    final onlyWork = on(monday, classes: false, sessions: false);
    expect(onlyWork.map((r) => r.title), ['Job 2 · 12:15']);
  });

  test('nothing in the past, and in order', () {
    final r = on(monday, from: DateTime(2026, 10, 12, 12));
    expect(r.every((r) => r.at.isAfter(DateTime(2026, 10, 12, 12))), isTrue);
    expect(r.map((r) => r.title), ['Full Body A · 18:00']);
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
      reason: 'he asked for classes, work and sessions',
    );
  });
}
