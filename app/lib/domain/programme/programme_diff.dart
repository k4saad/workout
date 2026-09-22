import '../models/prescription.dart';
import '../models/programme.dart';

enum ChangeKind { added, removed, modified }

/// One difference between two programmes, in words.
class Change {
  const Change({
    required this.kind,
    required this.scope,
    required this.id,
    required this.description,
  });

  final ChangeKind kind;

  /// `block`, `day` or `exercise`.
  final String scope;
  final String id;
  final String description;

  String get glyph => switch (kind) {
    ChangeKind.added => '+',
    ChangeKind.removed => '−',
    ChangeKind.modified => '~',
  };

  @override
  String toString() => '$glyph $scope $id: $description';
}

/// What applying a programme would do to the one you have.
///
/// Shown before every import and before the cycle-2 seed. Overwriting a
/// twelve-week programme is not something to do on a mis-tap, and "it
/// replaced my Thursday" is not a thing you want to discover mid-session.
class ProgrammeDiff {
  const ProgrammeDiff({
    required this.from,
    required this.to,
    required this.changes,
  });

  final Programme from;
  final Programme to;
  final List<Change> changes;

  bool get isEmpty => changes.isEmpty;

  /// The incoming programme is older than or level with what is on the phone.
  ///
  /// Nearly always means an edit made on the phone since the export, and it
  /// is exactly the case where an import silently loses work.
  bool get isRevisionConflict => to.revision <= from.revision;

  List<Change> ofKind(ChangeKind k) =>
      changes.where((c) => c.kind == k).toList(growable: false);

  String get summary {
    if (isEmpty) return 'Identical — nothing would change.';
    final a = ofKind(ChangeKind.added).length;
    final r = ofKind(ChangeKind.removed).length;
    final m = ofKind(ChangeKind.modified).length;
    return [
      if (a > 0) '$a added',
      if (r > 0) '$r removed',
      if (m > 0) '$m changed',
    ].join(' · ');
  }

  static ProgrammeDiff between(Programme from, Programme to) {
    final changes = <Change>[];

    void add(ChangeKind k, String scope, String id, String what) =>
        changes.add(Change(kind: k, scope: scope, id: id, description: what));

    if (from.totalWeeks != to.totalWeeks) {
      add(
        ChangeKind.modified,
        'programme',
        to.id,
        '${from.totalWeeks} weeks becomes ${to.totalWeeks}',
      );
    }
    if (from.startDate != to.startDate) {
      add(
        ChangeKind.modified,
        'programme',
        to.id,
        'starts ${_date(from.startDate)} becomes ${_date(to.startDate)}',
      );
    }

    final fromBlocks = {for (final b in from.blocks) b.id: b};
    final toBlocks = {for (final b in to.blocks) b.id: b};

    for (final id in fromBlocks.keys) {
      if (!toBlocks.containsKey(id)) {
        add(ChangeKind.removed, 'block', id, fromBlocks[id]!.name);
      }
    }
    for (final id in toBlocks.keys) {
      if (!fromBlocks.containsKey(id)) {
        add(ChangeKind.added, 'block', id, toBlocks[id]!.name);
      } else {
        final a = fromBlocks[id]!, b = toBlocks[id]!;
        if (a.weeks.join(',') != b.weeks.join(',')) {
          add(
            ChangeKind.modified,
            'block',
            id,
            'weeks ${a.weeks.join('-')} become ${b.weeks.join('-')}',
          );
        }
        if (a.inheritsDaysFrom != b.inheritsDaysFrom) {
          add(
            ChangeKind.modified,
            'block',
            id,
            b.inheritsDaysFrom == null
                ? 'detached from ${a.inheritsDaysFrom}'
                : 'now inherits from ${b.inheritsDaysFrom}',
          );
        }
      }
    }

    final fromDays = {
      for (final b in from.blocks)
        for (final d in b.days) d.id: d,
    };
    final toDays = {
      for (final b in to.blocks)
        for (final d in b.days) d.id: d,
    };
    for (final id in fromDays.keys) {
      if (!toDays.containsKey(id)) {
        add(ChangeKind.removed, 'day', id, fromDays[id]!.title);
      }
    }
    for (final id in toDays.keys) {
      if (!fromDays.containsKey(id)) {
        add(ChangeKind.added, 'day', id, toDays[id]!.title);
        continue;
      }
      final a = fromDays[id]!, b = toDays[id]!;
      if (a.weekday != b.weekday) {
        add(
          ChangeKind.modified,
          'day',
          id,
          'moves from ${a.weekday.name} to ${b.weekday.name}',
        );
      }
      if (a.title != b.title) {
        add(
          ChangeKind.modified,
          'day',
          id,
          '"${a.title}" becomes "${b.title}"',
        );
      }
      if (a.warnings.length != b.warnings.length) {
        add(
          ChangeKind.modified,
          'day',
          id,
          '${a.warnings.length} warnings become ${b.warnings.length}',
        );
      }
    }

    final fromPre = _prescriptions(from);
    final toPre = _prescriptions(to);
    for (final id in fromPre.keys) {
      if (!toPre.containsKey(id)) {
        add(ChangeKind.removed, 'exercise', id, fromPre[id]!.exerciseId);
      }
    }
    for (final id in toPre.keys) {
      final b = toPre[id]!;
      final a = fromPre[id];
      if (a == null) {
        add(ChangeKind.added, 'exercise', id, b.exerciseId);
        continue;
      }
      final notes = <String>[];
      if (a.exerciseId != b.exerciseId) {
        notes.add('${a.exerciseId} becomes ${b.exerciseId}');
      }
      if (a.sets != b.sets ||
          a.repsMin != b.repsMin ||
          a.repsMax != b.repsMax) {
        notes.add(
          '${a.sets}x${a.repRangeLabel} becomes ${b.sets}x${b.repRangeLabel}',
        );
      }
      if (a.startLoadKg != b.startLoadKg) {
        notes.add('${_kg(a.startLoadKg)} becomes ${_kg(b.startLoadKg)}');
      }
      if (a.restSec != b.restSec) {
        notes.add('rest ${a.restSec}s becomes ${b.restSec}s');
      }
      if (a.groupId != b.groupId) {
        notes.add(
          b.groupId == null ? 'no longer a superset' : 'joins a superset',
        );
      }
      if (a.targetRir != b.targetRir) {
        notes.add(
          'RIR ${a.targetRir ?? "inherited"} becomes '
          '${b.targetRir ?? "inherited"}',
        );
      }
      if (notes.isNotEmpty) {
        add(ChangeKind.modified, 'exercise', id, notes.join(', '));
      }
    }

    return ProgrammeDiff(from: from, to: to, changes: changes);
  }

  static Map<String, Prescription> _prescriptions(Programme p) => {
    for (final b in p.blocks)
      for (final d in b.days)
        for (final s in d.sections)
          for (final pre in s.prescriptions) pre.id: pre,
  };

  static String _kg(double? v) => v == null ? 'no load' : '$v kg';

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
