import 'package:drift/drift.dart';

import '../domain/planner/planner.dart';
import 'db/database.dart';

/// The changes he makes in the planner, in the app's database: his own
/// entries, the classes he skips, the Fridays he works, the sessions he
/// moves. Each is one row on one date; the timetable underneath never
/// changes.
class PlannerRepository {
  PlannerRepository(this.db);

  final AppDatabase db;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static PlannerEntry toEntry(PlannerRow r) => PlannerEntry.stored(
    id: r.id,
    date: r.onDate,
    kind: r.kind,
    blockId: r.blockId,
    title: r.title,
    start: r.startMin,
    end: r.endMin,
    remind: r.remind,
    category: r.category,
  );

  /// Entries dated [from]..[to], live.
  Stream<List<PlannerEntry>> watch(DateTime from, DateTime to) => db
      .watchPlannerEntries(from, to)
      .map((rows) => [for (final r in rows) toEntry(r)]);

  Future<List<PlannerEntry>> between(DateTime from, DateTime to) async => [
    for (final r in await db.plannerEntriesBetween(from, to)) toEntry(r),
  ];

  /// Adds one of his own to [date]: [start] to [end] minutes after midnight.
  Future<int> addEvent({
    required DateTime date,
    required String title,
    required int start,
    required int end,
    bool remind = true,
    String? category,
  }) => db
      .into(db.plannerEntries)
      .insert(
        PlannerEntriesCompanion.insert(
          onDate: _day(date),
          kind: EntryKind.event.name,
          title: Value(title),
          startMin: Value(start),
          endMin: Value(end),
          remind: Value(remind),
          category: Value(category),
        ),
      );

  Future<void> updateEvent(
    int id, {
    required String title,
    required int start,
    required int end,
    required bool remind,
    String? category,
  }) => (db.update(db.plannerEntries)..where((e) => e.id.equals(id))).write(
    PlannerEntriesCompanion(
      title: Value(title),
      startMin: Value(start),
      endMin: Value(end),
      remind: Value(remind),
      category: Value(category),
    ),
  );

  Future<void> delete(int id) =>
      (db.delete(db.plannerEntries)..where((e) => e.id.equals(id))).go();

  Future<void> _clear(DateTime date, EntryKind kind, {String? blockId}) =>
      (db.delete(db.plannerEntries)..where(
            (e) =>
                e.onDate.equals(_day(date)) &
                e.kind.equals(kind.name) &
                (blockId == null
                    ? const Constant(true)
                    : e.blockId.equals(blockId)),
          ))
          .go();

  /// Skips [blockId] on [date], or brings it back.
  Future<void> setSkipped(DateTime date, String blockId, bool skipped) =>
      db.transaction(() async {
        await _clear(date, EntryKind.skip, blockId: blockId);
        if (!skipped) return;
        await db
            .into(db.plannerEntries)
            .insert(
              PlannerEntriesCompanion.insert(
                onDate: _day(date),
                kind: EntryKind.skip.name,
                blockId: Value(blockId),
              ),
            );
      });

  /// Puts [blockId] (one that happens only when marked) on [date], or takes
  /// it off.
  Future<void> setMarked(DateTime date, String blockId, bool marked) =>
      db.transaction(() async {
        await _clear(date, EntryKind.mark, blockId: blockId);
        if (!marked) return;
        await db
            .into(db.plannerEntries)
            .insert(
              PlannerEntriesCompanion.insert(
                onDate: _day(date),
                kind: EntryKind.mark.name,
                blockId: Value(blockId),
              ),
            );
      });

  /// Moves the session on [date] to [start] minutes after midnight; null
  /// puts it back where the planner would have it.
  Future<void> setSessionTime(DateTime date, int? start) =>
      db.transaction(() async {
        await _clear(date, EntryKind.sessionTime);
        if (start == null) return;
        await db
            .into(db.plannerEntries)
            .insert(
              PlannerEntriesCompanion.insert(
                onDate: _day(date),
                kind: EntryKind.sessionTime.name,
                startMin: Value(start),
              ),
            );
      });
}
