import '../calendar/adherence.dart';
import '../calendar/programme_calendar.dart';
import '../models/programme.dart';

/// A shoot, as a checkpoint sees it: when, and which poses it has.
typedef ShootEvidence = ({DateTime on, Set<String> poses});

/// One tape-measure reading: when, and where.
typedef MeasureEvidence = ({DateTime on, String site});

/// What the app already holds that a checkpoint could be ticked from.
///
/// Gathered by the data layer and handed over whole; the rules about which
/// of it counts live here, where they can be tested.
class CheckpointEvidence {
  const CheckpointEvidence({
    this.shoots = const [],
    this.measurements = const [],
    this.weighIns = const [],
    this.sessions,
  });

  final List<ShootEvidence> shoots;
  final List<MeasureEvidence> measurements;
  final List<DateTime> weighIns;

  /// The required sessions from week 1 to the checkpoint week, tallied.
  final SessionTally? sessions;
}

/// One line of a checkpoint, ticked or not.
class CheckItem {
  const CheckItem({
    required this.index,
    required this.text,
    required this.done,
    this.auto,
  });

  final int index;
  final String text;
  final bool done;

  /// Set when the app ticks this line itself; null when it is ticked by
  /// hand.
  final CheckKind? auto;
}

abstract final class CheckpointReview {
  /// The dates a checkpoint's evidence may come from: its own week and the
  /// week before. A shoot on the Sunday before counts; one a month earlier
  /// is the previous checkpoint's.
  static ({DateTime from, DateTime to}) window(
    ProgrammeCalendar calendar,
    int week,
  ) {
    final start = calendar.startOfWeek(week);
    return (
      from: ProgrammeCalendar.addDays(start, -7),
      to: ProgrammeCalendar.addDays(start, 6),
    );
  }

  /// Every line of [checkpoint], with what the evidence says about it.
  ///
  /// [poses] are the poses a full shoot needs; [sites] the measurements;
  /// [ticked] the indices ticked by hand, which count only for lines the
  /// app cannot check itself.
  static List<CheckItem> review({
    required Checkpoint checkpoint,
    required ProgrammeCalendar calendar,
    required CheckpointEvidence evidence,
    required Set<String> poses,
    required List<String> sites,
    Set<int> ticked = const {},
  }) {
    final w = window(calendar, checkpoint.week);
    bool inside(DateTime d) {
      final day = DateTime(d.year, d.month, d.day);
      return !day.isBefore(w.from) && !day.isAfter(w.to);
    }

    bool met(CheckKind kind) => switch (kind) {
      CheckKind.photos =>
        poses.isNotEmpty &&
            evidence.shoots.any(
              (s) => inside(s.on) && s.poses.containsAll(poses),
            ),
      CheckKind.measurements =>
        sites.isNotEmpty &&
            {
              for (final m in evidence.measurements)
                if (inside(m.on)) m.site,
            }.containsAll(sites),
      CheckKind.weighIn => evidence.weighIns.any(inside),
      CheckKind.sessionsLogged => switch (evidence.sessions) {
        final t? => t.required > 0 && t.missed == 0 && t.remaining == 0,
        null => false,
      },
    };

    return [
      for (final (i, text) in checkpoint.items.indexed)
        switch (checkpoint.autoFor(i)) {
          final kind? => CheckItem(
            index: i,
            text: text,
            auto: kind,
            done: met(kind),
          ),
          null => CheckItem(index: i, text: text, done: ticked.contains(i)),
        },
    ];
  }
}
