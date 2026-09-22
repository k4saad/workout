import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/day.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/exercise.dart';
import '../common/widgets.dart';

/// The full session, read-only.
///
/// Phase 2 turns this into the runner; for now it replaces the printed plan.
class DayDetailScreen extends ConsumerWidget {
  const DayDetailScreen({super.key, required this.weekNo, required this.dayId});

  final int weekNo;
  final String dayId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bundleProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Week $weekNo')),
      body: async.when(
        loading: () => const AsyncScaffoldBody(
          loading: true,
          error: null,
          child: SizedBox(),
        ),
        error: (e, _) => AsyncScaffoldBody(
          loading: false,
          error: e,
          child: const SizedBox(),
        ),
        data: (b) {
          final block = b.programme.blockForWeek(weekNo);
          if (block == null) {
            return const Center(
              child: Text('That week is outside the programme.'),
            );
          }
          Day? day;
          for (final d in b.resolver.resolveDays(block, weekNo)) {
            if (d.id == dayId) day = d;
          }
          if (day == null) {
            return const Center(child: Text('No session on that day.'));
          }
          return _DayBody(
            day: day,
            library: b.library,
            blockName: block.name,
            weekNo: weekNo,
          );
        },
      ),
    );
  }
}

class _DayBody extends StatelessWidget {
  const _DayBody({
    required this.day,
    required this.library,
    required this.blockName,
    required this.weekNo,
  });

  final Day day;
  final ExerciseLibrary library;
  final String blockName;
  final int weekNo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return ListView(
      padding: Gap.pagePadding,
      children: [
        KindRail(kind: day.kind, optional: day.optional, height: 4),
        Gap.m,
        Row(
          children: [Expanded(child: Text(day.title, style: t.headlineMedium))],
        ),
        Gap.s,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            InfoChip(label: blockName),
            InfoChip(
              label: '${AppTheme.glyphForKind(day.kind)} ${day.kind.name}',
            ),
            if (day.estMinutes > 0)
              InfoChip(
                label: '~${day.estMinutes} min',
                icon: Icons.schedule_outlined,
              ),
            if (day.totalWorkingSets > 0)
              InfoChip(label: '${day.totalWorkingSets} sets'),
            if (day.optional) const InfoChip(label: 'optional'),
          ],
        ),

        if (day.note != null) ...[
          Gap.m,
          Text(
            day.note!,
            style: t.bodyLarge?.copyWith(color: AppTheme.textDim),
          ),
        ],

        // Warnings come BEFORE the work, always.
        for (final w in day.warnings) ...[Gap.m, WarningBanner(warning: w)],

        if (day.isTrainingDay) ...[
          Gap.l,
          FilledButton.icon(
            onPressed: () => context.go('/run/$weekNo/${day.id}'),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start session'),
          ),
        ],

        for (final section in day.sections) ...[
          Gap.l,
          _SectionCard(section: section, library: library),
        ],

        if (day.kind == DayKind.rest) ...[
          Gap.l,
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.bedtime_outlined,
                    color: AppTheme.slate,
                    size: 28,
                  ),
                  Gap.m,
                  Expanded(
                    child: Text(
                      'Muscle is built on the days you don’t train. '
                      'The session only sends the signal.',
                      style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.library});

  final Section section;
  final ExerciseLibrary library;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final groups = section.groups;

    // Label supersets SS1, SS2... within the section.
    final ssIndex = <String, int>{};
    for (final g in groups) {
      if (g.length > 1 && g.first.groupId != null) {
        ssIndex[g.first.groupId!] = ssIndex.length + 1;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(section.title, style: t.titleLarge)),
                if (section.estMinutes > 0)
                  Text(
                    '${section.estMinutes} min',
                    style: t.labelLarge?.copyWith(color: AppTheme.textDim),
                  ),
              ],
            ),

            // Warm-up and cool-down drills: ticked, not logged.
            if (section.drills.isNotEmpty) ...[
              Gap.s,
              for (final d in section.drills)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3, right: 10),
                        child: Icon(
                          Icons.check_box_outline_blank,
                          size: 20,
                          color: AppTheme.textDim,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: library.resolve(d.exerciseId).name,
                                    style: t.bodyLarge,
                                  ),
                                  TextSpan(
                                    text: '  ${d.text}',
                                    style: t.bodyMedium?.copyWith(
                                      color: AppTheme.textDim,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (d.note != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  d.note!,
                                  style: t.bodyMedium?.copyWith(
                                    color: AppTheme.textDim,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            // Prescriptions, with supersets kept visually together.
            for (var i = 0; i < groups.length; i++) ...[
              if (i > 0 || section.drills.isNotEmpty) const Divider(height: 20),
              if (groups[i].length > 1)
                _SupersetGroup(
                  members: groups[i],
                  label: 'SS${ssIndex[groups[i].first.groupId!]}',
                  library: library,
                )
              else
                PrescriptionRow(
                  prescription: groups[i].first,
                  exercise: library.resolve(groups[i].first.exerciseId),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A superset renders as ONE unit — that is what makes the alternating
/// structure legible mid-session, and it is how the 60-minute cap is met.
class _SupersetGroup extends StatelessWidget {
  const _SupersetGroup({
    required this.members,
    required this.label,
    required this.library,
  });

  final List members;
  final String label;
  final ExerciseLibrary library;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rest = members.last.restSec as int;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: AppTheme.dusk.withValues(alpha: 0.07),
        border: Border.all(color: AppTheme.dusk.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_vert, size: 18, color: AppTheme.dusk),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$label · alternate, rest ${rest}s after the pair',
                  style: t.labelLarge?.copyWith(color: AppTheme.dusk),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          for (var i = 0; i < members.length; i++) ...[
            if (i > 0)
              Divider(height: 14, color: AppTheme.dusk.withValues(alpha: 0.25)),
            PrescriptionRow(
              prescription: members[i],
              exercise: library.resolve(members[i].exerciseId as String),
            ),
          ],
        ],
      ),
    );
  }
}
