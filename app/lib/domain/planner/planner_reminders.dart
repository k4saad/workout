import 'day_planner.dart';
import 'timetable.dart';

/// One notification to lay: when, and what it says.
typedef PlannerReminder = ({DateTime at, String title, String body});

/// What rings before something starts, worked out from planned days.
///
/// A class rings [classLead] minutes before, with its room. Work rings when
/// it is time to leave: the travel time and [leaveSlack] before the shift —
/// or the moment the class before it ends, never in the middle of a
/// lecture. A session rings [sessionLead] minutes before, unless he has
/// already trained or it is optional. His own study rings [classLead]
/// minutes before, or — the library, somewhere to get to — when it is time
/// to leave for it. His own entries ring when he asked. Meals, travel and
/// prayer never ring.
///
/// Pure: the notification plugin is the data layer's business.
class PlannerReminders {
  const PlannerReminders({
    this.classLead = 15,
    this.sessionLead = 30,
    this.eventLead = 15,
    this.leaveSlack = 10,
  });

  final int classLead;
  final int sessionLead;
  final int eventLead;
  final int leaveSlack;

  List<PlannerReminder> build(
    List<DayPlan> plans, {
    required DateTime from,
    required int travelMinutes,
    bool classes = true,
    bool work = true,
    bool sessions = true,
    bool study = true,
    Set<DateTime> trained = const {},
  }) {
    final done = {for (final d in trained) DateTime(d.year, d.month, d.day)};
    final out = <PlannerReminder>[];
    for (final p in plans) {
      DateTime at(int minute) => DateTime(
        p.date.year,
        p.date.month,
        p.date.day,
        minute ~/ 60,
        minute % 60,
      );

      for (final i in p.items) {
        int? minute;
        String? body;
        switch (i.kind) {
          case PlanKind.lecture when classes:
            minute = i.start - classLead;
            body = [?i.room, ?i.who, 'in $classLead minutes'].join(' · ');
          case PlanKind.job when work:
            minute = i.start - travelMinutes - leaveSlack;
            // Inside a class? Ring as it ends.
            for (final c in p.commitments) {
              if (c != i && c.start < minute! && minute < c.end) {
                minute = c.end;
              }
            }
            body =
                'Leave by ${formatHhmm(i.start - travelMinutes)}: '
                '$travelMinutes min to get there.';
          case PlanKind.study when study:
            // Somewhere to get to: ring when the ride there starts.
            final ride = p.travel.where((l) => l.end == i.start).firstOrNull;
            if (ride != null) {
              minute = ride.start - leaveSlack;
              for (final c in p.commitments) {
                if (c != i && c.start < minute! && minute < c.end) {
                  minute = c.end;
                }
              }
              body =
                  'Leave by ${formatHhmm(ride.start)}: '
                  '${ride.minutes} min to get there.';
            } else {
              minute = i.start - classLead;
              body = [
                ?i.room,
                '${i.minutes} min',
                'in $classLead minutes',
              ].join(' · ');
            }
          case PlanKind.session when sessions:
            if (i.optional || done.contains(p.date)) continue;
            minute = i.start - sessionLead;
            body = '${i.minutes} min, in the basement in half an hour.';
          case PlanKind.event when i.remind:
            minute = i.start - eventLead;
            body = 'In $eventLead minutes.';
          default:
            continue;
        }
        final when = at(minute!);
        if (!when.isAfter(from)) continue;
        out.add((
          at: when,
          title: '${i.title} · ${formatHhmm(i.start)}',
          body: body,
        ));
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }
}
