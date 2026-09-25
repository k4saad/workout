import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/body_providers.dart';
import '../../app/providers.dart';
import '../../app/session_providers.dart';
import '../../core/ui/ui.dart';
import '../../data/db/database.dart' show CardioLog;
import '../../data/db/tables.dart';
import '../../domain/intervals/interval_engine.dart';
import '../../domain/models/programme.dart';
import '../session/widgets/rest_timer_bar.dart';

/// The cardio day.
///
/// Two jobs: a heart that works, and calves and Achilles that tolerate
/// skipping. Neither job is "burn calories" — at 50 kg trying to gain, extra
/// cardio is a cost, not a bonus, and the programme caps it deliberately.
class CardioScreen extends ConsumerStatefulWidget {
  const CardioScreen({super.key});

  @override
  ConsumerState<CardioScreen> createState() => _CardioScreenState();
}

class _CardioScreenState extends ConsumerState<CardioScreen> {
  IntervalSpec? _running;
  DateTime? _startedAt;
  String? _runningLabel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final bundle = ref.watch(bundleProvider).asData?.value;
    final week = ref.watch(currentWeekProvider);
    final cardio = bundle?.programme.cardioForWeek(week);
    final logs = ref.watch(cardioLogsProvider).asData?.value ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Cardio')),
      body: ListView(
        padding: Gap.pagePadding,
        children: [
          if (cardio != null) _WeekTargets(week: week, cardio: cardio),

          if (_running != null && _startedAt != null) ...[
            Gap.l,
            IntervalTimerPanel(
              spec: _running!,
              startedAt: _startedAt!,
              onFinished: _onIntervalFinished,
            ),
            Gap.m,
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _running = null;
                  _startedAt = null;
                }),
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            ),
          ] else ...[
            Gap.l,
            Text('Start a timer', style: t.titleLarge),
            Gap.s,
            Text(
              'Skipping ramps over four weeks on purpose — it is the '
              'commonest way untrained calves and Achilles tendons get hurt. '
              'Always on the interlocking mats, never bare concrete.',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
            Gap.m,
            _IntervalButton(
              label: 'Skipping · 6 × 45 s',
              spec: const IntervalSpec(
                rounds: 6,
                workSec: 45,
                restSec: 45,
                prepareSec: 10,
                label: 'Skipping',
              ),
              onStart: _start,
            ),
            Gap.s,
            _IntervalButton(
              label: 'Skipping · 8 × 30 s fast',
              spec: const IntervalSpec(
                rounds: 8,
                workSec: 30,
                restSec: 30,
                prepareSec: 10,
                label: 'Skipping',
              ),
              onStart: _start,
            ),
            Gap.s,
            _IntervalButton(
              label: 'Heavy bag · 3 × 2 min',
              spec: const IntervalSpec(
                rounds: 3,
                workSec: 120,
                restSec: 60,
                prepareSec: 15,
                label: 'Bag rounds',
              ),
              onStart: _start,
            ),
            Gap.s,
            Text(
              'Wraps or gloves on, always. Straight punches, move your feet, '
              'breathe out on every shot.',
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
          ],

          Gap.l,
          const Divider(),
          Gap.m,
          Text('Log a run', style: t.titleLarge),
          Gap.xs,
          Text(
            'No GPS — your phone already has a running app. This just '
            'records that it happened.',
            style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
          ),
          Gap.m,
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _logRun,
              icon: const Icon(Icons.directions_run),
              label: const Text('Log a run'),
            ),
          ),

          if (logs.isNotEmpty) ...[
            Gap.l,
            Text('Recent', style: t.titleLarge),
            Gap.s,
            for (final log in logs.take(12)) _CardioRow(log: log),
          ],
          Gap.xl,
        ],
      ),
    );
  }

  void _start(IntervalSpec spec) {
    setState(() {
      _running = spec;
      _startedAt = DateTime.now();
      _runningLabel = spec.label;
    });

    // Schedule the round cues so they fire with the screen off. The on-screen
    // countdown is cosmetic; this is what you actually hear.
    final engine = IntervalEngine(spec);
    final cues = engine
        .transitions(_startedAt!)
        .map(
          (x) => (
            at: x.at,
            title: switch (x.phase) {
              IntervalPhase.work => 'Round ${x.round} — go',
              IntervalPhase.rest => 'Rest',
              IntervalPhase.done => 'Done',
              IntervalPhase.prepare => 'Get ready',
            },
            body: spec.label ?? 'Interval',
          ),
        )
        .toList();
    ref.read(notificationServiceProvider).scheduleIntervalCues(cues);
  }

  Future<void> _onIntervalFinished() async {
    final spec = _running;
    if (spec == null) return;
    await ref
        .read(bodyServiceProvider)
        .logCardio(
          kind: (spec.label ?? '').toLowerCase().contains('bag')
              ? CardioKind.bag
              : CardioKind.skip,
          on: ref.read(todayProvider),
          durationSec: spec.totalSec,
          rounds: spec.rounds,
        );
    ref.invalidate(cardioLogsProvider);
    if (mounted) {
      setState(() {
        _running = null;
        _startedAt = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_runningLabel ?? 'Interval'} logged.')),
      );
    }
  }

  Future<void> _logRun() async {
    final minutes = TextEditingController();
    final km = TextEditingController();
    var effort = 5;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Log a run'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: minutes,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Duration',
                  suffixText: 'min',
                ),
              ),
              TextField(
                controller: km,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Distance (optional)',
                  suffixText: 'km',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'How hard? $effort / 10',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Slider(
                value: effort.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                onChanged: (v) => setLocal(() => effort = v.round()),
              ),
              Text(
                'Every run in this programme is conversational except the '
                'week-12 time trial. Above 6 and you are racing it.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppTheme.textDim),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final mins = int.tryParse(minutes.text);
    if (mins == null) return;
    final distance = double.tryParse(km.text.replaceAll(',', '.'));

    await ref
        .read(bodyServiceProvider)
        .logCardio(
          kind: CardioKind.run,
          on: ref.read(todayProvider),
          durationSec: mins * 60,
          distanceM: distance == null ? null : (distance * 1000).round(),
          effort: effort,
        );
    ref.invalidate(cardioLogsProvider);
  }
}

