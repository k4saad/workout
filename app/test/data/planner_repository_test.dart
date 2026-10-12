import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/planner_repository.dart';
import 'package:keller_twelve/domain/planner/planner.dart';

/// The planner's rows: one change on one date, laid over a timetable that
/// itself never changes.
void main() {
  late AppDatabase db;
  late PlannerRepository repo;
  final mon = DateTime(2026, 10, 12);
  final fri = DateTime(2026, 10, 16);

  setUp(() {
    db = AppDatabase.memory();
    repo = PlannerRepository(db);
  });
  tearDown(() => db.close());

  Future<List<PlannerEntry>> week() =>
      repo.between(mon, DateTime(2026, 10, 18));

  test('an entry of his own round-trips, by date', () async {
    final id = await repo.addEvent(
      date: DateTime(2026, 10, 14, 15, 30),
      title: 'Exam prep',
      start: 14 * 60,
      end: 16 * 60,
      category: 'study',
    );
    final e = (await week()).single;
    expect(e.id, id);
    expect(e.kind, EntryKind.event);
    expect(e.date, DateTime(2026, 10, 14), reason: 'stored at midnight');
    expect(e.title, 'Exam prep');
    expect(e.start, 14 * 60);
    expect(e.end, 16 * 60);
    expect(e.remind, isTrue);
    expect(e.category, 'study');

    await repo.updateEvent(
      id,
      title: 'Exam',
      start: 9 * 60,
      end: 11 * 60,
      remind: false,
    );
    final changed = (await week()).single;
    expect(changed.title, 'Exam');
    expect(changed.remind, isFalse);

    await repo.delete(id);
    expect(await week(), isEmpty);
  });

  test('skipping twice is one skip; bringing it back removes it', () async {
    await repo.setSkipped(mon, 'gis-mon', true);
    await repo.setSkipped(mon, 'gis-mon', true);
    expect((await week()).where((e) => e.kind == EntryKind.skip), hasLength(1));
    await repo.setSkipped(mon, 'gis-mon', false);
    expect(await week(), isEmpty);
  });

  test('a skip on one block leaves another alone', () async {
    final thu = DateTime(2026, 10, 15);
    await repo.setSkipped(thu, 'sii-thu', true);
    await repo.setSkipped(thu, 'sii-ex-thu', true);
    await repo.setSkipped(thu, 'sii-thu', false);
    expect((await week()).single.blockId, 'sii-ex-thu');
  });

  test('a Friday is marked and unmarked', () async {
    await repo.setMarked(fri, 'job2-fri', true);
    final e = (await week()).single;
    expect(e.kind, EntryKind.mark);
    expect(e.blockId, 'job2-fri');
    await repo.setMarked(fri, 'job2-fri', false);
    expect(await week(), isEmpty);
  });

  test('a moved session keeps only its latest time, and goes back', () async {
    await repo.setSessionTime(mon, 19 * 60);
    await repo.setSessionTime(mon, 19 * 60 + 30);
    final e = (await week()).single;
    expect(e.kind, EntryKind.sessionTime);
    expect(e.start, 19 * 60 + 30);
    await repo.setSessionTime(mon, null);
    expect(await week(), isEmpty);
  });

  test('the live stream sees a change at once', () async {
    final stream = repo.watch(mon, DateTime(2026, 10, 18));
    await repo.setMarked(fri, 'job2-fri', true);
    expect(await stream.first, hasLength(1));
  });
}
