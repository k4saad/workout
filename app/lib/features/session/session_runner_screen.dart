import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/calendar_providers.dart';
import '../../app/providers.dart';
import '../../app/session_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/db/tables.dart';
import '../../domain/models/day.dart';
import '../../domain/models/exercise.dart';
import '../common/widgets.dart';
import '../exercises/exercise_detail_screen.dart';
import 'session_controller.dart';
import 'widgets/rest_timer_bar.dart';
import 'widgets/set_input.dart';
import 'widgets/suggestion_card.dart';

/// The session runner: press start, walk through the work, log every set.
///
/// This is the app. Everything else is a view onto what happens here.
class SessionRunnerScreen extends ConsumerStatefulWidget {
  const SessionRunnerScreen({
    super.key,
    required this.weekNo,
    required this.dayId,
    this.retroDate,
  });

  final int weekNo;
  final String dayId;

  /// Set when logging a session from memory rather than live.
  final DateTime? retroDate;

  @override
  ConsumerState<SessionRunnerScreen> createState() =>
      _SessionRunnerScreenState();
}

/// What the steppers show and an untouched stepper logs: anything the athlete
/// changed, else the suggestion (see [RunnerItem.prefill]).
PendingSet _withPrefill(RunnerItem item, PendingSet p) {
  final pre = item.prefill;
  return PendingSet(
    reps: p.reps ?? pre.reps,
    loadKg: p.loadKg ?? pre.loadKg,
    durationSec: p.durationSec ?? pre.durationSec,
    distanceM: p.distanceM ?? pre.distanceM,
    rir: p.rir,
  );
}

