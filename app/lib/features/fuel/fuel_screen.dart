import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ui/ui.dart';
import '../common/widgets.dart';

/// The Fuel tab: what to eat today, and whether it got eaten.
///
/// Phase 0 shell. It already reads the real week's targets from the
/// programme's `nutritionPhases`; the day-by-day meal plan replaces the body
/// in Phase 2.
class FuelScreen extends ConsumerWidget {
  const FuelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(currentWeekProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Fuel')),
      body: ref
          .watch(bundleProvider)
          .when(
            loading: () => const SkeletonPage(),
            error: (e, _) => AsyncScaffoldBody(
              loading: false,
              error: e,
              child: const SizedBox(),
            ),
            data: (bundle) {
              final phase = bundle.programme.nutritionForWeek(week);
              if (phase == null) {
                return Center(
                  child: EmptyState(
                    icon: Icons.restaurant_outlined,
                    title: 'No food target for week $week',
                    body:
                        'The programme sets no nutrition phase for this '
                        'week. Add one to the programme file and re-import '
                        'it.',
                  ),
                );
              }
              return ListView(
                padding: Gap.pagePadding,
                children: [
                  Text('WEEK $week TARGET', style: AppTheme.overline),
                  Gap.s,
                  AppCard(
                    hero: true,
                    child: Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            label: 'Energy',
                            value: phase.kcal.toDouble(),
                            unit: 'kcal',
                            size: 40,
                            labelColor: Colors.white,
                            unitColor: Colors.white,
                          ),
                        ),
                        StatTile(
                          label: 'Protein',
                          value: phase.proteinG.toDouble(),
                          unit: 'g',
                          size: 40,
                          labelColor: Colors.white,
                          unitColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  if (phase.note != null) ...[
                    Gap.m,
                    Text(phase.note!, style: t.bodyMedium),
                  ],
                ],
              );
            },
          ),
    );
  }
}