class _WeekTargets extends StatelessWidget {
  const _WeekTargets({required this.week, required this.cardio});

  final int week;
  final CardioWeek cardio;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Week $week', style: t.titleLarge),
          Gap.s,
          if (cardio.longRunLabel != null)
            _Line(
              icon: Icons.directions_run,
              label: 'Sunday run',
              value: cardio.longRunLabel!,
            ),
          if (cardio.secondRunMin != null)
            _Line(
              icon: Icons.directions_walk,
              label: 'Second run',
              value:
                  '${cardio.secondRunMin!.first}–'
                  '${cardio.secondRunMin!.last} min',
            ),
          if (cardio.skipping != null)
            _Line(
              icon: Icons.cable,
              label: 'Skipping',
              value: cardio.skipping!,
            ),
          if (cardio.bag != null)
            _Line(icon: Icons.sports_mma, label: 'Bag', value: cardio.bag!),
          if (cardio.note != null) ...[
            Gap.s,
            Text(
              cardio.note!,
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textDim),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
            ),
          ),
          Text(value, style: t.bodyLarge),
        ],
      ),
    );
  }
}

class _IntervalButton extends StatelessWidget {
  const _IntervalButton({
    required this.label,
    required this.spec,
    required this.onStart,
  });

  final String label;
  final IntervalSpec spec;
  final void Function(IntervalSpec) onStart;

  @override
  Widget build(BuildContext context) {
    final minutes = (spec.totalSec / 60).ceil();
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: () => onStart(spec),
        child: Row(
          children: [
            const Icon(Icons.play_arrow),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
            Text(
              '~$minutes min',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppTheme.textDim),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardioRow extends StatelessWidget {
  const _CardioRow({required this.log});

  final CardioLog log;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final minutes = (log.durationSec ?? 0) ~/ 60;
    final km = log.distanceM == null
        ? null
        : (log.distanceM! / 1000).toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            switch (log.kind) {
              CardioKind.run => Icons.directions_run,
              CardioKind.skip => Icons.cable,
              CardioKind.bag => Icons.sports_mma,
              CardioKind.other => Icons.favorite_outline,
            },
            size: 18,
            color: AppTheme.moss,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${log.measuredOn.day}/${log.measuredOn.month}'
              '  ·  ${log.kind.name}',
              style: t.bodyMedium,
            ),
          ),
          Text(
            [
              if (minutes > 0) '$minutes min',
              if (km != null) '$km km',
              if (log.rounds != null) '${log.rounds} rounds',
            ].join(' · '),
            style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
          ),
        ],
      ),
    );
  }
}