class _SessionRunnerScreenState extends ConsumerState<SessionRunnerScreen> {
  RunnerState? _state;
  PendingSet _pending = const PendingSet();
  Object? _error;
  bool _warningsDismissed = false;
  bool _offeredCut = false;
  Timer? _budgetTicker;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
    // The phone must not sleep between sets. A phone that refuses is an
    // inconvenience, never a reason for the session to fall over.
    unawaited(WakelockPlus.enable().catchError((Object _) {}));
    _budgetTicker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkBudget(),
    );
  }

  @override
  void dispose() {
    _budgetTicker?.cancel();
    unawaited(WakelockPlus.disable().catchError((Object _) {}));
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      final bundle = await ref.read(bundleProvider.future);
      final block = bundle.programme.blockForWeek(widget.weekNo);
      if (block == null) throw StateError('week ${widget.weekNo} has no block');

      final days = bundle.resolver.resolveDays(block, widget.weekNo);
      final day = days.firstWhere(
        (d) => d.id == widget.dayId,
        orElse: () => throw StateError('no day ${widget.dayId}'),
      );

      final service = ref.read(sessionServiceProvider);
      final DateTime date = widget.retroDate ?? ref.read(todayProvider);
      final session = await service.start(
        programmeId: bundle.programme.id,
        blockId: block.id,
        day: day,
        weekNo: widget.weekNo,
        date: date,
        retroactive: widget.retroDate != null,
      );

      // What to load today, worked out once from the history BEFORE this
      // session: the stepper pre-fills it and every set logs it as target.
      final suggestions = await ref.read(suggestionServiceProvider.future);
      final controller = ref.read(runnerControllerProvider);
      final loaded = await controller.load(
        session,
        day,
        suggestions: await suggestions.forSession(session, day),
      );
      if (!mounted) return;
      setState(() => _state = loaded);

      await ref.read(notificationServiceProvider).init();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _checkBudget() {
    final s = _state;
    if (s == null || _offeredCut) return;
    if (s.isRunningLong(DateTime.now())) {
      _offeredCut = true;
      _offerToCut();
    }
  }

  Future<void> _offerToCut() async {
    final s = _state;
    if (s == null || !mounted) return;
    final cut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Running long'),
        content: Text(
          'You are ${s.elapsedMinutes(DateTime.now())} minutes in, with '
          '${s.visibleItems.where((i) => !i.isComplete).length} movements '
          'left.\n\nSixty minutes means sixty minutes. Cut the last '
          'superset and finish the main lifts properly.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cut the last superset'),
          ),
        ],
      ),
    );
    if (cut == true && mounted) {
      setState(
        () => _state = ref.read(runnerControllerProvider).enterShortMode(s),
      );
    }
  }

  Future<void> _logCurrentSet(
    RunnerItem item,
    Exercise exercise, {
    bool isWarmup = false,
  }) async {
    final s = _state;
    final next = item.nextSet;
    if (s == null || next == null) return;

    final controller = ref.read(runnerControllerProvider);
    // Exactly what the steppers show, so an untouched stepper logs its value.
    final shown = _withPrefill(item, _pending);
    final updated = await controller.logSet(
      s,
      prescription: item.prescription,
      setIndex: next.setIndex,
      side: next.side,
      reps: shown.reps,
      loadKg: shown.loadKg,
      durationSec: shown.durationSec,
      distanceM: shown.distanceM,
      rir: shown.rir,
      isWarmup: isWarmup,
      exerciseName: exercise.name,
    );

    if (updated.restEndsAt != null) {
      await ref
          .read(notificationServiceProvider)
          .scheduleRestEnd(
            updated.restEndsAt!,
            exerciseName: exercise.name,
            setNumber: next.setIndex,
          );
    }

    if (!mounted) return;
    setState(() {
      _state = updated;
      _pending = const PendingSet();
    });
  }

  Future<void> _finish() async {
    final s = _state;
    if (s == null) return;
    final incomplete = s.visibleItems.where((i) => !i.isComplete).length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Finish session?'),
        content: Text(
          incomplete == 0
              ? 'Everything logged. Nice work.'
              : '$incomplete movement${incomplete == 1 ? '' : 's'} still '
                    'unlogged — this will be recorded as a partial '
                    'session, which is honest rather than punitive.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(runnerControllerProvider).finish(s);
    await ref.read(notificationServiceProvider).cancelRest();
    ref.invalidate(historyProvider);
    ref.invalidate(resumableSessionProvider);
    // The screen underneath (calendar, week, Today) is still alive and must
    // not show the day as untrained — tapping it would offer to restart, and
    // restarting un-finishes the session.
    ref.invalidate(allRecordsProvider);
    ref.invalidate(completedSessionCountProvider);
    // Back to wherever the session was started from: Today, the week,
    // the calendar. That tab's stack is intact underneath.
    if (mounted) context.canPop() ? context.pop() : context.go('/');
  }

  Future<void> _logNiggle(String? exerciseId) async {
    final s = _state;
    if (s == null) return;
    final site = await showModalBottomSheet<NiggleSite>(
      context: context,
      // Eight sites plus a title do not fit the default 9/16 cap on a small
      // phone at large text; the list scrolls instead of cutting off.
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'What hurts?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final n in NiggleSite.values)
                ListTile(
                  title: Text(_niggleLabel(n)),
                  onTap: () => Navigator.pop(context, n),
                ),
            ],
          ),
        ),
      ),
    );
    if (site == null || !mounted) return;
    await ref
        .read(runnerControllerProvider)
        .logNiggle(state: s, site: site, severity: 2, exerciseId: exerciseId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logged. If it is more than a niggle, stop the set and use '
            'the substitute.',
          ),
        ),
      );
    }
  }

  static String _niggleLabel(NiggleSite s) => switch (s) {
    NiggleSite.knee => 'Knee',
    NiggleSite.lowBack => 'Lower back',
    NiggleSite.shoulder => 'Shoulder',
    NiggleSite.elbow => 'Elbow',
    NiggleSite.wrist => 'Wrist',
    NiggleSite.hip => 'Hip',
    NiggleSite.neck => 'Neck',
    NiggleSite.other => 'Something else',
  };

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session')),
        body: AsyncScaffoldBody(
          loading: false,
          error: _error,
          child: const SizedBox(),
        ),
      );
    }

    final s = _state;
    if (s == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bundle = ref.watch(bundleProvider).asData?.value;
    final library = bundle?.library;
    final item = s.focus;

    // Back mid-set asks first. Leaving loses nothing — every set is already
    // saved and Today offers to resume — but a stray swipe between heavy
    // sets should not dump you out of the session.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave the session?'),
            content: const Text(
              'Everything you have logged is saved. Today will offer to '
              'resume exactly where you left off.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep going'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) {
          ref.invalidate(resumableSessionProvider);
          ref.invalidate(allRecordsProvider);
          context.canPop() ? context.pop() : context.go('/');
        }
      },
      child: _body(context, s, bundle, library, item),
    );
  }

  Widget _body(
    BuildContext context,
    RunnerState s,
    ProgrammeBundle? bundle,
    ExerciseLibrary? library,
    RunnerItem? item,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(s.day.title),
        actions: [
          IconButton(
            tooltip: 'Something hurts',
            icon: const Icon(Icons.healing_outlined),
            onPressed: () => _logNiggle(item?.prescription.exerciseId),
          ),
          TextButton(onPressed: _finish, child: const Text('Finish')),
        ],
      ),
      body: Column(
        children: [
          _SessionHeader(state: s),
          if (s.day.warnings.isNotEmpty && !_warningsDismissed)
            _WarningStack(
              warnings: s.day.warnings,
              onDismiss: () => setState(() => _warningsDismissed = true),
            ),
          Expanded(
            child: library == null
                ? const Center(child: CircularProgressIndicator())
                : _RunnerBody(
                    state: s,
                    library: library,
                    pending: _pending,
                    latticeStep: bundle!.lattice.nominalBarbellStep ?? 1.0,
                    // The prescription's startLoadKg already has the block
                    // multiplier applied, but logged history does not — so
                    // the engine needs it separately.
                    blockMultiplier:
                        bundle.programme
                            .blockForWeek(widget.weekNo)
                            ?.loadMultiplier ??
                        1.0,
                    onPendingChanged: (v) => setState(() => _pending = v),
                    onFocus: (i) => setState(() {
                      _state = ref.read(runnerControllerProvider).focusOn(s, i);
                      _pending = const PendingSet();
                    }),
                    onLog: (it, ex, {bool warmup = false}) =>
                        _logCurrentSet(it, ex, isWarmup: warmup),
                    onUndo: () async {
                      final updated = await ref
                          .read(runnerControllerProvider)
                          .undoLast(s);
                      if (mounted) setState(() => _state = updated);
                    },
                  ),
          ),
          if (s.isResting)
            RestTimerBar(
              endsAt: s.restEndsAt!,
              totalSec: item?.prescription.restSec ?? 120,
              label: s.restLabel ?? '',
              setNumber: s.restSetNumber ?? 1,
              onAdjust: (secs) async {
                final updated = ref
                    .read(runnerControllerProvider)
                    .adjustRest(s, secs);
                setState(() => _state = updated);
                if (updated.restEndsAt != null) {
                  await ref
                      .read(notificationServiceProvider)
                      .scheduleRestEnd(
                        updated.restEndsAt!,
                        exerciseName: updated.restLabel ?? '',
                        setNumber: updated.restSetNumber ?? 1,
                      );
                }
              },
              onSkip: () async {
                setState(
                  () =>
                      _state = ref.read(runnerControllerProvider).clearRest(s),
                );
                await ref.read(notificationServiceProvider).cancelRest();
              },
              onDone: () {},
            ),
        ],
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.state});

  final RunnerState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final elapsed = state.elapsedMinutes(DateTime.now());
    final estimate = state.day.estMinutes;
    final over = estimate > 0 && elapsed > estimate;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${state.doneSets} / ${state.plannedSets} sets',
                style: t.labelLarge?.copyWith(color: AppTheme.textDim),
              ),
              const Spacer(),
              Icon(
                Icons.schedule_outlined,
                size: 15,
                color: over ? AppTheme.warn : AppTheme.textDim,
              ),
              const SizedBox(width: 4),
              Text(
                estimate > 0 ? '$elapsed / $estimate min' : '$elapsed min',
                style: t.labelLarge?.copyWith(
                  color: over ? AppTheme.warn : AppTheme.textDim,
                ),
              ),
              if (state.shortMode) ...[
                const SizedBox(width: 8),
                const InfoChip(label: 'short'),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: state.progress,
              minHeight: 5,
              backgroundColor: AppTheme.outline,
              valueColor: const AlwaysStoppedAnimation(AppTheme.oxblood),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningStack extends StatelessWidget {
  const _WarningStack({required this.warnings, required this.onDismiss});

  final List<DayWarning> warnings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          for (final w in warnings) ...[
            WarningBanner(warning: w),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: onDismiss,
              child: const Text('Read it — start the session'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RunnerBody extends StatelessWidget {
  const _RunnerBody({
    required this.state,
    required this.library,
    required this.pending,
    required this.latticeStep,
    required this.blockMultiplier,
    required this.onPendingChanged,
    required this.onFocus,
    required this.onLog,
    required this.onUndo,
  });

  final RunnerState state;
  final ExerciseLibrary library;
  final PendingSet pending;
  final double latticeStep;

  /// The block's loadMultiplier. The prescription's own startLoadKg already
  /// has it applied, but history does not — so the engine needs it too.
  final double blockMultiplier;
  final ValueChanged<PendingSet> onPendingChanged;
  final ValueChanged<int> onFocus;
  final void Function(RunnerItem, Exercise, {bool warmup}) onLog;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final visible = state.visibleItems;

    return ListView(
      padding: Gap.pagePadding,
      children: [
        // The movement strip: one tap to switch, current one highlighted.
        SizedBox(
          height: 44,
          child: ListView.separated(
            key: const ValueKey('movement-strip'),
            scrollDirection: Axis.horizontal,
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final it = visible[i];
              final realIndex = state.items.indexOf(it);
              final selected = realIndex == state.focusIndex;
              return _MovementPill(
                label: library.resolve(it.prescription.exerciseId).name,
                done: it.isComplete,
                selected: selected,
                superset: it.prescription.groupId != null,
                onTap: () => onFocus(realIndex),
              );
            },
          ),
        ),
        Gap.l,
        if (state.focus != null)
          _FocusCard(
            item: state.focus!,
            exercise: library.resolve(state.focus!.prescription.exerciseId),
            pending: pending,
            latticeStep: latticeStep,
            blockMultiplier: blockMultiplier,
            onPendingChanged: onPendingChanged,
            onLog: onLog,
            onUndo: onUndo,
          ),
      ],
    );
  }
}

class _MovementPill extends StatelessWidget {
  const _MovementPill({
    required this.label,
    required this.done,
    required this.selected,
    required this.superset,
    required this.onTap,
  });

  final String label;
  final bool done;
  final bool selected;
  final bool superset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: selected
          ? AppTheme.oxblood.withValues(alpha: 0.3)
          : AppTheme.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? AppTheme.oxblood : AppTheme.outline,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // Glyph, not colour: the state has to survive bad light.
              Text(
                done ? '✓' : (superset ? '⇄' : '○'),
                style: TextStyle(
                  color: done ? AppTheme.good : AppTheme.textDim,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: t.labelLarge?.copyWith(
                  color: selected ? AppTheme.text : AppTheme.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusCard extends ConsumerWidget {
  const _FocusCard({
    required this.item,
    required this.exercise,
    required this.pending,
    required this.latticeStep,
    required this.blockMultiplier,
    required this.onPendingChanged,
    required this.onLog,
    required this.onUndo,
  });

  final RunnerItem item;
  final Exercise exercise;
  final PendingSet pending;
  final double latticeStep;
  final double blockMultiplier;
  final ValueChanged<PendingSet> onPendingChanged;
  final void Function(RunnerItem, Exercise, {bool warmup}) onLog;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final p = item.prescription;
    final next = item.nextSet;
    final lastTime =
        ref
            .watch(
              lastTimeProvider((
                prescriptionId: p.id,
                exerciseId: p.exerciseId,
              )),
            )
            .asData
            ?.value ??
        [];
    // The suggestion the session opened with — the one the stepper holds and
    // the log records. The provider is only a fallback.
    final suggestion =
        item.suggestion ??
        ref
            .watch(suggestionProvider((p: p, mult: blockMultiplier)))
            .asData
            ?.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(exercise.name, style: t.headlineSmall)),
                // One tap to the demo and back. A demo you have to leave the
                // session to find does not get watched — and this pushes a
                // route rather than replacing one, so you come back to the
                // exact set you were on.
                IconButton(
                  tooltip: 'How do I do this?',
                  icon: const Icon(Icons.help_outline),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ExerciseDetailScreen(exerciseId: p.exerciseId),
                    ),
                  ),
                ),
              ],
            ),
            Gap.s,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InfoChip(
                  label:
                      '${p.sets} × ${p.repRangeLabel}'
                      '${p.unit.short.isEmpty ? '' : ' ${p.unit.short}'}'
                      '${p.perSide ? ' / side' : ''}',
                  emphasis: true,
                ),
                if (p.restSec > 0)
                  InfoChip(
                    label: '${p.restSec}s rest',
                    icon: Icons.timer_outlined,
                  ),
                if (p.targetRir != null) InfoChip(label: 'RIR ${p.targetRir}'),
                if (p.tempo != null) InfoChip(label: p.tempo!),
                if (p.warmupRamp) const InfoChip(label: 'ramp first'),
              ],
            ),
            Gap.m,
            LastTimeLine(
              sets: lastTime
                  .map(
                    (l) => (
                      reps: l.reps,
                      loadKg: l.loadKg,
                      durationSec: l.durationSec,
                    ),
                  )
                  .toList(),
              unit: p.unit,
            ),

            if (suggestion != null) ...[
              Gap.m,
              SuggestionCard(suggestion: suggestion),
            ],

            if (p.coachNote != null) ...[
              Gap.m,
              Text(
                p.coachNote!,
                style: t.bodyMedium?.copyWith(color: AppTheme.textDim),
              ),
            ],

            const Divider(height: 28),

            if (next == null) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.good),
                  Gap.s,
                  Expanded(
                    child: Text(
                      'All ${item.totalCount} sets logged.',
                      style: t.titleMedium?.copyWith(color: AppTheme.good),
                    ),
                  ),
                ],
              ),
              Gap.m,
              OutlinedButton.icon(
                onPressed: onUndo,
                icon: const Icon(Icons.undo),
                label: const Text('Undo last set'),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Set ${next.setIndex} of ${p.sets}'
                      '${next.side != null ? '  ·  ${next.side == 'L' ? 'left' : 'right'}' : ''}',
                      style: t.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item.doneCount}/${item.totalCount} done',
                    style: t.labelLarge?.copyWith(color: AppTheme.textDim),
                  ),
                ],
              ),
              Gap.m,
              SetInput(
                prescription: p,
                value: _withPrefill(item, pending),
                latticeStep: latticeStep,
                onChanged: onPendingChanged,
              ),
              Gap.l,
              FilledButton(
                onPressed: () => onLog(item, exercise),
                child: Text(
                  'Log set ${next.setIndex}'
                  '${next.side != null ? ' (${next.side})' : ''}',
                ),
              ),
              if (p.warmupRamp && item.doneCount == 0) ...[
                Gap.s,
                OutlinedButton(
                  onPressed: () => onLog(item, exercise, warmup: true),
                  child: const Text('Log as a ramp set'),
                ),
              ],
              if (item.doneCount > 0) ...[
                Gap.s,
                TextButton.icon(
                  onPressed: onUndo,
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Undo last set'),
                ),
              ],
            ],

            if (exercise.cues.isNotEmpty) ...[
              const Divider(height: 28),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Cues', style: t.titleMedium),
                children: [
                  for (final c in exercise.cues)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('·  '),
                          Expanded(child: Text(c, style: t.bodyMedium)),
                        ],
                      ),
                    ),
                  if (exercise.soloSafety != null) ...[
                    Gap.s,
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warn.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        exercise.soloSafety!,
                        style: t.bodyMedium?.copyWith(color: AppTheme.warn),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
