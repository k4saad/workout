import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/session_providers.dart';
import '../../core/ui/ui.dart';
import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../common/widgets.dart';

/// A flat list of what has actually happened.
///
/// The proper calendar arrives in Phase 4; this is enough to check the morning
/// after that last night's sets really landed.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: async.when(
        loading: () => const SkeletonPage(),
        error: (e, _) => AsyncScaffoldBody(
          loading: false,
          error: e,
          child: const SizedBox(),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(28),
              child: Center(
                child: Text(
                  'Nothing logged yet.\n\nA session you did not log is a '
                  'session you cannot beat next week.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: AppTheme.textDim),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: Gap.pagePadding,
            itemCount: sessions.length,
            separatorBuilder: (_, _) => Gap.m,
            itemBuilder: (context, i) => SessionCard(session: sessions[i]),
          );
        },
      ),
    );
  }
}

/// One logged session: when, what, and every working set.
///
/// Shared by History and the calendar's day sheet, so a session reads the
/// same wherever it is looked at.
class SessionCard extends ConsumerWidget {
  const SessionCard({super.key, required this.session, this.showDate = true});

  final Session session;

  /// Off inside a day sheet, which already says what day it is.
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final sets = ref.watch(sessionSetsProvider(session.id)).asData?.value ?? [];
    final working = sets.where((s) => !s.isWarmup).toList();
    final bundle = ref.watch(bundleProvider).asData?.value;
    final library = bundle?.library;
    // The day's name as the programme had it on the date it was planned for.
    // A session from a plan since replaced is named as that, not by an id —
    // nor as "Rest", when a moved week made its day a rest day (a Tuesday
    // trained on v4, before v4.1 moved training to Monday). Its sets below
    // still say what was done.
    final planned = bundle?.calendar.forDate(session.plannedDate).day;
    final title =
        planned != null && planned.id == session.dayId && planned.isTrainingDay
        ? planned.title
        : 'Earlier plan';

    final duration = session.startedAt != null && session.finishedAt != null
        ? session.finishedAt!.difference(session.startedAt!).inMinutes
        : null;

    final byExercise = <String, List<SetLog>>{};
    for (final s in working) {
      (byExercise[s.exerciseId] ??= []).add(s);
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  showDate
                      ? DateFormat('EEE d MMM')
                            .format(session.scheduledDate)
                            .toUpperCase()
                      : 'WEEK ${session.weekNo}',
                  style: t.labelLarge?.copyWith(color: AppTheme.textDim),
                ),
              ),
              _StatusGlyph(status: session.status),
            ],
          ),
          Gap.xs,
          Text(
            showDate ? 'Week ${session.weekNo} · $title' : title,
            style: t.titleMedium,
          ),
          Gap.s,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoChip(label: '${working.length} sets'),
              if (duration != null)
                InfoChip(label: '$duration min', icon: Icons.schedule_outlined),
              if (session.bodyweightKg != null)
                InfoChip(label: '${session.bodyweightKg} kg BW'),
              if (session.loggedRetroactively)
                const InfoChip(label: 'from memory'),
              if (session.wasShortened) const InfoChip(label: 'short'),
            ],
          ),
          if (byExercise.isNotEmpty) ...[
            const Divider(height: 22),
            for (final entry in byExercise.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        library?.resolve(entry.key).name ?? entry.key,
                        style: t.bodyMedium,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _summarise(entry.value),
                        textAlign: TextAlign.end,
                        style: t.bodyMedium?.copyWith(
                          color: AppTheme.textDim,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _summarise(List<SetLog> sets) {
    final reps = sets
        .map((s) => s.reps ?? s.durationSec ?? 0)
        .map((v) => '$v')
        .join(', ');
    final loads = sets.map((s) => s.loadKg).whereType<double>().toSet();
    if (loads.isEmpty) return reps;
    if (loads.length == 1) {
      return '$reps @ ${_fmt(loads.first)}';
    }
    return '$reps @ ${loads.map(_fmt).join('/')}';
  }

  static String _fmt(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    // Glyph AND colour — never colour on its own.
    final (glyph, color, label) = switch (status) {
      SessionStatus.completed => ('✓', AppTheme.good, 'done'),
      SessionStatus.partial => ('◐', AppTheme.warn, 'partial'),
      SessionStatus.skipped => ('⊘', AppTheme.textDim, 'skipped'),
      SessionStatus.inProgress => ('▶', AppTheme.oxblood, 'running'),
      SessionStatus.planned => ('○', AppTheme.textDim, 'planned'),
    };
    return Row(
      children: [
        Text(glyph, style: TextStyle(color: color, fontSize: 15)),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
        ),
      ],
    );
  }
}
