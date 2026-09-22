import '../models/enums.dart';
import 'programme_calendar.dart';

/// One scheduled nudge.
typedef Reminder = ({DateTime at, String title, String body});

/// Which evenings deserve a reminder, and what it should say.
///
/// Pure: hand it a calendar and the dates already logged, get back a list.
/// Nothing here touches the notification plugin, so the rules are testable
/// without a device.
class SessionReminders {
  const SessionReminders(this.calendar);

  final ProgrammeCalendar calendar;

  /// Reminders for the next [days] days, skipping:
  ///
  ///  * rest days — there is nothing to turn up for
  ///  * optional days — the whole point of optional is that it does not nag
  ///  * days already logged — being told to train after training is noise,
  ///    and noise is what makes people turn notifications off
  List<Reminder> upcoming({
    required DateTime from,
    required Set<DateTime> loggedDates,
    int hour = 18,
    int minute = 30,
    int days = 14,
  }) {
    final logged = {for (final d in loggedDates) _dateOnly(d)};
    final out = <Reminder>[];

    for (var i = 0; i < days; i++) {
      final date = ProgrammeCalendar.addDays(_dateOnly(from), i);
      final planned = calendar.forDate(date);
      final day = planned.day;
      if (day == null) continue;
      if (day.kind == DayKind.rest) continue;
      if (day.optional) continue;
      if (logged.contains(date)) continue;

      final at = DateTime(date.year, date.month, date.day, hour, minute);
      if (!at.isAfter(from)) continue;

      out.add((
        at: at,
        title: day.title,
        body: day.estMinutes > 0
            ? '${day.estMinutes} minutes. ${_lead(planned)}'
            : _lead(planned),
      ));
    }
    return out;
  }

  /// The first thing on the card — what you actually walk downstairs to do.
  static String _lead(PlannedDay planned) {
    final day = planned.day;
    if (day == null) return 'Training day.';
    final first = day.loggedPrescriptions.isEmpty
        ? null
        : day.loggedPrescriptions.first;
    if (first == null) return 'Training day.';
    return 'Opens with ${first.sets} x ${first.repRangeLabel}.';
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
