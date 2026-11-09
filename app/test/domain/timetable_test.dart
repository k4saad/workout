import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/models/enums.dart';
import 'package:keller_twelve/domain/planner/planner.dart';

import '../support/fixtures.dart';

/// The week as data he can change on the phone (docs/13-your-week-plan.md):
/// what a block is, how a timetable is edited, and V22 as the phone runs it.
/// Written before the editor.
void main() {
  final shipped = Timetable.fromJson(Fixtures.timetableJson);

  TimetableBlock block(
    String id,
    List<Weekday> days,
    String start,
    String end, {
    PlanKind kind = PlanKind.lecture,
    String? place = 'campus',
    bool offInBreaks = false,
  }) => TimetableBlock(
    id: id,
    days: days,
    start: parseHhmm(start),
    end: parseHhmm(end),
    kind: kind,
    title: id,
    place: place,
    offInBreaks: offInBreaks,
  );

  Timetable week(List<TimetableBlock> blocks) => Timetable(
    name: 'Test term',
    lecturesFrom: DateTime(2026, 10, 12),
    lecturesTo: DateTime(2027, 2, 5),
    breaks: [
      TimetableBreak(
        'Winter break',
        DateTime(2026, 12, 23),
        DateTime(2027, 1, 3),
      ),
    ],
    travelMinutes: 30,
    places: const {'campus': 'Campus', 'job1': 'Job 1', 'library': 'Library'},
    blocks: blocks,
  );

  group('a block', () {
    test('is on one day or several', () {
      final german = TimetableBlock.fromJson({
        'id': 'german',
        'days': ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
        'start': '20:00',
        'end': '21:00',
        'kind': 'study',
        'title': 'German',
      });
      expect(german.days, Weekday.values);
      expect(german.kind, PlanKind.study);
      expect(german.place, isNull, reason: 'anywhere: no travel');
      expect(german.minutes, 60);
    });

    test('still reads the single weekday of a v1 file', () {
      final b = TimetableBlock.fromJson({
        'id': 'gis-mon',
        'weekday': 'mon',
        'start': '10:15',
        'end': '11:45',
        'kind': 'lecture',
        'title': 'Geoinformation in Society',
        'place': 'campus',
      });
      expect(b.days, [Weekday.mon]);
      expect(b.isOn(Weekday.mon), isTrue);
      expect(b.isOn(Weekday.tue), isFalse);
    });

    test('keeps its days in week order, once each', () {
      final b = TimetableBlock.fromJson({
        'id': 'lib',
        'days': ['fri', 'tue', 'fri'],
        'start': '15:00',
        'end': '18:00',
        'kind': 'study',
        'title': 'Library',
        'place': 'library',
      });
      expect(b.days, [Weekday.tue, Weekday.fri]);
    });

    test('round-trips through JSON', () {
      final b = TimetableBlock(
        id: 'job2-fri',
        days: const [Weekday.fri],
        start: 7 * 60,
        end: 9 * 60 + 30,
        kind: PlanKind.job,
        title: 'Job 2',
        place: 'job2',
        room: 'Back office',
        who: 'Anna',
        optional: true,
        onlyWhenMarked: true,
        offInBreaks: true,
        note: 'Every fifth week.',
      );
      final again = TimetableBlock.fromJson(
        jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>,
      );
      expect(again.toJson(), b.toJson());
      expect(again.days, [Weekday.fri]);
      expect(again.offInBreaks, isTrue);
      expect(b.toJson()['start'], '07:00');
      expect(b.toJson()['days'], ['fri']);
    });

    test('can be given its id when it is saved', () {
      final draft = TimetableBlock(
        id: '',
        days: const [Weekday.tue, Weekday.fri],
        start: 15 * 60,
        end: 18 * 60,
        kind: PlanKind.study,
        title: 'Library',
        place: 'library',
        offInBreaks: true,
        note: 'Subjects.',
      );
      final saved = draft.withId('library');
      expect(saved.id, 'library');
      expect(
        {...saved.toJson()}..remove('id'),
        {...draft.toJson()}..remove('id'),
      );
    });

    test('leaves out what it does not have', () {
      final j = block('x', const [Weekday.mon], '10:00', '11:00').toJson();
      expect(j.containsKey('room'), isFalse);
      expect(j.containsKey('optional'), isFalse);
      expect(j.containsKey('offInBreaks'), isFalse);
    });

    test('rejects a kind it does not know', () {
      expect(
        () => TimetableBlock.fromJson({
          'id': 'x',
          'days': ['mon'],
          'start': '10:00',
          'end': '11:00',
          'kind': 'nap',
          'title': 'x',
        }),
        throwsFormatException,
      );
    });
  });

  group('the timetable', () {
    test('round-trips through JSON, the shipped one included', () {
      final again = Timetable.fromJson(
        jsonDecode(jsonEncode(shipped.toJson())) as Map<String, dynamic>,
      );
      expect(again.toJson(), shipped.toJson());
      expect(again.blocks.length, shipped.blocks.length);
    });

    test('lists a day earliest first, several-day blocks included', () {
      final t = week([
        block('late', const [Weekday.tue], '16:00', '17:00'),
        block('every', Weekday.values, '08:00', '09:00', place: null),
        block('early', const [Weekday.tue], '10:00', '11:00'),
      ]);
      expect(t.on(Weekday.tue).map((b) => b.id), ['every', 'early', 'late']);
      expect(t.on(Weekday.sun).map((b) => b.id), ['every']);
    });

    test('lectures run in term only; the rest all year', () {
      final lecture = block('l', const [Weekday.wed], '10:00', '11:00');
      final job = block(
        'j',
        const [Weekday.wed],
        '12:00',
        '13:00',
        kind: PlanKind.job,
        place: 'job1',
      );
      final t = week([lecture, job]);
      final inTerm = DateTime(2026, 11, 11);
      final inBreak = DateTime(2026, 12, 30);
      final after = DateTime(2027, 2, 10);
      expect(t.runsOn(lecture, inTerm), isTrue);
      expect(t.runsOn(lecture, inBreak), isFalse);
      expect(t.runsOn(lecture, after), isFalse);
      expect(t.runsOn(job, inBreak), isTrue);
      expect(t.runsOn(job, after), isTrue);
    });

    test('a block can be off in the breaks and still run after term', () {
      final library = block(
        'lib',
        const [Weekday.fri],
        '15:00',
        '18:00',
        kind: PlanKind.study,
        place: 'library',
        offInBreaks: true,
      );
      final t = week([library]);
      expect(t.runsOn(library, DateTime(2026, 11, 13)), isTrue);
      expect(t.runsOn(library, DateTime(2026, 12, 25)), isFalse);
      expect(
        t.runsOn(library, DateTime(2027, 2, 12)),
        isTrue,
        reason: 'the exams come after the lectures',
      );
    });
  });

  group('editing it', () {
    final base = week([
      block('a', const [Weekday.mon], '10:00', '11:00'),
    ]);

    test('adds a block, or replaces the one with its id', () {
      final added = base.withBlock(
        block('b', const [Weekday.tue], '12:00', '13:00'),
      );
      expect(added.blocks.map((b) => b.id), ['a', 'b']);
      final moved = added.withBlock(
        block('a', const [Weekday.wed], '09:00', '10:00'),
      );
      expect(moved.blocks.map((b) => b.id), ['a', 'b']);
      expect(moved.block('a')!.days, [Weekday.wed]);
      expect(base.blocks, hasLength(1), reason: 'the old one is untouched');
    });

    test('removes a block', () {
      expect(base.withoutBlock('a').blocks, isEmpty);
      expect(base.withoutBlock('nope').blocks, hasLength(1));
    });

    test('a new id is new, and reads like its title', () {
      final t = base.withBlock(
        block('german', Weekday.values, '20:00', '21:00', place: null),
      );
      expect(t.newBlockId('German'), 'german-2');
      expect(t.newBlockId('Spatial Justice'), 'spatial-justice');
      expect(t.newBlockId('  '), 'block');
      expect(t.newPlaceId('Library'), 'library-2');
      expect(t.newPlaceId('Café Müller'), 'cafe-muller');
    });

    test('places are added and renamed, and one in use cannot go', () {
      final t = base.withPlace('gym', 'Gym').withPlace('campus', 'Uni');
      expect(t.places['gym'], 'Gym');
      expect(t.places['campus'], 'Uni');
      expect(t.usesOf('campus').map((b) => b.id), ['a']);
      expect(() => t.withoutPlace('campus'), throwsStateError);
      expect(t.withoutPlace('gym').places.containsKey('gym'), isFalse);
    });

    test('the semester itself changes with copyWith', () {
      final t = base.copyWith(
        name: 'Summer Semester 2027',
        lecturesFrom: DateTime(2027, 4, 12),
        lecturesTo: DateTime(2027, 7, 23),
        breaks: const [],
        travelMinutes: 20,
      );
      expect(t.name, 'Summer Semester 2027');
      expect(t.hasLectures(DateTime(2027, 4, 12)), isTrue);
      expect(t.breaks, isEmpty);
      expect(t.travelMinutes, 20);
      expect(t.blocks, base.blocks);
    });
  });

  group('V22 on the phone', () {
    const validator = TimetableValidator();

    List<String> errors(Timetable t) => [
      for (final p in validator.check(t))
        if (p.isError) p.message,
    ];
    List<String> warnings(Timetable t) => [
      for (final p in validator.check(t))
        if (!p.isError) p.message,
    ];

    test('the shipped week is clean', () {
      expect(validator.check(shipped), isEmpty);
    });

    test('two blocks on top of each other', () {
      final t = week([
        block('Library', const [Weekday.tue], '15:00', '18:00'),
        block('German', Weekday.values, '17:30', '18:30', place: null),
      ]);
      expect(warnings(t).single, contains('German'));
      expect(warnings(t).single, contains('Library'));
      expect(errors(t), isEmpty);
    });

    test('too little time to get between two places', () {
      final t = week([
        block(
          'Job 1',
          const [Weekday.wed],
          '09:00',
          '13:45',
          kind: PlanKind.job,
          place: 'job1',
        ),
        block('Spatial Justice', const [Weekday.wed], '14:00', '15:30'),
      ]);
      expect(warnings(t).single, contains('15 min'));
    });

    test('a block anywhere needs no travel', () {
      final t = week([
        block('Lecture', const [Weekday.wed], '10:00', '11:00'),
        block('German', const [Weekday.wed], '11:00', '12:00', place: null),
      ]);
      expect(validator.check(t), isEmpty);
    });

    test('what the app cannot work with', () {
      final t = week([
        block('backwards', const [Weekday.mon], '11:00', '10:00'),
        block('nowhere', const [Weekday.mon], '12:00', '13:00', place: 'mars'),
        block('never', const [], '14:00', '15:00'),
        block('twice', const [Weekday.tue], '09:00', '10:00'),
        block('twice', const [Weekday.wed], '09:00', '10:00'),
      ]);
      final e = errors(t).join('\n');
      expect(e, contains('ends before it starts'));
      expect(e, contains('mars'));
      expect(e, contains('no days'));
      expect(e, contains('twice'));
    });

    test('the semester\'s own dates', () {
      final t = week(const []).copyWith(
        lecturesTo: DateTime(2026, 10, 1),
        breaks: [
          TimetableBreak('Late', DateTime(2027, 3, 1), DateTime(2027, 3, 8)),
        ],
        travelMinutes: 0,
      );
      final e = errors(t).join('\n');
      expect(e, contains('lecture period ends before it starts'));
      expect(warnings(t).join('\n'), contains('Late'));
      expect(e, isNot(contains('travel')), reason: '0 min: same building');
    });

    test('clashes names what one block runs into', () {
      final library = block(
        'Library',
        const [Weekday.tue, Weekday.fri],
        '15:00',
        '18:00',
        kind: PlanKind.study,
        place: 'library',
      );
      final t = week([
        library,
        block('Jumuah', const [Weekday.fri], '14:00', '14:45'),
        block('German', Weekday.values, '17:00', '18:00', place: null),
      ]);
      final c = validator.clashes(t, library);
      expect(c, hasLength(3));
      expect(c.where((m) => m.contains('German')), hasLength(2));
      expect(c.where((m) => m.contains('Jumuah')).single, contains('15 min'));
    });
  });
}
