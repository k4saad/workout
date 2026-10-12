import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/calendar/programme_calendar.dart';
import 'package:keller_twelve/domain/calendar/session_reminders.dart';

import '../support/fixtures.dart';

void main() {
  final programme = Fixtures.programme;
  final calendar = ProgrammeCalendar(programme);
  final reminders = SessionReminders(calendar);

  /// Monday of week 5 — the middle of the Build block.
  DateTime mondayOfWeek(int w) => calendar.startOfWeek(w);

  test('nothing is scheduled before the programme starts', () {
    final list = reminders.upcoming(
      from: DateTime(2026, 1, 1, 8),
      loggedDates: const {},
    );
    expect(list, isEmpty);
  });

  test('a training week produces one reminder per lift or cardio day', () {
    final from = DateTime(
      mondayOfWeek(5).year,
      mondayOfWeek(5).month,
      mondayOfWeek(5).day,
      6,
    );
    final list = reminders.upcoming(from: from, loggedDates: const {}, days: 7);

    // The Build week is three lift days and the optional Sunday.
    expect(list, isNotEmpty);
    expect(list.length, lessThanOrEqualTo(7));
    for (final r in list) {
      expect(r.at.hour, 18);
      expect(r.at.minute, 30);
      expect(r.title, isNotEmpty);
    }
  });

  test('rest days are never nagged about', () {
    final from = ProgrammeCalendar.addDays(mondayOfWeek(5), 0);
    final list = reminders.upcoming(
      from: DateTime(from.year, from.month, from.day, 6),
      loggedDates: const {},
      days: 7,
    );
    for (final offset in [1, 3, 4]) {
      // Tuesday, Thursday and Friday.
      final rest = ProgrammeCalendar.addDays(mondayOfWeek(5), offset);
      expect(
        list.any(
          (r) =>
              r.at.year == rest.year &&
              r.at.month == rest.month &&
              r.at.day == rest.day,
        ),
        isFalse,
        reason: 'weekday ${offset + 1}',
      );
    }
  });

  test('a day already logged is not reminded about', () {
    final monday = mondayOfWeek(5);
    final from = DateTime(monday.year, monday.month, monday.day, 6);

    final without = reminders.upcoming(
      from: from,
      loggedDates: const {},
      days: 7,
    );
    final with_ = reminders.upcoming(
      from: from,
      loggedDates: {monday},
      days: 7,
    );

    expect(with_.length, without.length - 1);
    expect(
      with_.any((r) => r.at.day == monday.day && r.at.month == monday.month),
      isFalse,
    );
  });

  test('the chosen time is honoured', () {
    final monday = mondayOfWeek(5);
    final list = reminders.upcoming(
      from: DateTime(monday.year, monday.month, monday.day, 6),
      loggedDates: const {},
      hour: 17,
      minute: 5,
      days: 3,
    );
    expect(list.first.at.hour, 17);
    expect(list.first.at.minute, 5);
  });

  test('a reminder for later today is kept, one for this morning is not', () {
    final monday = mondayOfWeek(5);
    final lateEvening = DateTime(monday.year, monday.month, monday.day, 21);

    final list = reminders.upcoming(
      from: lateEvening,
      loggedDates: const {},
      days: 1,
    );
    expect(
      list,
      isEmpty,
      reason: '18:30 has already passed; do not schedule it in the past',
    );
  });

  test('the body says what the session opens with', () {
    final monday = mondayOfWeek(5);
    final list = reminders.upcoming(
      from: DateTime(monday.year, monday.month, monday.day, 6),
      loggedDates: const {},
      days: 1,
    );
    expect(list.single.body, contains('minutes'));
    expect(list.single.body, contains('Opens with'));
  });

  test('nothing is scheduled past the end of the programme', () {
    final lastWeek = mondayOfWeek(programme.totalWeeks);
    final list = reminders.upcoming(
      from: ProgrammeCalendar.addDays(lastWeek, 7),
      loggedDates: const {},
      days: 14,
    );
    expect(list, isEmpty);
  });
}
