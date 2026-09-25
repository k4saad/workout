import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../domain/metrics/session_summary.dart';

/// The end of a session, marked.
///
/// An hour in a basement deserves more than a dialog closing: the ring
/// fills, the numbers count up, and one button takes him back to wherever
/// the session was started from.
Future<void> showFinishMoment(
  BuildContext context, {
  required String title,
  required SessionSummary summary,
  required int doneSets,
  required int plannedSets,
}) {
  final reduced = AppMotion.reduced(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppTheme.bg,
    transitionDuration: reduced ? Duration.zero : AppMotion.slow,
    pageBuilder: (context, _, _) => FinishMoment(
      title: title,
      summary: summary,
      doneSets: doneSets,
      plannedSets: plannedSets,
    ),
    transitionBuilder: (context, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        scale: Tween(
          begin: 0.96,
          end: 1.0,
        ).animate(CurvedAnimation(parent: a, curve: AppMotion.emphasized)),
        child: child,
      ),
    ),
  );
}

class FinishMoment extends StatelessWidget {
  const FinishMoment({
    super.key,
    required this.title,
    required this.summary,
    required this.doneSets,
    required this.plannedSets,
  });

  final String title;
  final SessionSummary summary;
  final int doneSets;
  final int plannedSets;

  bool get _partial => doneSets < plannedSets;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final minutes = summary.duration?.inMinutes;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            children: [
              const Spacer(),
              RingProgress(
                value: plannedSets == 0 ? 1 : doneSets / plannedSets,
                size: 150,
                stroke: 12,
                color: _partial ? AppTheme.warn : AppTheme.crimson,
                center: Text(
                  _partial ? '◐' : '✓',
                  style: TextStyle(
                    fontSize: 54,
                    color: _partial ? AppTheme.warn : AppTheme.text,
                  ),
                ),
              ),
              Gap.l,
              Text(
                _partial ? 'Part done' : 'Done',
                style: AppTheme.overline.copyWith(
                  color: _partial ? AppTheme.warn : AppTheme.crimson,
                ),
              ),
              Gap.xs,
              Text(title, textAlign: TextAlign.center, style: t.headlineMedium),
              Gap.s,
              Text(
                _partial
                    ? '$doneSets of $plannedSets sets. It still counts: you '
                          'turned up.'
                    : 'Every set logged. Now eat, and sleep.',
                textAlign: TextAlign.center,
                style: t.bodyLarge!.copyWith(color: AppTheme.textDim),
              ),
              Gap.xl,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Sets',
                      value: summary.workingSets.toDouble(),
                      caption:
                          '${summary.movements} '
                          'movement${summary.movements == 1 ? '' : 's'}',
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: 'On the bar',
                      value: summary.volumeKg,
                      unit: 'kg',
                      caption: 'load × reps',
                    ),
                  ),
                  if (minutes != null)
                    Expanded(
                      child: StatTile(
                        label: 'Time',
                        value: minutes.toDouble(),
                        unit: 'min',
                      ),
                    ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
