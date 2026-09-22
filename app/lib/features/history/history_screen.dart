import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/session_providers.dart';
import '../../core/theme/app_theme.dart';
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
        loading: () => const Center(child: CircularProgressIndicator()),
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
            itemBuilder: (context, i) => _SessionCard(session: sessions[i]),
          );
        },
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final sets = ref.watch(sessionSetsProvider(session.id)).asData?.value ?? [];
    final working = sets.where((s) => !s.isWarmup).toList();
    final library = ref.watch(bundleProvider).asData?.value.library;

    final duration = session.startedAt != null && session.finishedAt != null
        ? session.finishedAt!.difference(session.startedAt!).inMinutes
        : null;

    final byExercise = <String, List<SetLog>>{};
    for (final s in working) {
      (byExercise[s.exerciseId] ??= []).add(s);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEE d MMM')
                        .format(session.scheduledDate)
                        .toUpperCase(),
                    style: t.labelLarge?.copyWith(color: AppTheme.textDim),
                  ),
                ),
                _StatusGlyph(status: session.status),
              ],
            ),
            Gap.xs,
            Text(
              'Week ${session.weekNo} · ${session.dayId}',
              style: t.titleMedium,
            ),
            Gap.s,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InfoChip(label: '${working.length} sets'),
                if (duration != null)
                  InfoChip(
                    label: '$duration min',
                    icon: Icons.schedule_outlined,
                  ),
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
      SessionStatus.skipped => ('✕', AppTheme.textDim, 'skipped'),
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
