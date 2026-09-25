import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/calendar/adherence.dart';
import 'package:keller_twelve/domain/calendar/programme_calendar.dart';
import 'package:keller_twelve/domain/models/programme.dart';
import 'package:keller_twelve/domain/progress/checkpoint_review.dart';

import '../support/fixtures.dart';

/// A checkpoint that ticks itself: the photos, the tape and the scale are
/// already in the app, so asking him to tick them as well is asking twice.
void main() {
  final programme = Fixtures.programme;
  final calendar = ProgrammeCalendar(programme);

  DateTime day(int week, int offset) =>
      ProgrammeCalendar.addDays(calendar.startOfWeek(week), offset);

  const poses = {'front-relaxed', 'front-flexed', 'side-right', 'back'};
  const sites = ['waist', 'chest', 'upperArm', 'thigh', 'neck'];

  const week4 = Checkpoint(
    week: 4,
    items: ['Photos', 'Measurements', 'Squat moving', 'Every session logged'],
    autoTick: {
      CheckKind.photos: 0,
      CheckKind.measurements: 1,
      CheckKind.sessionsLogged: 3,
    },
  );

  List<CheckItem> review(
    CheckpointEvidence evidence, {
    Checkpoint checkpoint = week4,
    Set<int> ticked = const {},
  }) => CheckpointReview.review(
    checkpoint: checkpoint,
    calendar: calendar,
    evidence: evidence,
    poses: poses,
    sites: sites,
    ticked: ticked,
  );

  group('the window', () {
    test('is the checkpoint week and the week before it', () {
      final w = CheckpointReview.window(calendar, 4);
      expect(w.from, day(3, 0));
      expect(w.to, day(4, 6));
    });
  });

  group('photos', () {
    test('tick with a shoot of every pose inside the window', () {
      final items = review(
        CheckpointEvidence(shoots: [(on: day(4, 1), poses: poses)]),
      );
      expect(items[0].done, isTrue);
      expect(items[0].auto, CheckKind.photos);
    });

    test('a shoot the Sunday before counts; one in week 2 does not', () {
      expect(
        review(
          CheckpointEvidence(shoots: [(on: day(3, 6), poses: poses)]),
        )[0].done,
        isTrue,
      );
      expect(
        review(
          CheckpointEvidence(shoots: [(on: day(2, 3), poses: poses)]),
        )[0].done,
        isFalse,
      );
    });

    test('three poses of four is not a shoot', () {
      final items = review(
        CheckpointEvidence(
          shoots: [
            (on: day(4, 1), poses: {'front-relaxed', 'front-flexed', 'back'}),
          ],
        ),
      );
      expect(items[0].done, isFalse);
    });
  });

  group('measurements', () {
    test('tick when every site is in, over any days of the window', () {
      final items = review(
        CheckpointEvidence(
          measurements: [
            for (final s in sites.take(3)) (on: day(4, 0), site: s),
            for (final s in sites.skip(3)) (on: day(4, 2), site: s),
          ],
        ),
      );
      expect(items[1].done, isTrue);
    });

    test('one site short is not done, and an extra site does not help', () {
      final items = review(
        CheckpointEvidence(
          measurements: [
            for (final s in sites.take(4)) (on: day(4, 0), site: s),
            (on: day(4, 0), site: 'hips'),
          ],
        ),
      );
      expect(items[1].done, isFalse);
    });
  });

  group('the weigh-in', () {
    const week1 = Checkpoint(
      week: 1,
      items: ['Photos', 'First bodyweight entry'],
      autoTick: {CheckKind.photos: 0, CheckKind.weighIn: 1},
    );

    test('ticks on any weigh-in in the window, including before day one', () {
      final items = review(
        CheckpointEvidence(weighIns: [day(1, -3)]),
        checkpoint: week1,
      );
      expect(items[1].done, isTrue);
      expect(items[0].done, isFalse);
    });
  });

  group('every session logged', () {
    test('only once nothing was missed and nothing is left', () {
      bool done(SessionTally t) =>
          review(CheckpointEvidence(sessions: t))[3].done;

      expect(
        done(const SessionTally(required: 12, done: 11, skipped: 1, missed: 0)),
        isTrue,
        reason: 'a skip is logged; it is not a hole',
      );
      expect(
        done(const SessionTally(required: 12, done: 10, skipped: 1, missed: 1)),
        isFalse,
      );
      expect(
        done(const SessionTally(required: 12, done: 10, skipped: 0, missed: 0)),
        isFalse,
        reason: 'two still to come',
      );
      expect(review(const CheckpointEvidence())[3].done, isFalse);
    });
  });

  group('the rest', () {
    test('are ticked by hand, and a hand tick cannot fake a shoot', () {
      final items = review(const CheckpointEvidence(), ticked: {0, 2});
      expect(items[2].done, isTrue);
      expect(items[2].auto, isNull);
      expect(items[0].done, isFalse, reason: 'photos tick themselves only');
    });
  });

  group('the shipped programme', () {
    test('photos and measurements tick themselves at every checkpoint', () {
      expect(programme.checkpoints, isNotEmpty);
      for (final c in programme.checkpoints) {
        expect(
          c.autoTick.keys,
          containsAll([CheckKind.photos, CheckKind.measurements]),
          reason: 'week ${c.week}',
        );
        for (final i in c.autoTick.values) {
          expect(i, inInclusiveRange(0, c.items.length - 1));
        }
      }
    });

    test('names the sites to measure', () {
      expect(programme.measurementSites, sites);
    });
  });
}
