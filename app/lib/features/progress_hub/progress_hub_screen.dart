import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/body_providers.dart';
import '../../app/progress_providers.dart';
import '../../app/run_providers.dart';
import '../../app/providers.dart';
import '../../core/ui/ui.dart';
import '../../domain/metrics/bodyweight_trend.dart';
import '../../domain/run/run.dart';

/// The Progress tab: every way of seeing that it is working.
///
/// Body (weight, measurements), Photos, Lifts — one hub instead of the two
/// tabs v2 split them across. Each card shows the headline number so the hub
/// answers "is it working?" before anything is opened.
class ProgressHubScreen extends ConsumerWidget {
  const ProgressHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weights = ref.watch(weightEntriesProvider).asData?.value ?? const [];
    final shoots = ref.watch(shootsProvider).asData?.value ?? const [];
    final week = ref.watch(currentWeekProvider);
    final runs = ref.watch(finishedRunsProvider).asData?.value ?? const [];

    // The same 7-day average and weekly rate the Body screen and Today use.
    // A single scale reading swings a kilo on water; the hub must not
    // disagree with the screen it opens.
    const trend = BodyweightTrend();
    final avg = trend.currentAverage(weights);
    final rate = trend.weeklyChange(weights);

    String weightCaption() {
      if (avg == null) return 'Weigh in to start the trend';
      if (rate == null) return 'Weigh in again to see the trend';
      final r = double.parse(rate.toStringAsFixed(2));
      final glyph = r > 0 ? '▲ +' : (r < 0 ? '▼ ' : '■ ');
      return '$glyph${r.abs().toStringAsFixed(2)} kg/week · 7-day average';
    }

    final cards = <Widget>[
      _HubCard(
        icon: Icons.monitor_weight_outlined,
        title: 'Body',
        value: avg == null ? '—' : '${avg.toStringAsFixed(1)} kg',
        caption: weightCaption(),
        onTap: () => context.go('/progress/body'),
      ),
      _HubCard(
        icon: Icons.photo_camera_outlined,
        title: 'Photos',
        value: '${shoots.length}',
        caption: shoots.isEmpty
            ? (week <= 1
                  ? 'Shoot the baseline this week'
                  : 'No shoots yet · take the first one this week')
            : 'shoot${shoots.length == 1 ? '' : 's'} · private to this phone',
        onTap: () => context.go('/progress/photos'),
      ),
      _HubCard(
        icon: Icons.route_outlined,
        title: 'Runs',
        value: runs.isEmpty
            ? '—'
            : '${formatKm(runs.fold<double>(0, (a, r) => a + r.distanceM))} km',
        caption: runs.isEmpty
            ? 'Trail, splits and pace for every run'
            : '${runs.length} run${runs.length == 1 ? '' : 's'} · '
                  'last ${formatKm(runs.first.distanceM)} km',
        onTap: () => context.go('/progress/runs'),
      ),
      _HubCard(
        icon: Icons.fitness_center,
        title: 'Lifts',
        value: 'Numbers',
        caption: 'Sets per muscle, session length, every lift',
        onTap: () => context.go('/progress/lifts'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(
        padding: Gap.pagePadding,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            FadeSlideIn(index: i, child: cards[i]),
            Gap.m,
          ],
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      semanticLabel: title,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            child: Icon(icon, color: AppTheme.text),
          ),
          Gap.m,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: AppTheme.overline),
                Gap.xs,
                Text(value, style: AppTheme.numeric(28)),
                Gap.xs,
                Text(
                  caption,
                  style: t.bodySmall!.copyWith(color: AppTheme.textDim),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.textFaint),
        ],
      ),
    );
  }
}
